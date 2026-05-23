# mo-search

Search helpers and fuzzy pickers.

| Command | Description |
|---------|-------------|
| `grep` / `grepi` | colorized grep — case-sensitive / case-insensitive |
| `f <pattern>` | find files matching pattern (shortcut for `find . | grepi <pattern>`) |
| `fhist` | fuzzy-select a past command and load it onto the prompt |
| `fman` | fuzzy-select and open a man page |
| `frg` | fuzzy ripgrep across file contents; opens result in `$EDITOR` |

Also configures `FZF_DEFAULT_OPTS`, `FZF_CTRL_T_OPTS`, `FZF_ALT_C_OPTS`, and `FZF_DEFAULT_COMMAND` — all guarded, silently skipped if fzf/fd/bat are not installed.

**Dependencies:** `fzf` (fhist, fman, frg, env vars), `rg` (frg), `bat`/`batcat` (preview), `fd`/`fdfind` (default command) — all optional.
