# mo-dirs

Directory navigation helpers.

| Command | Description |
|---------|-------------|
| `mkcd <dir>` | `mkdir -p` then `cd` into it |
| `up [n]` | go up `n` directory levels (default 1) |
| `tmpcd` | create a temp dir and `cd` into it |
| `fcd [dir]` | fuzzy-select a subdirectory and `cd` into it |
| `n` | xdg-open in the current directory |

**Dependencies:** `fzf` for `fcd` — checked at call time.
