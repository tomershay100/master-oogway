# mo-process

Process management helpers.

| Command | Description |
|---------|-------------|
| `psgrep <name>` | list running processes matching name (case-sensitive, full command line); `-a/--all` for case-insensitive matching |
| `port <n>` | show which process is listening on port `n` |
| `fkill [signal]` | fuzzy-select one or more processes to kill (TAB for multi-select; default SIGTERM) |
| `connected [-v]` | list machines currently SSH-ed into this host; `-v` adds TTY, source IP:port, PID and login time |

**Dependencies:** `pgrep` for `psgrep`; `lsof` for `port`; `fzf` for `fkill`; `ss` for `connected -v` — each checked at call time.
