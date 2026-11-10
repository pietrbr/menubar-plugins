# tools

`plugins/tools.sh` shows a menu of small tools. In SwiftBar, the menu bar icon is the SF Symbol `case`.

## Requirements

- `pi` for the GPT sol engine. You must be logged in to the `openai-codex` provider.
- `claude` for the Claude Opus engine.
- The simple-english plugin for Claude Code. The Opus engine reads its `SKILL.md` from `~/.claude/plugins/marketplaces/simple-english/`.
- MarkEdit for "Open clipboard in MarkEdit".
- `pdftotext` to summarize PDF files, and `pandoc` for Word and similar files.

## Menu

Clipboard line: shows the number of characters, words, and lines of the clipboard text. When you open the menu, SwiftBar refreshes it. The line does nothing on click. Characters include spaces and line breaks. A last line without a line break counts as a line.

Open clipboard in MarkEdit: opens the clipboard in MarkEdit. If the clipboard holds a file, MarkEdit opens that file. Otherwise it opens the clipboard text.

Summarize clipboard: a click on a model summarizes the clipboard with that model. The result goes to the clipboard, and a notification shows its first line. The summary explains the content to a colleague who hears about it for the first time. Long content gets a 1-2 sentence abstract and a short summary. Shorter content gets less.

Polish text: a click on a model polishes the clipboard text with that model. The result goes to the clipboard. The tool always fixes errors and improves the phrasing toward American English. Tone and level control the rest.

Settings: opens one window for the default model, the polish tone, and the polish level. The default model has a checkmark in the menu. The settings are in `~/.config/menubar-tools/state`.

## Models

| Model         | How it runs                                                |
| ------------- | ---------------------------------------------------------- |
| GPT sol       | `pi` with the `gpt-6.1-sol` model and low thinking effort  |
| Claude Opus   | `claude` with medium effort and the simple-english rules   |

Both engines run without tools, skills, or project files. Only the Sol engine reads images.

## Clipboard content

The tools read text from the clipboard. If you copy a file in Finder, the tools read the file. Text, Markdown, PDF, and Word files work. Images work with Summarize and the GPT sol engine only.

## Polish tone

| Tone          | Result                                    |
| ------------- | ----------------------------------------- |
| Keep original | The text keeps the tone that it has.      |
| Formal        | The text becomes formal.                  |
| Friendly      | The text becomes friendly and warm.       |
| Direct        | The text becomes short and to the point.  |

## Polish level

The level sets how much the tool can change your text.

| Level    | What changes                                                                                          |
| -------- | ----------------------------------------------------------------------------------------------------- |
| Light    | Errors and small phrasing issues. The order of the ideas, the structure, and the length stay the same. |
| Balanced | Also flow and clarity. The tool can reorder ideas. It removes only clear filler and keeps at least 80% of the length. |
| Tight    | The same as Balanced, but the text becomes clearly shorter, about 60% of the length or less. Filler and repetition go. Key points stay. |

The default level is Balanced.

## Prompts

The prompts are in `tools/prompts/`. Edit `summarize.md` or `polish.md` to change the base prompt. The plugin adds the tone and level text to the polish prompt.

## Notifications

The plugin sends notifications with `osascript`, so macOS shows them as notifications from Script Editor. If no notification appears, open System Settings > Notifications and allow notifications for Script Editor.
