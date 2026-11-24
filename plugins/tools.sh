#!/bin/sh
# <xbar.title>Tools</xbar.title>
# <xbar.desc>Quick clipboard tools.</xbar.desc>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.refreshOnOpen>true</swiftbar.refreshOnOpen>

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

SELF=$(readlink -f "$0")
TOOLS_DIR="$(dirname "$SELF")/../tools"
PROMPTS="$TOOLS_DIR/prompts"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/menubar-tools"
STATE_FILE="$STATE_DIR/state"
VIEW_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/menubar-tools/clipboard.md"
SIMPLE_ENGLISH_SKILL="$HOME/.claude/plugins/marketplaces/simple-english/skills/simple-english/SKILL.md"

CODEX_MODEL=gpt-6.1-sol
CODEX_EFFORT=low
QWEN_MODEL=qwen9
LLAMA_URL=http://127.0.0.1:8080/v1/chat/completions
CLAUDE_MODEL=opus
CLAUDE_EFFORT=medium
RUN_TIMEOUT_SECONDS=120
TIMEOUT_STATUS=142
LOCK_DIR="$STATE_DIR/lock"
# shortcut: shares auth.json by symlink, copy it if a token refresh replaces the link.
CODEX_HOME_DIR="$STATE_DIR/codex-home"

ENGINE_SOL=sol
ENGINE_OPUS=opus
ENGINE_QWEN=qwen
ENGINE_OPTIONS="$ENGINE_SOL:GPT sol (light),$ENGINE_OPUS:Claude Opus (medium),$ENGINE_QWEN:Qwen 9B (local)"
TONE_OPTIONS="original:Keep original,formal:Formal,friendly:Friendly,direct:Direct"
STYLE_OPTIONS="proofread:Proofread - fix errors and change a few words,polish:Polish - clearer flow and little shortening,polish_shorten:Polish and shorten - clearer flow and about 60% of the length"

default_engine=$ENGINE_SOL
polish_tone=original
polish_style=polish

notify() {
  osascript \
    -e 'on run argv' \
    -e 'display notification (item 1 of argv) with title "Tools"' \
    -e 'end run' -- "$1"
}

load_state() {
  if [ -f "$STATE_FILE" ]; then
    . "$STATE_FILE"
  fi
}

set_state() {
  case $2 in
  *[!a-z0-9_]* | "")
    return 1
    ;;
  esac
  mkdir -p "$STATE_DIR"
  tmp=$(mktemp)
  if [ -f "$STATE_FILE" ]; then
    grep -v "^$1=" "$STATE_FILE" >"$tmp"
  fi
  echo "$1=$2" >>"$tmp"
  mv "$tmp" "$STATE_FILE"
}

open_settings() {
  load_state
  result=$(osascript -l JavaScript "$TOOLS_DIR/settings.js" \
    "Default model|$default_engine|$ENGINE_OPTIONS" \
    "Polish tone|$polish_tone|$TONE_OPTIONS" \
    "Polish style|$polish_style|$STYLE_OPTIONS")
  if [ -z "$result" ]; then
    return
  fi
  # shellcheck disable=SC2086 # settings.js prints one value per line.
  set -- $result
  set_state default_engine "$1"
  set_state polish_tone "$2"
  set_state polish_style "$3"
}

count_clipboard() {
  tmp=$(mktemp)
  pbpaste >"$tmp"
  chars=$(wc -m <"$tmp" | tr -d ' ')
  words=$(wc -w <"$tmp" | tr -d ' ')
  lines=$(awk 'END { print NR }' "$tmp")
  rm -f "$tmp"
  echo "$chars chars, $words words, $lines lines"
}

clipboard_file() {
  path=$(osascript \
    -e 'try' \
    -e 'POSIX path of (the clipboard as «class furl»)' \
    -e 'on error' \
    -e '""' \
    -e 'end try' 2>/dev/null)
  if [ -e "$path" ]; then
    echo "$path"
  fi
}

open_clipboard() {
  path=$(clipboard_file)
  if [ -n "$path" ]; then
    open -a MarkEdit "$path"
    return
  fi
  mkdir -p "$(dirname "$VIEW_FILE")"
  pbpaste >"$VIEW_FILE"
  open -a MarkEdit "$VIEW_FILE"
}

# Sets ATTACH to an image path, or writes text to $1. Sets ERROR on failure.
# Sets FROM_FILE to the copied file, if any.
read_input() {
  ATTACH=
  ERROR=
  path=$(clipboard_file)
  FROM_FILE=$path
  if [ -z "$path" ]; then
    pbpaste >"$1"
    return
  fi
  case $(file -b --mime-type "$path") in
  application/pdf)
    pdftotext -layout "$path" "$1" 2>/dev/null || ERROR="pdftotext failed."
    ;;
  image/*)
    ATTACH=$path
    ;;
  text/* | application/json | application/xml)
    cp "$path" "$1"
    ;;
  *)
    pandoc -t plain "$path" -o "$1" 2>/dev/null || ERROR="Unsupported file type."
    ;;
  esac
}

build_polish_prompt() {
  cat "$PROMPTS/polish.md"
  echo
  if [ "$polish_tone" = original ]; then
    echo "Keep the original tone."
  else
    echo "Change the tone to $polish_tone."
  fi
  cat "$PROMPTS/polish-$polish_style.md"
}

with_timeout() {
  perl -e 'alarm shift; exec @ARGV' "$RUN_TIMEOUT_SECONDS" "$@"
}

acquire_lock() {
  mkdir -p "$STATE_DIR"
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    holder=$(cat "$LOCK_DIR/pid" 2>/dev/null)
    if [ -z "$holder" ] || kill -0 "$holder" 2>/dev/null; then
      return 1
    fi
    rm -rf "$LOCK_DIR"
    mkdir "$LOCK_DIR" || return 1
  fi
  echo $$ >"$LOCK_DIR/pid"
}

run_codex() {
  codex_prompt=$(cat "$1")
  codex_input=$2
  mkdir -p "$CODEX_HOME_DIR"
  [ -e "$CODEX_HOME_DIR/auth.json" ] || ln -s "$HOME/.codex/auth.json" "$CODEX_HOME_DIR/auth.json"
  set -- env CODEX_HOME="$CODEX_HOME_DIR" codex exec --ephemeral --skip-git-repo-check \
    -s read-only -m "$CODEX_MODEL" -c model_reasoning_effort="$CODEX_EFFORT" \
    -c features.shell_tool=false -c features.unified_exec=false -c web_search=disabled
  if [ -n "$ATTACH" ]; then
    with_timeout "$@" --image="$ATTACH" -- "$codex_prompt" </dev/null
  else
    with_timeout "$@" -- "$codex_prompt" <"$codex_input"
  fi
}

run_qwen() {
  jq -n --rawfile system "$1" --rawfile user "$2" --arg model "$QWEN_MODEL" \
    '{model: $model, chat_template_kwargs: {enable_thinking: false},
      messages: [{role: "system", content: $system}, {role: "user", content: $user}]}' >request.json
  with_timeout curl -sS --fail-with-body --connect-timeout 5 "$LLAMA_URL" -H 'Content-Type: application/json' -d @request.json \
    >response.json || return
  jq -r '.choices[0].message.content // error(.error.message // "no answer")' response.json
}

run_claude() {
  with_timeout claude -p --safe-mode --no-session-persistence --tools "" \
    --model "$CLAUDE_MODEL" --effort "$CLAUDE_EFFORT" \
    --system-prompt "$(cat "$1")" <"$2"
}

run_tool() {
  load_state
  tool=$1
  engine=${2:-$default_engine}
  case $tool in
  summarize) label=Summarize ;;
  polish) label=Polish ;;
  esac

  if ! acquire_lock; then
    notify "$label: already running."
    exit 1
  fi
  work=$(mktemp -d)
  trap 'rm -rf "$work" "$LOCK_DIR"' EXIT
  input="$work/input.txt"
  system_prompt="$work/system.md"
  output="$work/output.md"

  read_input "$input"
  if [ -n "$ERROR" ]; then
    notify "$label: $ERROR"
    exit 1
  fi
  if [ -z "$ATTACH" ] && ! grep -q '[^[:space:]]' "$input"; then
    if [ -n "$FROM_FILE" ]; then
      notify "$label: no text found in the file."
    else
      notify "$label: clipboard is empty."
    fi
    exit 1
  fi
  if [ -n "$ATTACH" ] && { [ "$tool" = polish ] || [ "$engine" != "$ENGINE_SOL" ]; }; then
    notify "$label: images work only with summarize and the sol engine."
    exit 1
  fi

  if [ "$tool" = polish ]; then
    build_polish_prompt >"$system_prompt"
  else
    cp "$PROMPTS/summarize.md" "$system_prompt"
  fi

  if [ "$engine" = "$ENGINE_OPUS" ] && [ "$tool" = summarize ]; then
    if [ ! -f "$SIMPLE_ENGLISH_SKILL" ]; then
      notify "$label: missing $SIMPLE_ENGLISH_SKILL"
      exit 1
    fi
    cat "$SIMPLE_ENGLISH_SKILL" >>"$system_prompt"
  fi

  notify "$label: running with $engine..."
  cd "$work" || exit 1
  case $engine in
  "$ENGINE_OPUS") run_claude "$system_prompt" "$input" ;;
  "$ENGINE_QWEN") run_qwen "$system_prompt" "$input" ;;
  *) run_codex "$system_prompt" "$input" ;;
  esac >"$output" 2>"$work/error.txt"
  status=$?

  if [ "$status" -eq "$TIMEOUT_STATUS" ]; then
    notify "$label failed: no answer after $RUN_TIMEOUT_SECONDS seconds."
    exit 1
  fi
  if [ "$status" -ne 0 ] || [ ! -s "$output" ]; then
    notify "$label failed: $(tr '\n' ' ' <"$work/error.txt" | cut -c 1-200)"
    exit 1
  fi
  pbcopy <"$output"
  notify "$label done: $(head -n 1 "$output" | cut -c 1-100)"
}

case "$1" in
open)
  open_clipboard
  exit 0
  ;;
run)
  run_tool "$2" "$3"
  exit 0
  ;;
settings)
  open_settings
  exit 0
  ;;
esac

load_state

echo ":case:"
echo "---"
echo "Clipboard: $(count_clipboard)"
echo "Open clipboard in MarkEdit | bash='$SELF' param1=open terminal=false"
echo "---"
engine_label=$(echo "$default_engine" | awk '{ print toupper(substr($0, 1, 1)) substr($0, 2) }')
echo "Summarize clipboard  -  [$engine_label] | bash='$SELF' param1=run param2=summarize terminal=false"
echo "Polish text  -  [$engine_label, $polish_tone tone, $(echo "$polish_style" | sed 's/_/ + /') style] | bash='$SELF' param1=run param2=polish terminal=false"
echo "---"
echo "Settings... | bash='$SELF' param1=settings terminal=false refresh=true"
