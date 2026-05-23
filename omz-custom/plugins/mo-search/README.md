# mo-search

Search helpers and fuzzy pickers. Also configures `FZF_DEFAULT_OPTS`, `FZF_CTRL_T_OPTS`, `FZF_ALT_C_OPTS`, and `FZF_DEFAULT_COMMAND` — all guarded, silently skipped if the required tools are absent.

| Command | Description |
|---------|-------------|
| `grep` / `grepi` | colorized grep — case-sensitive / case-insensitive |
| `f <pattern>` | find files by name (shortcut for `find . \| grepi <pattern>`) |
| `fhist` | fuzzy-select a past command and load it onto the prompt |
| `fman` | fuzzy-select and open a man page |
| `frg` | fuzzy ripgrep across file contents; opens result in `$EDITOR` |

**Dependencies:** `fzf` for `fhist`, `fman`, `frg`, and env vars; `rg` for `frg`; `bat`/`batcat` for preview; `fd`/`fdfind` for default command — all optional, each checked at call time.
