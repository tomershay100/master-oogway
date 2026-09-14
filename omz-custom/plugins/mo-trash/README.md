# mo-trash

Safer `rm` — moves files to the trash instead of deleting them immediately.
Skips silently if no trash tool is installed, leaving `rm` untouched.

- **Linux** — the FreeDesktop trash via `trash-cli`. Files show up in
  Nautilus/Files and restore to their original location natively.
- **macOS** — `~/.Trash` via `/usr/bin/trash` (macOS 14+). Finder's *Put Back*
  works as usual.

| Command | Description |
|---------|-------------|
| `rm <file>` | move to trash (overrides system `rm`) |
| `trash-list` | show trashed files with original path and deletion date, newest first |
| `trash-restore` | fzf-pick a trashed file and restore it to its original location |
| `trash-empty` | permanently delete all trash (shows size and asks for confirmation) |
| `trash-prune <days>` | permanently remove trash entries older than `<days>` days |

To bypass `rm`: use `\rm` (backslash-quoting skips aliases in any shell).

## How restore finds the original location

On Linux, `trash-cli` records the original path itself and `trash-restore` uses
it directly.

macOS does not expose one. Finder's *Put Back* location lives in a private
database inside `~/.Trash/.DS_Store` — it is in neither the file's extended
attributes nor that file's readable content. So on macOS `rm` is a shell
function rather than an alias, and it appends each original path to:

```
$MO_CONFIG_DIR/trash-index.tsv    <epoch>  <trashed-name>  <original-path>
```

Tab and newline are legal in filenames, so both path fields are stored with
`\\`, `\t` and `\n` escaped. `trash-list`, `trash-prune` and the `trash-restore`
picker show names and original paths in that same escaped, one-per-line form.

`trash-restore` reads that index and puts the file back exactly where it came
from. Files trashed by Finder are absent from it and restore to the current
directory instead, with a note saying so.

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `MO_TRASH_DIR` | FreeDesktop trash on Linux, `~/.Trash` on macOS | Trash directory. |
| `MO_TRASH_INDEX` | `$MO_CONFIG_DIR/trash-index.tsv` | Original-path index (macOS only). |

**Dependencies:** on Linux, `trash-cli` ≥ 0.22.x — `trash-prune` uses
`trash-empty --trash-dir=<dir> <days>`, which older versions lack. On macOS,
`trash`, which ships with macOS 14+. `fzf` for `trash-restore` on both.
