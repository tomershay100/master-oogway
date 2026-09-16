# mo-brew

Homebrew helpers. Arch-aware — works against `/opt/homebrew` on Apple Silicon
and `/usr/local` on Intel without configuration.

| Command | Description |
|---------|-------------|
| `bup` | `brew update` + `upgrade` + `cleanup` in one, with a pass/fail summary |
| `bi [term]` | fuzzy-pick formulae **and** casks to install (TAB for multi-select) |
| `bun` | fuzzy-pick installed packages to uninstall (TAB for multi-select) |
| `bs <term>` | search formulae and casks; shows full `brew info` for your pick |
| `bl` | browse `brew leaves` with a dependency-tree and reverse-dependency preview |
| `bout` | list outdated packages |

**Dependencies:** `brew` — required, plugin does not load without it.
`fzf` for `bi`, `bun`, `bs` and `bl` — checked at call time.

## On Linux

This plugin does not load on Linux — silently, since a warning on every shell
start would be noise for something that simply does not apply there. Add it to
`plugins=(…)` unconditionally; it costs nothing off-platform.
