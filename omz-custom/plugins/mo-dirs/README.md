# mo-dirs

Directory navigation helpers.

**Dependencies:** `fzf` (fcd) — checked at call time.

| Command | Description |
|---------|-------------|
| `mkcd <dir>` | `mkdir -p` then `cd` into it |
| `up [n]` | go up `n` directory levels (default 1) |
| `tmpcd` | create a temp dir and `cd` into it |
| `fcd [dir]` | fuzzy-select a subdirectory and `cd` into it |
