# mo-welcome

Prints a system snapshot banner on every shell open. No commands — runs automatically at startup.

```
  host   user @ hostname
  os     Ubuntu 24.04.2 LTS
  sys    6.8.0-57-generic
  now    Sat, 24 May 2025 · 09:41
  up     3d 2h 17m
```

## Configuration

Set `MO_WELCOME_FIELDS` (space-separated) to choose which fields appear and in what order:

```zsh
# ~/.zshrc or ~/.config/master-oogway/conf.zsh
MO_WELCOME_FIELDS="host os now up"          # default without kernel
MO_WELCOME_FIELDS="host os sys now up ip"   # add local IP
MO_WELCOME_FIELDS="tmux ssh host now"       # context fields first
MO_WELCOME_FIELDS=""                        # silence the banner
```

## Fields

| Token  | Shows | Notes |
|--------|-------|-------|
| `host` | `user @ hostname` | |
| `os`   | distro name | from `/etc/os-release` |
| `sys`  | kernel version | `uname -r` |
| `now`  | date + time | |
| `up`   | uptime | |
| `ip`   | local LAN IP | first non-loopback address |
| `shell`| zsh version | |
| `load` | 1-min load average | from `/proc/loadavg` |
| `mem`  | used / total RAM | from `/proc/meminfo` |
| `tmux` | tmux session name | hidden when not in tmux |
| `ssh`  | remote user@host label | hidden when not in an SSH session |

Order is preserved — fields print top-to-bottom as listed. Context-aware fields (`tmux`, `ssh`) emit nothing when their condition isn't met, so they can be listed unconditionally.
