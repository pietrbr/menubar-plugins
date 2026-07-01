# xbar-todotxt

An [xbar](https://xbarapp.com) plugin that puts your [todo.txt](http://todotxt.org) in the macOS menu bar.

## Features

- View active tasks sorted by priority, due date, project, or context
- Add tasks via a dialog (auto-stamped with creation date)
- Edit any task inline
- Mark tasks complete with one click
- Archive completed tasks to `done.txt`
- Color-coded overdue and due-today tasks
- `+project` and `@context` tag highlighting

## Requirements

- macOS with [xbar](https://xbarapp.com) installed
- Python 3

## Installation

Copy `todotxt.1m.py` to your xbar plugins directory (e.g. `~/Library/Application Support/xbar/plugins/`) and make it executable:

```bash
chmod +x todotxt.1m.py
```

Then refresh xbar.

Alternatively, symlink it from your clone so `git pull` keeps the plugin current:

```bash
ln -sfn "$(pwd)/todotxt.1m.py" ~/Library/"Application Support"/xbar/plugins/todotxt.1m.py
```

## Configuration

### File paths

The plugin reads `~/.todo/config` for the standard todo-txt shell variables:

```sh
export TODO_DIR="$HOME/todo"
export TODO_FILE="$TODO_DIR/todo.txt"
export DONE_FILE="$TODO_DIR/done.txt"
```

If the file doesn't exist, defaults are `~/todo/todo.txt` and `~/todo/done.txt`.

### Plugin settings

Create `~/.todo/todotxt-bar.ini` to override plugin-specific options:

```ini
[settings]
sort_by       = priority   ; priority | due | project | context
max_items     = 30
show_priority = true
color_project  = green     ; ANSI color name
color_context  = green     ; ANSI color name
color_overdue  = #FF6B6B   ; hex, applied to whole line
color_due_today = #FFD93D  ; hex, applied to whole line
```

## License

MIT
