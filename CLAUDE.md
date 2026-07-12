# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Context

This directory is a **standalone, separately-published git repo** (`github.com/tomershay100/master-oogway`) that is also vendored inside the parent `custum-linux-configs/` dotfiles repo. It has its own `.git/`, its own remote, and its own submodules. Treat it as the project root — git commands here operate on master-oogway, not the parent. The parent's `CLAUDE.md` covers umbrella dotfile conventions; this file covers master-oogway specifics.

The repo ships a complete zsh environment: the **dragon** prompt theme (~130 tunable vars, TUI preset picker, 43 presets) plus 22 `mo-*` plugins (5 override + 17 additive) on top of oh-my-zsh.

End-user docs live in `README.md`. Contributor mechanics (adding plugins/presets/variables, plugin README structure) live in `CONTRIBUTING.md` — read it before substantive theme or plugin work; this file does not duplicate it.

## Validation — run before every commit

```bash
bash -n install.sh
zsh -n omz-custom/themes/dragon.zsh-theme \
       omz-custom/themes/dragon/*.zsh \
       omz-custom/themes/dragon/parts/*.zsh \
       omz-custom/themes/dragon/configure/*.zsh \
       omz-custom/plugins/mo-*/mo-*.plugin.zsh
shellcheck install.sh
```

`_dragon_write_conf` runs `zsh -n` on the generated `conf.zsh` before writing it (see `configure/writer.zsh`), so generated config is self-validating — only source files need the checks above.

## Install modes — auto-detected by `install.sh`

| Mode | Trigger | What it does |
|---|---|---|
| **curl** | `curl … \| bash` | clones repo to `~/.master-oogway/`, re-execs `install.sh` from there |
| **update** | `~/.master-oogway/install.sh` | `git pull --ff-only` + submodule update, re-applies dotfiles |
| **dev** | running `install.sh` from any other path | **symlinks** `~/.master-oogway` → this directory so edits go live with `soursh` |

Run `./install.sh` from this directory once for dev setup; afterwards edits to anything under `omz-custom/` are picked up by `soursh` without re-installing.

## Edit → test loop

| Changed | How to apply |
|---|---|
| Any `omz-custom/` file | `soursh` — live via symlink |
| `zshenv.master-oogway` | re-run `./install.sh`, then `soursh` |
| `gitconfig.master-oogway` / `editorconfig.master-oogway` | re-run `./install.sh` |
| `zshrc.master-oogway` | `rm ~/.zshrc && ./install.sh` (zshrc is **install-once** by design) |
| `install.sh` itself | just re-run — idempotent |

`~/.zshrc` carries a `master-oogway:managed` marker line. **Do not remove it** — without it the next install replaces the file and the user's local edits are lost.

## Dragon theme architecture

Entry shim: `omz-custom/themes/dragon.zsh-theme` → `omz-custom/themes/dragon/dragon.zsh`.

```
dragon.zsh           defaults loop (set_if_unset per schema), hook registration
schema.zsh           SINGLE SOURCE OF TRUTH for all DRAGON__* vars
configure.zsh        entry for `dragon-configure`
configure/           configurator implementation
  state.zsh            conf I/O, preset apply, active-preset header read, glyph loader ($'\uXXXX' eval)
  preview.zsh          prompt preview + gallery renderer
  pick.zsh             TUI preset picker — the front door (bare / --pick)
  writer.zsh           generates conf.zsh w/ `# preset:` header (validates via `zsh -n` before writing)
parts/                 segment + prompt assembly (9 files)
presets/               43 *.conf.zsh presets — only override values that differ from defaults
aliases.zsh            rezsh, reset_theme_variables
```

**Render path per keypress:** `gitstatus callback → __refresh_prompt (transient.zsh) → dragon__set_lprompt/dragon__set_rprompt (prompt.zsh) → __dragon__show per segment (helpers.zsh) → PROMPT / RPROMPT assembled`.

### Adding a `DRAGON__*` variable — 5 places must be updated

Touching fewer than all five leaves the variable either unset, missing or ungrouped in the generated `conf.zsh`, or unrendered:

1. `schema.zsh` → `_DRAGON_DEFAULTS[KEY]="default"`
2. `schema.zsh` → `_DRAGON_TYPE[KEY]="bool|color|string|enum:a|b|c"`
3. `schema.zsh` → add `KEY` to the appropriate `_DRAGON_GROUP_VARS[group]` space-separated list
4. *(optional)* `schema.zsh` → `_DRAGON_HINT[KEY]="…"` when the type isn't self-explanatory
5. Consume `$DRAGON__KEY` in the relevant `parts/*.zsh` (new segment → also wire it from `dragon__set_lprompt` / `dragon__set_rprompt` in `parts/prompt.zsh`)

Runtime variable name is always `DRAGON__` + schema key.

### Adding a preset — 3 things must stay in sync

1. `presets/<name>.conf.zsh` — export **only** values differing from the schema default
2. `schema.zsh` `_dragon_init_presets()`: append to `_DRAGON_PRESET_NAMES`, add description, add ASCII example (used by `--pick` / `--gallery`)
3. Bump the preset count in `omz-custom/themes/dragon/README.md`

Separator glyphs in preset files use `$'\uXXXX'` Unicode-escape form (the state-loader evals them on read). Powerline glyphs sit at U+E0B0–U+E0C3.

## Shared libs

`omz-custom/lib/` holds one file sourced automatically by oh-my-zsh before any plugin or theme:

| File | Global | Purpose |
|------|--------|---------|
| `lib/colors.zsh` | `_MO_COLORS[name]` | Named xterm-256 color table — shared by dragon theme and mo-color plugin. Edit here; do not duplicate in either consumer. |

Plugin usage: `command -v <tool> &>/dev/null` per-function — lazy check, only pays cost on invocation. For tools with package aliases (bat/batcat, fd/fdfind) check both: `command -v bat &>/dev/null || command -v batcat &>/dev/null`.

## Plugin system

22 master-oogway plugins live in `omz-custom/plugins/mo-*/`. Each is `mo-<name>/mo-<name>.plugin.zsh` plus optional `requirements.zsh`, `optional-deps.zsh`, `README.md`.

### Plugin ordering in `zshrc.master-oogway` (`plugins=(…)`)

Hard constraints — violating any breaks behavior, not just style:

1. `zsh-autosuggestions` **before** `zsh-syntax-highlighting`.
2. `zsh-syntax-highlighting` **must be the last entry except `history-substring-search`**. It wraps every ZLE widget defined by earlier plugins; widgets added after it are not re-highlighted on keystrokes. `history-substring-search` is the one sanctioned entry below it — its upstream README requires loading *after* zsh-syntax-highlighting.
3. Override plugins (`mo-*-override`) come **before** additive plugins so additives inherit the overridden commands.

### Dependency tiers — pick the right one

| Tier | When | Pattern |
|---|---|---|
| **Hard** | plugin useless without tool X | `mo-<n>/requirements.zsh` + `source "${0:h}/requirements.zsh" \|\| return` at top of plugin. Canonical: `mo-bat-override`. |
| **Soft** | plugin loads; one feature degrades silently | declare in `optional-deps.zsh` (read **only** by `install.sh` — never sourced at runtime) so the installer reports missing packages. Canonical: `mo-search`. |
| **Per-function** | only one function needs the tool; missing → clear error | inline `command -v <tool> &>/dev/null \|\| { echo "cmd: tool not installed" >&2; return 1; }` inside that function. No deps files. Canonical: `mo-process` (`port` needs `lsof`, `psgrep` needs `pgrep`). |

Optional-dep keys use the **canonical** command name (`fd`, `bat`) — `install.sh` handles known apt alternates (`fdfind`, `batcat`) on its own.

### Plugins writing files outside `~/.config/master-oogway/`

Any such plugin must: use a unique filename, emit `# autogenerated — do not edit by hand`, skip the write when content hasn't changed (compare via sha cached under `~/.config/master-oogway/`) to keep steady-state shell start at zero cost, and gate any mutation of user-owned config files behind an explicit `setup` subcommand — never silently change those at shell open.

## Code style

- **Tabs** for indentation in all `.sh` / `.zsh` (`tab_width=4`, enforced by `editorconfig.master-oogway`).
- **Markdown trailing whitespace is significant** — `editorconfig` disables `trim_trailing_whitespace` for `*.md` because a double-space at EOL is a hard line break. Do not run a formatter that strips it.
- Naming: `snake_case.sh` for repo source files; `kebab-case` for the installed command name in `bin/` (e.g. `notify_gotify.sh` → installed as `notify-gotify`). Functions `snake_case`; globals/constants `UPPER_SNAKE_CASE`; private fns `_leading_underscore`.
- All bash scripts begin with `#!/usr/bin/env bash` then `set -Eeuo pipefail`. Section separators use `# -- Name ---…` ASCII hyphens padded to 80 columns — never em-dashes inside scripts.

## Comments and documentation

Applies to every file in this repo — source comments, READMEs, PR descriptions alike. Keep it short, to the point, readable, simple.

- **Default to no comments.** Well-named identifiers and the code itself already say *what* it does. Add a comment only when the reader cannot see the *why* from the code — a hidden invariant, a workaround for a known bug, a non-obvious constraint.
- **Explain WHY, not WHAT.** "Increment counter" is noise; "RIGHT_SEGMENT_SEPARATOR_SWAP_COLORS needed because flame glyphs render with inverted fg/bg" is signal.
- **Rationale belongs in commit messages**, not in comments. Comments rot in place; commit messages are timestamped and reviewable.
- **User-facing config files are the exception.** `zshrc.master-oogway`, preset `.conf.zsh` files, `optional-deps.zsh`, and the generated `conf.zsh` are *read and edited by users* — inline `# what this knob does` annotations are part of the UX there. Still keep them tight: one phrase per line, never paragraphs.
- **READMEs**: short, scannable, tables over prose. Don't restate what the table already says.

## Files Claude should NOT edit

- `**/*.zwc` — zsh bytecode, regenerated by `install.sh` via `zcompile`. Edit the `.zsh` source.
- `omz-custom/plugins/{gitstatus,you-should-use,zsh-autosuggestions,zsh-syntax-highlighting}/` — vendored git submodules. Update the submodule pointer; do not edit in-tree.
- The `master-oogway:managed` marker line in `zshrc.master-oogway` and `~/.zshrc` — removing it disables overwrite protection.
