#!/bin/sh
# <xbar.title>Tools</xbar.title>
# <xbar.desc>Quick clipboard tools.</xbar.desc>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

notify() {
  osascript -e "display notification \"$1\" with title \"Tools\""
}

count_clipboard() {
  tmp=$(mktemp)
  pbpaste >"$tmp"
  chars=$(wc -m <"$tmp" | tr -d ' ')
  words=$(wc -w <"$tmp" | tr -d ' ')
  lines=$(awk 'END { print NR }' "$tmp")
  rm -f "$tmp"
  notify "$chars chars, $words words, $lines lines"
}

if [ "$1" = "count" ]; then
  count_clipboard
  exit 0
fi

echo ":wrench.and.screwdriver:"
echo "---"
echo "Count clipboard | bash='$0' param1=count terminal=false"
