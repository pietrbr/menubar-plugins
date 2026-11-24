# tools

`plugins/tools.sh` shows a menu of small tools. In SwiftBar, the menu bar icon is the SF Symbol `case`.

## Requirements

- `codex` for the GPT sol engine. You must be logged in to Codex.
- `claude` for the Claude Opus engine.
- A llama.cpp server at `127.0.0.1:8080` with the `qwen9` model for the Qwen engine. You also need `jq`.
- The simple-english plugin for Claude Code. The Opus engine reads its `SKILL.md` from `~/.claude/plugins/marketplaces/simple-english/`.
- MarkEdit for "Open clipboard in MarkEdit".
- `pdftotext` to summarize PDF files, and `pandoc` for Word and similar files.

## Menu

Clipboard line: shows the number of characters, words, and lines of the clipboard text. When you open the menu, SwiftBar refreshes it. The line does nothing on click. Characters include spaces and line breaks. A last line without a line break counts as a line.

Open clipboard in MarkEdit: opens the clipboard in MarkEdit. If the clipboard holds a file, MarkEdit opens that file. Otherwise it opens the clipboard text.

Summarize clipboard: one click summarizes the clipboard with the default model. The result goes to the clipboard, and a notification shows its first line. The summary explains the content to a colleague who hears about it for the first time. Long content gets a 1-2 sentence abstract and a short summary. Shorter content gets less.

Polish text: one click polishes the clipboard text with the default model, tone, and style. The menu item shows the current settings in brackets after its name. The result goes to the clipboard. The tool always fixes errors and improves the phrasing toward American English. Tone and style control the rest. If the text is a conversation, such as an email thread, the tool polishes only the newest message and uses the rest as context.

Settings: opens one window for the default model, the polish tone, and the polish style. All tools use these settings, so you set them once. The settings are in `~/.config/menubar-tools/state`.

## Models

| Model         | How it runs                                                                  |
| ------------- | ---------------------------------------------------------------------------- |
| GPT sol       | `codex exec` with the `gpt-6.1-sol` model and low reasoning effort           |
| Claude Opus   | `claude` with medium effort and the simple-english rules                     |
| Qwen 9B       | A direct request to the local llama.cpp server, with thinking turned off     |

The engines run without tools, skills, plugins, or your global instructions. Codex uses its own settings folder, `~/.config/menubar-tools/codex-home`, which links only to your Codex login file. Only the Sol engine reads images.

## Clipboard content

The tools read text from the clipboard. If you copy a file in Finder, the tools read the file. Text, Markdown, PDF, and Word files work. Images work with Summarize and the GPT sol engine only.

## Polish tone

| Tone          | Result                                    |
| ------------- | ----------------------------------------- |
| Keep original | The text keeps the tone that it has.      |
| Formal        | The text becomes formal.                  |
| Friendly      | The text becomes friendly and warm.       |
| Direct        | The text becomes short and to the point.  |

## Polish style

The style sets what kind of edit the tool makes.

| Style               | What changes                                                                                              |
| ------------------- | --------------------------------------------------------------------------------------------------------- |
| Proofread           | Errors and a few words. The order of the ideas, the structure, and the length stay the same.               |
| Polish              | Also flow and clarity. The tool can reorder ideas. It removes only clear filler and keeps at least 80% of the length. |
| Polish and shorten  | The same as Polish, but the text becomes about 60% of the length or less. Filler and repetition go. Key points stay. |

The default style is Polish.

## Prompts

The prompts are in `tools/prompts/`. Edit `summarize.md` or `polish.md` to change the base prompt. Each polish style has its own file, for example `polish-polish.md`. The plugin adds the tone line and the style file to the polish prompt.

## Notifications

The plugin sends notifications with `osascript`, so macOS shows them as notifications from Script Editor. If no notification appears, open System Settings > Notifications and allow notifications for Script Editor.
