# mo-lan-ssh

Auto-discovers every SSH host on your LAN, creates a short alias per host, and adds them to tab-completion. Re-scans when the cache is stale (default 24h) or you change networks.

## Commands

| Command | Description |
|---------|-------------|
| `<host>` | shorthand for `ssh <host>` — one alias per discovered host |
| `s-<host>` | fallback alias when the bare hostname conflicts with an existing command |
| `mo-lan-ssh list` | print all known hosts (auto + manual) |
| `mo-lan-ssh refresh [--background]` | re-scan the LAN |
| `mo-lan-ssh status` | show cache age, network, host counts |
| `mo-lan-ssh setup` | one-time setup: ensure `~/.ssh/config` includes `config.d/*` and run first scan |
| `mo-lan-ssh add <host>[:<port>]` | add a host to the manual overlay |
| `mo-lan-ssh remove <host>` | remove a host from the manual overlay |
| `mo-lan-ssh trust <host>` | run `ssh-copy-id` for a host |
| `mo-lan-ssh forget <host>` | remove from cache, manual overlay, `known_hosts`, and ssh-config |
| `mo-lan-ssh help` | show all subcommands and env-var options |

## How it works

**Discovery strategy** (tried in order, first to return ≥1 host wins):
1. DNS zone-transfer (AXFR)
2. `nmap` ping-sweep + reverse DNS
3. `arp-scan` (requires passwordless sudo)
4. `~/.ssh/known_hosts` parsing

Each candidate is then port-probed to confirm an SSH listener.

**SSH wrapper:** on first connect to any LAN host, automatically runs `ssh-copy-id` if no key is installed yet. If a host key changes (reinstalled machine), the old key is purged and the new one accepted. Set `MO_LAN_AUTO_TRUST=false` to disable. The wrapper only activates for LAN hosts — all other SSH connections pass through untouched.

**First run:** aliases appear on the second shell open (first scan runs in the background).

**Invalid cache entries:** the manual overlay (`~/.config/master-oogway/lan-hosts.manual`) is hand-editable, so the cache loader validates each line. Hostnames must match `[a-zA-Z0-9_-]+` and ports must be 1–65535. Invalid lines are skipped with a yellow `[mo-lan-ssh] Skipped <file>:<lineno>: …` warning on stderr so you can clean them up.

**`~/.ssh/config` Include placement:** `mo-lan-ssh setup` *appends* `Include config.d/*` at the bottom of `~/.ssh/config`. Per `ssh_config(5)`'s "first match wins" rule, any `Host <name>` you define above that Include takes precedence over the auto-generated `config.d/lan-hosts`. To override a discovered host, add a `Host <name>` block to your main `~/.ssh/config`.

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
