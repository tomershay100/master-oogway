# mo-search

Search helpers and fuzzy pickers.

| Command | Description |
|---------|-------------|
| `grep` / `grepi` | colorized grep — case-sensitive / case-insensitive |
| `f <pattern>` | find files matching pattern (shortcut for `find . | grepi <pattern>`) |
| `fhist` | fuzzy-select a past command and load it onto the prompt |
| `fman` | fuzzy-select and open a man page |
| `frg` | fuzzy ripgrep across file contents; opens result in `$EDITOR` |

**Dependencies:** `fzf` (fhist, fman, frg), `rg` (frg) — checked at call time.
