# dragon theme

A fully configurable zsh prompt theme with ~130 tunable variables, an interactive wizard, and SSH forwarding.

## Configuration

```bash
dragon-configure                   # full interactive wizard
dragon-configure --pick            # TUI preset browser — arrow keys, live preview, Enter to apply
dragon-configure --new-only        # step through only newly added variables
dragon-configure --preset <name>   # switch to a preset instantly
dragon-configure --gallery         # print every preset stacked with a labeled banner
dragon-configure --diff <preset>   # show what would change if you switched to <preset>
dragon-configure --dismiss         # silence the new-variables notifier (repeats every shell open until dismissed)
dragon-configure --help            # show all options
```

Settings are written to `~/.config/master-oogway/conf.zsh` — never overwritten after creation, except by an explicit user-initiated reset (which always writes a timestamped backup first; see Presets below).

## Presets

Recommended starting points:

| Preset | Style |
|--------|-------|
| `short` | minimal — `hostname:dir$`, inline git, no rprompt extras |
| `default` | balanced — `user@host:dir ❯`, git status, time, exec timer |
| `verbose` | maximum — multiline, full paths, rich git indicators |

```bash
dragon-configure --preset default
```

43 presets ship in [`presets/`](presets/), grouped into four flavours:

- **Layouts.** `short` `default` `verbose` `minimal` `portrait` `multiplexer`
- **Themed palettes.** `tokyonight` `dracula` `catppuccin-mocha` `catppuccin-latte`
  `solarized-dark` `kanagawa` `everforest` `paper` `sakura` `blade` `prism` `inferno`
  `specter` `aurora` `nova` `razor` `cosmic` `ember`
- **Moods.** `cyberpunk` `retro-terminal` `pastel` `zen` `focus`
  `synthwave` `matrix` `rainbow`
- **Special-purpose.** `high-contrast` (WCAG) `ascii` (no glyphs)
  `prod-server` (SSH banner) `corporate` (muted)

Browse all of them in the interactive picker with `dragon-configure`, or jump
straight to one with `dragon-configure --preset <name>`.

A preset switch (CLI `--preset` or interactive `[3] Reset to preset`) writes
a timestamped backup at `~/.config/master-oogway/conf.zsh.bak.<YYYYMMDD_HHMMSS>`
before overwriting. To revert:

```bash
cp ~/.config/master-oogway/conf.zsh.bak.<ts> ~/.config/master-oogway/conf.zsh && soursh
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

## Dependencies

Dragon requires the [gitstatus](../../plugins/gitstatus/) submodule for git segment display. If the submodule is missing (e.g. before running `install.sh`), the git segment is silently omitted and all other prompt segments render normally.

## All variables

The full list of `DRAGON__*` variables with defaults, types, and descriptions lives in [`schema.zsh`](schema.zsh). Every variable is also visible (with live preview) in `dragon-configure`.
