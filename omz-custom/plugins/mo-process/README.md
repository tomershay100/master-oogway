# mo-process

Process management helpers.

| Command | Description |
|---------|-------------|
| `psgrep <name>` | list running processes matching name (case-insensitive, full command line) |
| `port <n>` | show which process is listening on port `n` (retries with sudo if needed) |
| `fkill [signal]` | fuzzy-select one or more processes to kill (TAB for multi-select; default SIGTERM) |

**Dependencies:** `pgrep` for `psgrep`; `lsof` for `port`; `fzf` for `fkill` — each checked at call time.
