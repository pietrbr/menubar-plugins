#!/usr/bin/env python3
# <xbar.title>todo.txt</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Pietro Brach del Prever</xbar.author>
# <xbar.desc>Todo.txt in the menu bar: view, add, edit, complete, archive.</xbar.desc>
# <xbar.dependencies>python3</xbar.dependencies>

"""
Actions dispatched via sys.argv:
  edit    <line>  - osascript dialog pre-filled with task text, writes back on Save
  done    <line>  - mark complete: strips (X), appends pri:X, prepends x DATE
  undo    <line>  - reverse of done: strips x DATE, restores (X) from pri:X
  archive         - move all x-prefixed lines from todo.txt to done.txt
  add             - osascript prompt, appends creation-dated task

Config sources:
  ~/.todo/config                - todo-txt shell vars (TODO_FILE, DONE_FILE ...)
  ~/.todo/todotxt-bar.ini       - plugin-only settings (sort_by, max_items ...)
"""

import configparser
import os
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

SCRIPT = os.path.realpath(sys.argv[0])
TODAY = date.today().isoformat()


# -- Config --------------------------------------------------------------------


def _expand_vars(val: str, env: dict) -> str:
    return re.sub(r"\$\{?(\w+)\}?", lambda m: env.get(m.group(1), m.group(0)), val)


def load_shell_config(path: Path) -> dict:
    env = {"HOME": str(Path.home())}
    try:
        for line in path.read_text().splitlines():
            m = re.match(r"^export\s+(\w+)=(.*)$", line.strip())
            if not m:
                continue
            key = m.group(1)
            val = m.group(2).strip().strip('"').strip("'")
            env[key] = _expand_vars(val, env)
    except FileNotFoundError:
        pass
    return env


def get_file_paths():
    env = load_shell_config(Path.home() / ".todo" / "config")
    todo_dir = env.get("TODO_DIR", str(Path.home() / "todo"))
    todo_file = Path(env.get("TODO_FILE", os.path.join(todo_dir, "todo.txt")))
    done_file = Path(env.get("DONE_FILE", os.path.join(todo_dir, "done.txt")))
    return todo_file, done_file


def load_plugin_config() -> dict:
    ini = Path.home() / ".todo" / "todotxt-bar.ini"
    cfg = configparser.ConfigParser(inline_comment_prefixes=(";", "#"))
    cfg.read(ini)

    def g(k, d):
        return cfg.get("settings", k, fallback=d)

    def gb(k, d):
        return cfg.getboolean("settings", k, fallback=d)

    def gi(k, d):
        return cfg.getint("settings", k, fallback=d)

    return {
        "sort_by": g("sort_by", "priority"),
        "max_items": gi("max_items", 30),
        "show_priority": gb("show_priority", True),
    }


# -- Task model ----------------------------------------------------------------


class Task:
    __slots__ = (
        "body",
        "completion_date",
        "contexts",
        "creation_date",
        "done",
        "due",
        "line_num",
        "priority",
        "projects",
        "raw",
    )

    def __init__(self, line_num: int, raw: str):
        self.line_num = line_num
        self.raw = raw
        self.done = False
        self.priority = None
        self.creation_date = None
        self.completion_date = None
        self._parse()

    def _parse(self):
        s = self.raw

        if s.startswith("x "):
            self.done = True
            s = s[2:]
            m = re.match(r"^(\d{4}-\d{2}-\d{2}) ", s)
            if m:
                self.completion_date = m.group(1)
                s = s[m.end():]

        if not self.done:
            m = re.match(r"^\(([A-Z])\) ", s)
            if m:
                self.priority = m.group(1)
                s = s[m.end():]

        m = re.match(r"^(\d{4}-\d{2}-\d{2}) ", s)
        if m:
            self.creation_date = m.group(1)
            s = s[m.end():]

        self.body = s
        self.projects = re.findall(r"(?<!\S)\+(\S+)", s)
        self.contexts = re.findall(r"(?<!\S)@(\S+)", s)
        dm = re.search(r"\bdue:(\d{4}-\d{2}-\d{2})\b", s)
        self.due = dm.group(1) if dm else None

    def sort_key(self, by: str) -> tuple:
        p = self.priority or "ZZ"
        d = self.due or "9999-99-99"
        if by == "priority":
            return (p, d, self.line_num)
        if by == "due":
            return (d, p, self.line_num)
        if by == "project":
            return (
                self.projects[0].lower() if self.projects else "zzz",
                d,
                self.line_num,
            )
        if by == "context":
            return (
                self.contexts[0].lower() if self.contexts else "zzz",
                d,
                self.line_num,
            )
        return (d, self.line_num)


def read_tasks(path: Path) -> list:
    try:
        lines = path.read_text().splitlines()
    except FileNotFoundError:
        return []
    return [Task(i + 1, ln) for i, ln in enumerate(lines) if ln.strip()]


# -- File operations -----------------------------------------------------------


def _read_lines(path: Path) -> list:
    try:
        return path.read_text().splitlines(keepends=True)
    except FileNotFoundError:
        return []


def _write_lines(path: Path, lines: list):
    path.write_text("".join(lines))


def do_edit(todo_file: Path, line_num: int, new_text: str):
    lines = _read_lines(todo_file)
    if 0 < line_num <= len(lines):
        lines[line_num - 1] = new_text.strip() + "\n"
    _write_lines(todo_file, lines)


def do_done(todo_file: Path, line_num: int):
    lines = _read_lines(todo_file)
    if 0 < line_num <= len(lines):
        raw = lines[line_num - 1].rstrip("\n")
        if not raw.startswith("x "):
            m = re.match(r"^\(([A-Z])\) ", raw)
            if m:
                raw = f"{raw[m.end():]} pri:{m.group(1)}"
            lines[line_num - 1] = f"x {TODAY} {raw}\n"
    _write_lines(todo_file, lines)


def do_undo(todo_file: Path, line_num: int):
    lines = _read_lines(todo_file)
    if not 0 < line_num <= len(lines):
        return
    raw = lines[line_num - 1].rstrip("\n")
    m = re.match(r"^x (?:\d{4}-\d{2}-\d{2} )?(.*)$", raw)
    if not m:
        return
    raw = m.group(1)
    p = re.search(r" pri:([A-Z])$", raw)
    if p:
        raw = f"({p.group(1)}) {raw[:p.start()]}"
    lines[line_num - 1] = raw + "\n"
    _write_lines(todo_file, lines)


def do_archive(todo_file: Path, done_file: Path):
    lines = _read_lines(todo_file)
    active, completed = [], []
    for ln in lines:
        (completed if ln.lstrip().startswith("x ") else active).append(ln)
    _write_lines(todo_file, active)
    done_file.parent.mkdir(parents=True, exist_ok=True)
    with done_file.open("a") as f:
        f.writelines(completed)


def do_add(todo_file: Path, text: str):
    if text:
        text = text.strip()
        m = re.match(r"^(\([A-Z]\)) (.*)", text)
        line = f"{m.group(1)} {TODAY} {m.group(2)}" if m else f"{TODAY} {text}"
        with todo_file.open("a") as f:
            f.write(line + "\n")


# -- osascript -----------------------------------------------------------------


def ask_dialog(prompt: str, default: str = ""):
    safe = default.replace("\\", "\\\\").replace('"', '" & quote & "')
    script = (
        'tell application "System Events"\n'
        f'  set dlg to display dialog "{prompt}" '
        f'default answer "{safe}" '
        'buttons {"Cancel", "Save"} default button "Save"\n'
        "  return text returned of dlg\n"
        "end tell"
    )
    r = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
    return None if r.returncode != 0 else r.stdout.strip()


# -- xbar rendering ------------------------------------------------------------

_RESET = "\x1b[0m"
_COLOR_PROJECT = "\x1b[32m"  # green
_COLOR_CONTEXT = "\x1b[36m"  # cyan
_COLOR_OVERDUE = "red"
_COLOR_DUE_TODAY = "yellow"
_COLOR_DUE_FUTURE = "\x1b[35m"  # magenta


def colorize(text: str, due_future: bool = False) -> str:
    if due_future:
        text = re.sub(
            r"due:\d{4}-\d{2}-\d{2}", f"{_COLOR_DUE_FUTURE}\\g<0>{_RESET}", text
        )
    text = re.sub(r"(?<!\S)(\+\S+)", f"{_COLOR_PROJECT}\\1{_RESET}", text)
    text = re.sub(r"(?<!\S)(@\S+)", f"{_COLOR_CONTEXT}\\1{_RESET}", text)
    return text


def _item(
    label: str,
    args: list,
    *,
    color: str = None,
    alternate: bool = False,
    ansi: bool = False,
):
    parts = [f"bash={SCRIPT}"]
    for i, a in enumerate(args, 1):
        parts.append(f"param{i}={a}")
    parts += ["terminal=false", "refresh=true"]
    if color:
        parts.append(f"color={color}")
    if alternate:
        parts.append("alternate=true")
    if ansi:
        parts.append("ansi=true")
    print(f"{label.replace('|', '｜')} | {' '.join(parts)}")


def render(todo_file: Path, done_file: Path, cfg: dict):
    tasks = read_tasks(todo_file)
    active = [t for t in tasks if not t.done]
    done = [t for t in tasks if t.done]

    active.sort(key=lambda t: t.sort_key(cfg["sort_by"]))

    overdue = [t for t in active if t.due and t.due < TODAY]
    # title = "🗒" + str(len(active)) + (" ⚠" + str(len(overdue)) if overdue else "")
    title = "✅ " + str(len(active)) + (" ⚠" + str(len(overdue)) if overdue else "")
    print(title)
    print("---")

    if not todo_file.exists():
        print(f"todo.txt not found: {todo_file} | color=red")
        print("---")

    for t in active[: cfg["max_items"]]:
        label = t.body
        if cfg["show_priority"] and t.priority:
            label = f"({t.priority}) {label}"

        if t.due and t.due < TODAY:
            _item(label, ["edit", str(t.line_num)], color=_COLOR_OVERDUE)
            _item(
                f"✓ {label}",
                ["done", str(t.line_num)],
                color=_COLOR_OVERDUE,
                alternate=True,
            )
        elif t.due and t.due == TODAY:
            _item(label, ["edit", str(t.line_num)], color=_COLOR_DUE_TODAY)
            _item(
                f"✓ {label}",
                ["done", str(t.line_num)],
                color=_COLOR_DUE_TODAY,
                alternate=True,
            )
        else:
            display = colorize(label, due_future=bool(t.due))
            _item(display, ["edit", str(t.line_num)], ansi=True)
            _item(f"✓ {display}", ["done", str(t.line_num)], alternate=True, ansi=True)

    if len(active) > cfg["max_items"]:
        print(f"... {len(active) - cfg['max_items']} more | color=gray size=11")

    if done:
        print("---")
        for t in done:
            print(f"✓ {t.body.replace('|', '｜')} | color=gray")
            _item(
                f"Undo {t.body}",
                ["undo", str(t.line_num)],
                color="gray",
                alternate=True,
            )

    print("---")
    print(f"Add task | bash={SCRIPT} param1=add terminal=false refresh=true")
    if done:
        print(
            f"Archive {len(done)} completed"
            f" | bash={SCRIPT} param1=archive terminal=false refresh=true"
        )
    print(f"Open todo.txt | bash=/usr/bin/open param1={todo_file} terminal=false")
    print("---")
    print(f"Sorted by: {cfg['sort_by']} | color=gray size=11")


# -- Entry point ---------------------------------------------------------------


def main():
    todo_file, done_file = get_file_paths()
    cfg = load_plugin_config()
    args = sys.argv[1:]

    if not args:
        render(todo_file, done_file, cfg)
        return

    action, *rest = args

    if action == "edit":
        line_num = int(rest[0])
        task = next((t for t in read_tasks(todo_file) if t.line_num == line_num), None)
        if task:
            new_text = ask_dialog("Edit task:", task.raw)
            if new_text is not None:
                do_edit(todo_file, line_num, new_text)

    elif action == "done":
        do_done(todo_file, int(rest[0]))

    elif action == "undo":
        do_undo(todo_file, int(rest[0]))

    elif action == "archive":
        do_archive(todo_file, done_file)

    elif action == "add":
        text = ask_dialog("New task:")
        if text:
            do_add(todo_file, text)


if __name__ == "__main__":
    main()
