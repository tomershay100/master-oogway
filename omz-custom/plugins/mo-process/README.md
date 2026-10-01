# mo-process

Process management helpers.

| Command | Description |
|---------|-------------|
| `psgrep <name>` | list running processes matching name (case-sensitive, full command line); `-a/--all` for case-insensitive matching |
| `port <n>` | show which process is listening on port `n` |
| `fkill [signal]` | fuzzy-select one or more processes to kill (TAB for multi-select; default SIGTERM) |
| `connected [-v\|-vv]` | list machines currently SSH-ed into this host; `-v` adds TTY, source IP:port, PID and login time; `-vv` adds connection duration and a `ps` listing per session TTY |

**Dependencies:** `pgrep` for `psgrep`; `lsof` for `port`; `fzf` for `fkill`; `ps` for `connected -vv`. `connected -v` resolves the peer socket with `ss` on Linux and `netstat` on macOS, via `_mo_ssh_peer`. Each is checked at call time.
