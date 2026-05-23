# mo-bat-override

Replaces `cat` and `less` with `bat` (syntax-highlighted viewer). Also sets `BAT_THEME` and `MANPAGER` so `man` pages render through bat. No-op if `bat`/`batcat` is not installed.

| Command | Description |
|---------|-------------|
| `cat` | `bat` with no paging, plain output |
| `less` | `bat` pager, plain output |
| `pcat` | `bat` with full decorations (headers, line numbers, git markers) |
| `pless` | `bat` pager with full decorations (headers, line numbers, grid, git markers) |

To bypass: use `\cat` or `\less` (backslash-quoting skips aliases in any shell).

**Dependencies:** `bat` or `batcat`.
