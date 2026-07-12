# dragon theme

A fully configurable zsh prompt theme with ~130 tunable variables, a preset
picker, and a self-documenting config file.

## Configuration

Two actions: **pick a look**, then **fine-tune the file**.

```bash
dragon-configure                   # TUI preset picker — arrows, live preview, Enter to apply
dragon-configure --preset <name>   # switch to a preset instantly (built-in or personal)
dragon-configure --edit            # open conf.zsh in $EDITOR to tweak individual settings
dragon-configure --export <name>   # save the current config as a personal preset
dragon-configure --gallery         # print every built-in preset stacked with a labeled banner
dragon-configure --help            # show all options
```

The picker asks a one-question Nerd-Font check, then lists every built-in preset
(plus your personal ones under a `── Personal ──` divider). Press `s` to cycle
the preview between plain, SSH, and failed-command contexts.

Settings live in `~/.config/master-oogway/conf.zsh`. The file **is** the variable
editor: every `DRAGON__*` var, grouped with hints, defaults commented out. Edit
it directly (`--edit`), then `rezsh`. Applying a preset regenerates the file
wholesale (a timestamped backup is written first; see Presets below); an update
regenerates it in place, preserving your values and surfacing any new options as
commented defaults.

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

Browse all of them in the picker with `dragon-configure`, or jump straight to
one with `dragon-configure --preset <name>`.

A preset switch (via the picker or `--preset`) writes a timestamped backup at
`~/.config/master-oogway/conf.zsh.bak.<YYYYMMDD_HHMMSS>` before overwriting.
To revert:

```bash
cp ~/.config/master-oogway/conf.zsh.bak.<ts> ~/.config/master-oogway/conf.zsh && soursh
```

## Dependencies

Dragon requires the [gitstatus](../../plugins/gitstatus/) submodule for git segment display. If the submodule is missing (e.g. before running `install.sh`), the git segment is silently omitted and all other prompt segments render normally.

## All variables

The full list of `DRAGON__*` variables with defaults, types, and descriptions lives in [`schema.zsh`](schema.zsh) — and, grouped with hints, in your generated `conf.zsh` (open it with `dragon-configure --edit`).
