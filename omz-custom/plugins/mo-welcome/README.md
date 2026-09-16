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
| `os`   | distro name / macOS version | `/etc/os-release` on Linux, `sw_vers` on macOS |
| `sys`  | kernel version | `/proc/sys/kernel/osrelease` on Linux, `uname -r` on macOS |
| `now`  | date + time | |
| `up`   | uptime | |
| `ip`   | local LAN IP | first non-loopback address |
| `shell`| zsh version | |
| `load` | `0.91 load · 4 cores · 23% busy` | green/yellow/red by %. On Apple Silicon the core count is split by tier, e.g. `6S+12P` — the tier names are read from the chip, since M1–M4 report Performance/Efficiency and M5 reports Super/Performance |
| `mem`  | `8.3 / 15.4 GB (54%)` | `/proc/meminfo` on Linux; `hw.memsize` plus `vm_stat` on macOS, counting active + wired + compressed, which is what Activity Monitor calls memory in use |
| `disk` | `/ at 42%` | green/yellow/red at 70/90. On macOS this measures `/System/Volumes/Data`, not `/`: the root volume is a sealed read-only snapshot that always reads a couple of percent |
| `arch` | `arm64` | `uname -m` |
| `tmux` | tmux session name | hidden when not in tmux |
| `ssh`  | remote user@host plus source IP you connected from | hidden when not in an SSH session |

Order is preserved — fields print top-to-bottom as listed. Context-aware fields (`tmux`, `ssh`) emit nothing when their condition isn't met, so they can be listed unconditionally.
