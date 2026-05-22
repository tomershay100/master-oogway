# mo-trash

Safer `rm` — moves files to the FreeDesktop trash instead of deleting them immediately. Trashed files are visible in Nautilus/Files and can be restored.

| Command | Description |
|---------|-------------|
| `rm <file>` | move to trash (overrides system `rm`) |
| `rrm <file>` | bypass — calls the real `rm` directly |
| `trash-list` | show trashed files with original path and deletion date, newest first |
| `trash-restore` | fzf-pick a trashed file and restore it to its original location |
| `trash-empty` | permanently delete all trash (shows size and asks for confirmation) |
| `trash-prune <days>` | permanently remove trash entries older than `<days>` days |

The plugin skips silently if `trash-cli` is not installed — `rm` stays untouched.

**Dependencies:** `trash-cli` (`sudo apt install trash-cli`), `fzf` for `trash-restore`.

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `MO_TRASH_DIR` | `$XDG_DATA_HOME/Trash` (or `~/.local/share/Trash`) | Path to the FreeDesktop trash directory. Override in `conf.zsh` if your trash lives elsewhere. |
