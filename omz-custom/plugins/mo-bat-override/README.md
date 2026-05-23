# mo-bat-override

Replaces `cat` and `less` with `bat` (syntax-highlighted viewer). Falls back to the system commands if `bat`/`batcat` is not installed.

Also sets `BAT_THEME` and `MANPAGER` so `man` pages render through bat.

**Dependencies:** `bat` or `batcat` — falls back to system `cat`/`less` if neither is installed.

| Escape hatch | Bypasses to |
|---|---|
| `rcat` or `\cat` | system `cat` |
| `rless` or `\less` | system `less` |

| Command | Description |
|---------|-------------|
| `pcat` | `bat` with full decorations (headers, line numbers, git markers) |
| `pless` | `bat` pager with headers, grid, and git markers (no line numbers) |
