# mo-cli

The `master-oogway` meta CLI — manage the framework from the command line.

| Command | Description |
|---------|-------------|
| `master-oogway update` | pull latest master-oogway and re-run `install.sh` |
| `master-oogway uninstall` | run `install.sh --uninstall` (interactive) |
| `master-oogway version` | print the installed version (date + commit) |
| `master-oogway configure [args]` | open `dragon-configure` (forwards args, e.g. `--preset short`); `--edit`/`--export` re-bake the SSH payload |
| `master-oogway edit` | open `~/.zshrc` in `$EDITOR` |
| `master-oogway diff-zshrc [tool]` | diff your `~/.zshrc` against the template snapshot from your last install/update (your edits show as `+`); uses `[tool]`, else git's `diff.tool`, else `diff -u` |
| `master-oogway path` | print the master-oogway install directory |
| `master-oogway lan-ssh setup` | configure DRAGON var forwarding + LAN host aliases (see below) |
| `master-oogway lan-ssh refresh` | re-scan the LAN now and rewrite host aliases |
| `master-oogway lan-ssh status` | show cron + alias-file state |
| `master-oogway help` | list all subcommands |

Tab completion: `master-oogway` subcommands (and `lan-ssh` actions, `dragon-configure` options via `master-oogway configure`).

**Dependencies:** `python3` for `lan-ssh` host discovery — checked at call time.

## lan-ssh

`master-oogway lan-ssh setup` wires up dragon-theme forwarding across your LAN:

- Adds `SendEnv DRAGON__PAYLOAD` and `HashKnownHosts no` to `~/.ssh/config` (so your prompt travels when you SSH out, and hostnames are saved unhashed). Your whole theme is packed into one base64 var, so it stays under sshd's per-session env limit. The payload is baked from your `conf.zsh` exports; hand-editing the file leaves the payload stale (edits render locally but don't forward) until you run `dragon-configure --edit` or `--export`, which re-bake it.
- Adds `AcceptEnv DRAGON__PAYLOAD` as a validated `sshd_config.d` drop-in (sudo) so this host accepts the forwarded theme when others SSH *in*. Run setup on each machine you want covered.
- Installs a daily cron running `lan_scan.sh`, which reverse-resolves every host on your subnet and writes `~/.config/master-oogway/custom-zsh/lan-hosts.zsh` — one `alias host='ssh <flags> user@host'` per host (flags/user from `MO_LAN_SSH_FLAGS`/`MO_LAN_SSH_USER`), auto-sourced on the next shell.

### MO_LAN_SUBNETS

Tune the scan via `MO_LAN_SUBNETS`, a comma-separated list. Each entry is
either form:

| Form | Example | Sweeps |
|------|---------|--------|
| 3-octet prefix | `192.168.1` | `192.168.1.1`–`192.168.1.254` (read as `/24`) |
| CIDR | `10.0.0.0/22` | every host address in the network |

Mixing them is fine: `MO_LAN_SUBNETS="192.168.1,10.0.0.0/22"`. Unset defaults
to `192.168.1`; on `lan-ssh setup` the subnet is auto-detected from this
machine's default route instead, and baked into the cron line as
`MO_LAN_SUBNETS=<cidr>` so the nightly refresh scans the same network the
first scan did. Change it later by editing that line (`crontab -e`).

**`/20` (4094 hosts) is the widest sweep allowed.** A wider entry — a
mistyped `/8`, say — is refused with a message on stderr and skipped; other
entries in the list still run. Narrow it rather than raising the cap.

Needs `python3` (stdlib only, no nmap/dig).
