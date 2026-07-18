# mo-cli

The `master-oogway` meta CLI — manage the framework from the command line.

| Command | Description |
|---------|-------------|
| `master-oogway update` | pull latest master-oogway and re-run `install.sh` |
| `master-oogway uninstall` | run `install.sh --uninstall` (interactive) |
| `master-oogway version` | print the installed version (date + commit) |
| `master-oogway configure [args]` | open `dragon-configure` (forwards args, e.g. `--preset short`) |
| `master-oogway edit` | open `~/.zshrc` in `$EDITOR` |
| `master-oogway diff-zshrc [tool]` | diff your `~/.zshrc` against the template snapshot from your last install/update (your edits show as `+`); uses `[tool]`, else git's `diff.tool`, else `diff -u` |
| `master-oogway path` | print the master-oogway install directory |
| `master-oogway lan-ssh setup` | configure DRAGON var forwarding + LAN host aliases (see below) |
| `master-oogway lan-ssh refresh` | re-scan the LAN now and rewrite host aliases |
| `master-oogway lan-ssh status` | show cron + alias-file state |
| `master-oogway help` | list all subcommands |

## lan-ssh

`master-oogway lan-ssh setup` wires up dragon-theme forwarding across your LAN:

- Adds `SendEnv DRAGON__*` and `HashKnownHosts no` to `~/.ssh/config` (so your prompt travels when you SSH out, and hostnames are saved unhashed).
- Adds `AcceptEnv DRAGON__*` as a validated `sshd_config.d` drop-in (sudo) so this host accepts forwarded vars when others SSH *in*. Run setup on each machine you want covered.
- Installs a daily cron running `lan_scan.sh`, which reverse-resolves every host on your subnet and writes `~/.config/master-oogway/custom-zsh/lan-hosts.zsh` — one `alias host='ssh $SSH_FLAGS $USER@host'` per host, auto-sourced on the next shell.

Tune the scan by editing the config vars at the top of `lan_scan.sh` (`MO_LAN_SUBNET`, `MO_LAN_SSH_USER`, `MO_LAN_SSH_FLAGS`). `$USER` stays literal in the alias; the flags are baked in when written. Needs `nmap` (falls back to a slower `dig` loop on `/24`).
