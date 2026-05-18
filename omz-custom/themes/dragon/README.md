# dragon theme

A fully configurable zsh prompt theme with ~130 tunable variables, an interactive wizard, and SSH forwarding.

## Configuration

```bash
dragon-configure                   # full interactive wizard
dragon-configure --new-only        # step through only newly added variables
dragon-configure --preset <name>   # switch to a preset instantly
dragon-configure --dismiss         # silence the new-variables notifier
dragon-configure --help            # show all options
```

Settings are written to `~/.config/master-oogway/conf.zsh` — never overwritten after creation.

## Presets

| Preset | Style |
|--------|-------|
| `short` | minimal — `hostname:dir$`, inline git, no rprompt extras |
| `default` | balanced — `user@host:dir ❯`, git status, time, exec timer |
| `verbose` | maximum — multiline, full paths, rich git indicators |

```bash
dragon-configure --preset default
```

To revert after a preset switch, use the backup printed by the command:

```bash
cp ~/.config/master-oogway/conf.zsh.bak ~/.config/master-oogway/conf.zsh && soursh
```

## SSH forwarding

Your theme settings travel with you over SSH to any remote machine that also runs dragon.

The installer configures both sides automatically. If you're setting up a remote manually:

```sshconfig
# ~/.ssh/config (client)
Host *
    SendEnv DRAGON__*
```

```text
# /etc/ssh/sshd_config (server)
AcceptEnv DRAGON__*
```

## All variables

The full list of `DRAGON__*` variables with defaults, types, and descriptions lives in [`schema.zsh`](schema.zsh). Every variable is also visible (with live preview) in `dragon-configure`.
