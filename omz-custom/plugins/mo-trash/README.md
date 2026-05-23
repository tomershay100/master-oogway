# mo-trash

Safer `rm` — moves files to the FreeDesktop trash instead of deleting them immediately. Trashed files are visible in Nautilus/Files and can be restored. Skips silently if `trash-cli` is not installed — `rm` stays untouched.

| Command | Description |
|---------|-------------|
| `rm <file>` | move to trash (overrides system `rm`) |
| `trash-list` | show trashed files with original path and deletion date, newest first |
| `trash-restore` | fzf-pick a trashed file and restore it to its original location |
| `trash-empty` | permanently delete all trash (shows size and asks for confirmation) |
| `trash-prune <days>` | permanently remove trash entries older than `<days>` days |

To bypass `rm`: use `\rm` (backslash-quoting skips aliases in any shell).

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `MO_TRASH_DIR` | `$XDG_DATA_HOME/Trash` (or `~/.local/share/Trash`) | Path to the FreeDesktop trash directory. |

**Dependencies:** `trash-cli` (`sudo apt install trash-cli`), `fzf` for `trash-restore`.
