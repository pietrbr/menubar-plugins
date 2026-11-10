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

PI_PROVIDER=openai-codex
PI_MODEL=gpt-6.1-sol
PI_THINKING=low
CLAUDE_MODEL=opus
CLAUDE_EFFORT=medium

ENGINE_SOL=sol
ENGINE_OPUS=opus
ENGINE_OPTIONS="$ENGINE_SOL:GPT sol (light),$ENGINE_OPUS:Claude Opus (medium)"
TONE_OPTIONS="original:Keep original,formal:Formal,friendly:Friendly,direct:Direct"
LEVEL_OPTIONS="light:Light - fix errors and keep order and length,balanced:Balanced - clearer flow and little shortening,tight:Tight - like Balanced but clearly shorter"

default_engine=$ENGINE_SOL
polish_tone=original
polish_level=balanced

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
    "Polish level|$polish_level|$LEVEL_OPTIONS")
  if [ -z "$result" ]; then
    return
  fi
  set -- $result
  set_state default_engine "$1"
  set_state polish_tone "$2"
  set_state polish_level "$3"
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
read_input() {
  ATTACH=
  ERROR=
  path=$(clipboard_file)
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
  case $polish_level in
    light)
      echo "Change as little as possible. Keep the order, the structure, and the length of the ideas."
      ;;
    tight)
      echo "Improve flow and clarity. Reorder or restructure the ideas if that reads better."
      echo "Shorten the text clearly. Aim for about 60% of the original length or less."
      echo "Remove filler, repetition, and side remarks, but keep every key point and request."
      ;;
    *)
      echo "Improve flow and clarity. Reorder or restructure the ideas if that reads better."
      echo "Shorten lightly: remove only clear filler. Keep at least 80% of the original length. Do not cut content or detail."
      ;;
  esac
}

run_pi() {
  if [ -n "$ATTACH" ]; then
    source_file=$ATTACH
  else
    source_file=$2
  fi
  pi -p --no-session --no-tools --no-extensions --no-skills --no-context-files \
    --no-prompt-templates --no-mcp \
    --provider "$PI_PROVIDER" --model "$PI_MODEL" --thinking "$PI_THINKING" \
    --system-prompt "$(cat "$1")" @"$source_file" "Process the attached content as instructed." </dev/null
}

run_claude() {
  claude -p --safe-mode --no-session-persistence --tools "" \
    --model "$CLAUDE_MODEL" --effort "$CLAUDE_EFFORT" \
    --system-prompt "$(cat "$1" "$SIMPLE_ENGLISH_SKILL")" <"$2"
}

run_tool() {
  load_state
  tool=$1
  engine=${2:-$default_engine}
  case $tool in
    summarize) label=Summarize ;;
    polish) label=Polish ;;
  esac

  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT
  input="$work/input.txt"
  system_prompt="$work/system.md"
  output="$work/output.md"

  read_input "$input"
  if [ -n "$ERROR" ]; then
    notify "$label: $ERROR"
    exit 1
  fi
  if [ -z "$ATTACH" ] && [ ! -s "$input" ]; then
    notify "$label: clipboard is empty."
    exit 1
  fi
  if [ -n "$ATTACH" ] && { [ "$tool" = polish ] || [ "$engine" = "$ENGINE_OPUS" ]; }; then
    notify "$label: images work only with summarize and the sol engine."
    exit 1
  fi

  if [ "$tool" = polish ]; then
    build_polish_prompt >"$system_prompt"
  else
    cp "$PROMPTS/summarize.md" "$system_prompt"
  fi

  if [ "$engine" = "$ENGINE_OPUS" ] && [ ! -f "$SIMPLE_ENGLISH_SKILL" ]; then
    notify "$label: missing $SIMPLE_ENGLISH_SKILL"
    exit 1
  fi

  notify "$label: running with $engine..."
  cd "$work" || exit 1
  if [ "$engine" = "$ENGINE_OPUS" ]; then
    run_claude "$system_prompt" "$input" >"$output" 2>"$work/error.txt"
  else
    run_pi "$system_prompt" "$input" >"$output" 2>"$work/error.txt"
  fi
  status=$?

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

option_title() {
  echo "$2" | tr ',' '\n' | sed -n "s/^$1:\(.*\)/\1/p"
}

run_items() {
  for engine in $ENGINE_SOL $ENGINE_OPUS; do
    printf -- "--%s | bash='%s' param1=run param2=%s param3=%s terminal=false" \
      "$(option_title "$engine" "$ENGINE_OPTIONS")" "$SELF" "$1" "$engine"
    if [ "$engine" = "$default_engine" ]; then
      printf ' checked=true'
    fi
    echo
  done
}

echo ":case:"
echo "---"
echo "Clipboard: $(count_clipboard)"
echo "Open clipboard in MarkEdit | bash='$SELF' param1=open terminal=false"
echo "---"
echo "Summarize clipboard"
run_items summarize
echo "Polish text"
run_items polish
echo "-----"
level_title=$(option_title "$polish_level" "$LEVEL_OPTIONS")
echo "--$(option_title "$polish_tone" "$TONE_OPTIONS"), ${level_title%% - *} level"
echo "---"
echo "Settings... | bash='$SELF' param1=settings terminal=false refresh=true"
