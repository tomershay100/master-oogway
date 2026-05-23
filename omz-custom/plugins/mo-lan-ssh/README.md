# mo-lan-ssh

Auto-discovers every SSH host on your LAN, creates a short alias per host, and adds them to tab-completion. Re-scans when the cache is stale (default 24h) or you change networks.

| Command | Description |
|---------|-------------|
| `<host>` | shorthand for `ssh <host>` — one alias per discovered host |
| `s-<host>` | fallback alias when the bare hostname conflicts with an existing command |
| `mo-lan-ssh setup` | one-time setup: add `Include config.d/*` to `~/.ssh/config` and run first scan |
| `mo-lan-ssh list` | print all known hosts (auto-discovered + manual) |
| `mo-lan-ssh refresh [--background]` | re-scan the LAN now |
| `mo-lan-ssh status` | show cache age, current network, and host counts |
| `mo-lan-ssh add <host>[:<port>]` | add a host to the manual overlay |
| `mo-lan-ssh remove <host>` | remove a host from the manual overlay |
| `mo-lan-ssh trust <host>` | run `ssh-copy-id` for a host |
| `mo-lan-ssh forget <host>` | remove from cache, manual overlay, `known_hosts`, and ssh-config |
| `mo-lan-ssh help` | show all subcommands and env-var options |

## How it works

**Discovery strategy** (tried in order; first to return ≥1 host wins):
1. DNS zone-transfer (AXFR)
2. `nmap` ping-sweep + reverse DNS
3. `arp-scan` (requires passwordless sudo)
4. `~/.ssh/known_hosts` parsing

Each candidate is then port-probed to confirm an SSH listener.

**SSH wrapper:** on first connect to any LAN host, automatically runs `ssh-copy-id` if no key is installed yet. If a host key changes (reinstalled machine), the old key is purged and the new one accepted. Set `MO_LAN_AUTO_TRUST=false` to disable. The wrapper only activates for LAN hosts — all other SSH connections pass through untouched.

**First run:** aliases appear on the second shell open (first scan runs in the background).

**`~/.ssh/config` Include placement:** `mo-lan-ssh setup` appends `Include config.d/*` at the bottom of `~/.ssh/config`. Per `ssh_config(5)`'s "first match wins" rule, any `Host <name>` block you define above that line takes precedence over the auto-generated entries.

## Configuration

Set in `~/.zshrc` or `~/.config/master-oogway/custom-pre-zsh/` before the plugin loads:

| Variable | Default | Description |
|----------|---------|-------------|
| `MO_LAN_TTL` | `86400` | cache TTL in seconds |
| `MO_LAN_SSH_PORTS` | `22` | comma-separated ports to probe |
| `MO_LAN_PROBE_TIMEOUT` | `2` | per-host SSH probe timeout (seconds) |
| `MO_LAN_PROBE_PARALLEL` | `20` | parallel probe connections |
| `MO_LAN_EXCLUDE` | — | comma-separated hosts/IPs to skip |
| `MO_LAN_SUBNET` | auto | CIDR subnet to scan |
| `MO_LAN_DNS_SERVER` | auto | DNS server for AXFR |
| `MO_LAN_DNS_ZONE` | auto | DNS zone for AXFR |
| `MO_LAN_AUTO_TRUST` | `true` | auto ssh-copy-id + key rotation on LAN hosts |
| `MO_LAN_VERBOSE` | `false` | print discovery progress |

**Dependencies:** `dig` for AXFR; at least one of `nmap`, `arp-scan`, or `~/.ssh/known_hosts` for host discovery.
