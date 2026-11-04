# todotxt

`plugins/todotxt.1m.py` shows your [todo.txt](http://todotxt.org) tasks in the menu bar. The menu bar title shows the number of active tasks and the number of overdue tasks.

## Features

- View active tasks sorted by priority, due date, project, or context
- Add tasks in a dialog, with the creation date added
- Edit any task in a dialog
- Mark a task complete: hold Option and click the task
- Archive completed tasks to `done.txt`
- Overdue tasks and tasks due today in color
- `+project` and `@context` tags in color

## Configuration

### File paths

The plugin reads the standard todo-txt shell variables from `~/.todo/config`:

```sh
export TODO_DIR="$HOME/todo"
export TODO_FILE="$TODO_DIR/todo.txt"
export DONE_FILE="$TODO_DIR/done.txt"
```

If that file does not exist, the plugin uses `~/todo/todo.txt` and `~/todo/done.txt`.

### Plugin configuration

To change the plugin configuration, create `~/.todo/todotxt-bar.ini`:

```ini
[settings]
sort_by       = priority   ; priority | due | project | context
max_items     = 30
show_priority = true
```
