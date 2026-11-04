# menubar-plugins

Plugins that add small tools to the macOS menu bar. Each plugin is one script that a menu bar runner shows as a menu. The author tests the plugins with SwiftBar.

The plugins use the xbar plugin format. They can also work in xbar, but the author does not test them there.

Links: [SwiftBar](https://github.com/swiftbar/SwiftBar), [xbar](https://xbarapp.com).

## Plugins

| Plugin                  | Menu                                                                 | Documentation                      |
| ----------------------- | -------------------------------------------------------------------- | ---------------------------------- |
| `plugins/todotxt.1m.py` | Your todo.txt tasks: view, add, edit, complete, archive              | [docs/todotxt.md](docs/todotxt.md) |
| `plugins/tools.sh`      | Clipboard tools, for example a count of characters, words, and lines | [docs/tools.md](docs/tools.md)     |

## Requirements

- macOS
- SwiftBar
- Python 3 for `todotxt.1m.py`

## Installation

1. Install SwiftBar with `brew install --cask swiftbar`.
2. Open SwiftBar and choose a plugin folder, for example `~/Library/Application Support/SwiftBar/plugins`.
3. Clone this repository.
4. In the clone, link each plugin that you want into the plugin folder:

   ```sh
   ln -sfn "$(pwd)/plugins/todotxt.1m.py" ~/Library/"Application Support"/SwiftBar/plugins/todotxt.1m.py
   ```

5. In the SwiftBar menu, select Refresh All.

Because the plugin folder holds links, a `git pull` in the clone updates the plugins.

To use all plugins in this repository, you can choose the `plugins` folder of the clone as the SwiftBar plugin folder. Then you do not need links.

The file name controls how often SwiftBar runs a plugin. For example, `todotxt.1m.py` runs every minute. To change the interval, give the link a different name, for example `todotxt.5m.py`.

## License

MIT
