# mo-lan-ssh

LAN SSH host auto-discovery, aliases, and tab-completion for oh-my-zsh.
Two host classes: **LAN PCs** (discovered automatically) and **USB gadgets** (declared via subnet).

## What it does

- Discovers SSH hosts on the LAN using a cascade of strategies (mDNS → AXFR → nmap → arp-scan → known_hosts).
- Generates `~/.ssh/config.d/lan-hosts` — PC and gadget wildcard blocks with keepalive directives.
- Defines bare-name shell aliases for PCs (`nas`, `web`, `s-make` when a name conflicts).
- Feeds tab-completion for `ssh`/`scp`/`sftp`/`rsync` with all known PC names.
- Optionally hints (yellow) when a key probe fails for a known PC or gadget IP — never auto-runs `ssh-copy-id`.

## Quick start

```zsh
mo-lan-ssh setup     # bootstrap: Include line, optional avahi, first discovery
```

Open a new terminal to load the aliases.

## USB gadgets

Gadgets are **not scanned** — declare their subnet in `~/.zshrc`:

```zsh
MO_LAN_GADGET_SUBNETS=(192.168.7.0/24)
MO_LAN_GADGET_PORT=2222   # default
```

The plugin writes a wildcard `Host 192.168.7.*` block with `User root`, `UserKnownHostsFile /dev/null`,
`LogLevel ERROR`, and keepalive directives. Reach a gadget by IP: `ssh 192.168.7.42`.

After flashing: `ssh-copy-id 192.168.7.42` (the hint wrapper will remind you).

## Manual overlay

For hosts not found by auto-discovery (e.g. behind WireGuard, non-standard port):

```zsh
mo-lan-ssh add vpn-server:22000
mo-lan-ssh remove vpn-server
```

## Commands

| Command | Description |
|---|---|
| `mo-lan-ssh list` | All known hosts + gadget subnets |
| `mo-lan-ssh refresh` | Re-run discovery now (foreground) |
| `mo-lan-ssh refresh --background` | Background refresh |
| `mo-lan-ssh status` | Cache age, network, settings, dep state |
| `mo-lan-ssh setup` | One-time bootstrap |
| `mo-lan-ssh add <host>[:<port>]` | Add to manual overlay |
| `mo-lan-ssh remove <host>` | Remove from manual overlay |
| `mo-lan-ssh purge <host>` | Remove from all sources + known_hosts |

## Key configuration

| Variable | Default | Description |
|---|---|---|
| `MO_LAN_GADGET_SUBNETS` | — | zsh array of CIDR subnets for gadget config |
| `MO_LAN_GADGET_PORT` | `2222` | Gadget SSH port |
| `MO_LAN_AUTO_SCAN` | `on` | `off` = refresh manually only |
| `MO_LAN_TTL` | `86400` | Cache freshness in seconds |
| `MO_LAN_TRUST_HINTS` | `true` | `false` disables ssh hint wrapper |
| `MO_LAN_CONNECT_TIMEOUT` | `5` | ConnectTimeout for both PC and gadget |
| `MO_LAN_SERVER_ALIVE_INTERVAL` | `10` | ServerAliveInterval (seconds) |
| `MO_LAN_SERVER_ALIVE_COUNT_MAX` | `2` | ServerAliveCountMax (~20s drop) |
| `MO_LAN_IDENTITY` | — | IdentityFile for both PC and gadget blocks |
| `MO_LAN_SSH_PORTS` | `22` | PC ports to probe (comma list) |
| `MO_LAN_EXCLUDE` | — | Comma-list of hostnames to skip |

## Dependencies

**Hard:** `openssh-client` (`ssh`).

**Soft** (install for best discovery): `avahi-utils` (mDNS), `dnsutils` (AXFR), `nmap`, `arp-scan`.

Run `mo-lan-ssh status` to see which are present.

## Upgrade from previous version

```bash
rm -f ~/.config/master-oogway/lan-hosts*
rm -f ~/.ssh/config.d/lan-hosts
```

In `~/.zshrc`: remove `MO_LAN_AUTO_TRUST=…` (new var is `MO_LAN_TRUST_HINTS`). Then open a new shell.
