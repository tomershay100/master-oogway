# Contributing to master-oogway

This document is for developers working on the master-oogway repo itself.
For user documentation see [README.md](README.md).

---

## Repo layout

```
install.sh                        entry point — 3 modes (see below)
zshrc.master-oogway               user's ~/.zshrc (installed once, never overwritten)
zshenv.master-oogway              always re-copied to ~/.zshenv on each install run
gitconfig.master-oogway           always re-copied to ~/.gitconfig.master-oogway on each install run
editorconfig.master-oogway        always re-copied to ~/.editorconfig on each install run

omz-custom/                       ZSH_CUSTOM directory (sourced by oh-my-zsh)
  themes/
    dragon.zsh-theme              OMZ entry point shim — sources dragon/{dragon,configure,aliases,notifier}.zsh
    dragon/                       all dragon theme code lives here
      dragon.zsh                  theme entry point — defaults loop, hook registration
      schema.zsh                  single source of truth for all DRAGON__* vars (defaults, types, hints, groups)
      configure.zsh               entry point for `dragon-configure` — sources configure/*.zsh
      configure/                  wizard implementation
        state.zsh                 state I/O, conf loading, preset apply
        preview.zsh               key reader, prompt preview, gallery renderer
        pick.zsh                  TUI preset browser (--pick)
        wizard.zsh                interactive steps, menus, variable editor
        writer.zsh                conf file generator
      aliases.zsh                 rezsh, reset_theme_variables
      notifier.zsh                shell-start notifier — fires when new theme vars exist
      parts/
        helpers.zsh               __get_xterm_*, __dragon__show (segment renderer)
        segments_left.zsh         username, hostname, directory, prompt_char, ssh_prefix
        segments_right.zsh        date_time, exec_timer, ssh_conn_count, jobs, exit_status
        separators.zsh            segment separators, multiline prompt lines
        git.zsh                   git segment rendering
        gitstatus.zsh             gitstatus daemon lifecycle + availability guard
        prompt.zsh                __calc_prompt_length, dragon__set_lprompt/set_rprompt
        lifecycle.zsh             __update_prompt, __refresh_prompt, dragon__update_zsh_prompt
        transient.zsh             zle hooks, transient prompt collapse
  plugins/
    mo-*/mo-*.plugin.zsh          25 master-oogway plugins (6 override + 19 additive)
```

---

## Install modes

`install.sh` auto-detects which mode to run based on how it was invoked.

### curl mode
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/tomershay100/master-oogway/main/install.sh)"
```
Clones the repo to `~/.master-oogway/`, then re-execs `install.sh` from there (becomes update mode).

### Update mode
```bash
~/.master-oogway/install.sh
```
`git pull --ff-only` + submodule update, then applies dotfiles.

### Dev mode
```bash
/path/to/your/local/clone/install.sh   # any path that is NOT ~/.master-oogway
```
Creates `~/.master-oogway` as a **symlink** to the local clone so edits are live immediately.
Also runs `git submodule update --init --recursive` in the clone to ensure plugin submodules are present.

**One-time dev setup:**
```bash
# From inside your local clone
./install.sh
```
That's it — `~/.master-oogway` now points to your clone. Edit any file; open a new terminal or run `soursh` to see changes.

---

## Edit → test loop

Different files have different latency depending on how they reach disk:

| What you changed | How to test |
|---|---|
| Any `omz-custom/` file (plugins, theme parts, configure, notifier) | `soursh` — live via symlink |
| `zshenv.master-oogway` | re-run `./install.sh`, then `soursh` |
| `gitconfig.master-oogway` | re-run `./install.sh` |
| `editorconfig.master-oogway` | re-run `./install.sh` |
| `zshrc.master-oogway` | `rm ~/.zshrc && ./install.sh` |
| `install.sh` itself | just run `./install.sh` — idempotent |

---

## Code style

All `.sh` and `.zsh` files use **tabs** for indentation (`tab_width = 4`).
This is enforced by `editorconfig.master-oogway` and matches the repo's
bash scripting conventions in `docs/bash_scripting_conventions.md`.

Markdown files deliberately disable `trim_trailing_whitespace` — a
double-space at the end of a Markdown line is a hard line-break. Removing
those spaces would silently break rendered output.

---

## Validation

Always run these checks before committing — every change should pass all of them:

```bash
# 1. bash syntax check on install.sh
bash -n install.sh

# 2. zsh syntax check on all theme + plugin files
zsh -n omz-custom/themes/dragon.zsh-theme \
       omz-custom/themes/dragon/*.zsh \
       omz-custom/themes/dragon/parts/*.zsh \
       omz-custom/plugins/mo-*/mo-*.plugin.zsh

# 3. static analysis on install.sh
shellcheck install.sh
```

If any of these fail, fix the underlying issue — never commit a file that fails parsing.

> **Note:** The wizard already validates its own output — `dragon-configure` runs `zsh -n` on the generated `conf.zsh` before writing it, so any wizard-produced config that fails syntax is rejected automatically (see `configure/writer.zsh`). You only need to run the checks above on source files.

---

## Adding a plugin

1. Create `omz-custom/plugins/mo-<name>/mo-<name>.plugin.zsh`.

2. **Declare hard dependencies** — if the plugin has no purpose without a package,
   create `omz-custom/plugins/mo-<name>/requirements.zsh` and source it at the
   top of the plugin:

   ```zsh
   # requirements.zsh
   local _missing=()
   command -v <tool> &>/dev/null || _missing+=(<apt-package>)
   if (( ${#_missing} )); then
       print -P "%F{yellow}[mo-<name>]%f missing: ${_missing[*]} (try: sudo apt install ${_missing[*]}) — plugin not loaded"
       return 1
   fi
   ```

   In the plugin:
   ```zsh
   source "${0:h}/requirements.zsh" || return
   ```

3. **Declare soft dependencies** — if the plugin degrades gracefully without a
   package (it loads fine, but some commands won't work), create
   `omz-custom/plugins/mo-<name>/optional-deps.zsh`. This file is **never sourced
   at runtime** — only read by `install.sh` to report missing packages to the user
   after an update:

   ```zsh
   # optional-deps.zsh
   typeset -gA MO_OPTIONAL_DEPS=(
       [<cmd>]="what it enables in this plugin"
   )
   typeset -gA MO_OPTIONAL_APT=(
       [<cmd>]="<apt-package-name>"   # apt name if different from the command
   )
   ```

   Key = the command name checked by `command -v`. Use the canonical command
   name (`fd` not `fdfind`, `bat` not `batcat`) — `install.sh` handles known
   alternates automatically.

4. Add `mo-<name>` to the plugins list in `zshrc.master-oogway` (override or additive group), with a one-line trailing comment summarising what it provides.

5. **Update the docs by hand — there is no generator.** Two places to touch:
   - [README.md](README.md): add a new row to the "Override plugins" or
     "Additive plugins" table with a short one-line description of what the
     plugin adds. Keep each table sorted alphabetically by plugin name.
   - `omz-custom/plugins/mo-<name>/README.md`: write the plugin README
     following the structure described in [Plugin README format](#plugin-readme-format) below.

6. Run the validation checks above.

---

## Plugin README format

Every plugin README follows this structure — in this order, only including sections that apply:

```markdown
# mo-<name>

One sentence describing what the plugin does. For override plugins, say what
it replaces and what happens when the dependency is absent.

| Command | Description |
|---------|-------------|
| `cmd [args]` | what it does |

[For override plugins only — omit if no bypass is needed:]
To bypass: use `\cmd` (backslash-quoting skips aliases in any shell).

[Optional — only when there are user-settable variables:]
## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `VAR` | `value` | what it controls |

[Optional — only when the syntax is non-obvious from the table alone:]
## Examples

```zsh
cmd foo bar   # shows the non-obvious case
```

[Always last:]
**Dependencies:** `tool1` for `cmd1`; `tool2` for `cmd2` — each checked at call time.

### Rules

The template above shows the structure; these are the rules it doesn't.

- **Bypass line** — override plugins only. Use the `\cmd` backslash form. Never document `r<name>` aliases that don't exist in the code.
- **No prose restating the table** — if the table already says it, don't say it again in a paragraph.
- **Plugins with no user-facing commands** (like `mo-auto-ls`, `mo-welcome`, `mo-colorize-override`) — two-sentence README maximum: what it does, and how to disable or bypass it.

Override plugins (those that shadow system commands) must appear **before** additive
plugins in `zshrc.master-oogway` so additive plugins inherit the overridden commands.
Override plugins go in the "Override plugins" table at the top of the README's
`## Plugins` section, not in the additive table.

**Plugin-order constraints in `zshrc.master-oogway`:**

1. `zsh-autosuggestions` must come **before** `zsh-syntax-highlighting`.
2. `zsh-syntax-highlighting` must be **the very last entry** in the `plugins=()`
   array. It wraps every ZLE widget defined by earlier plugins; widgets defined
   after it will not be re-highlighted on each keystroke. New plugins go above
   it, never below.
3. Override plugins (`mo-*-override`) come before additive plugins.

If a plugin requires a tool that may not be installed:

- **Hard dep** (plugin is useless without it): use `requirements.zsh` + `source "${0:h}/requirements.zsh" || return`. The plugin prints a yellow warning and does not load. Hard-dep checks must use `_MO_OPT_BIN` (not `command -v`) to handle package-name aliases like bat/batcat and fd/fdfind: `(( $+_MO_OPT_BIN[bat] )) || { echo "mo-foo: bat not installed" >&2; return 1; }`. See `mo-bat-override` for the canonical pattern.
- **Soft dep** (plugin loads and degrades gracefully, but a feature is silently missing): guard usage inline with `command -v <tool> &>/dev/null`, and declare the dep in `optional-deps.zsh` so `install.sh` can report it. See `mo-search` for the canonical pattern.
- **Per-function dep** (only one function needs a tool, and it already errors clearly when missing): guard inline with `command -v <tool> &>/dev/null || { echo "cmd: tool not installed" >&2; return 1; }` inside the function itself. No `requirements.zsh` or `optional-deps.zsh` needed — the function is self-documenting. See `mo-network` (`natip`, `serve`, `sshto`) for the canonical pattern.

**Plugins that write outside `~/.config/master-oogway/`** (introduced by
`mo-lan-ssh`, which writes `~/.ssh/config.d/lan-hosts`) should:

- Use a unique filename (no collision with user-managed files).
- Emit a clear `# autogenerated — do not edit by hand` header.
- Skip the write entirely when content hasn't changed since last write
  (compare via a sha stored under `~/.config/master-oogway/`). This keeps
  shell startup cost at zero on the steady state.
- Document the path and behaviour in the plugin's `# Provides:` line and
  in the plugin's README "Command reference" section.
- If the write requires modifying a user-owned config file (`~/.ssh/config`,
  `~/.gitconfig`, etc.) in order to take effect, gate that mutation behind
  an explicit `setup` subcommand — never silently change a user-owned file
  at shell startup.

---

## Adding a preset

A built-in preset is three things in sync: a `.conf.zsh` file, a name in the
registry array, and a description + example string. All three must be added together.

**1. Create `omz-custom/themes/dragon/presets/<name>.conf.zsh`**

Export only values that differ from the schema defaults. Check the default for
any variable you want to set by looking it up in `_DRAGON_DEFAULTS` inside
`schema.zsh`. If your value matches the default, omit it.

```zsh
# dragon preset: <name>
# One-line description of the look/feel.
export DRAGON__SOME_VAR='value'   # short comment if the choice isn't obvious
```

**2. Register the preset in `schema.zsh` — `_dragon_init_presets()`**

Three places inside that function:

```zsh
# (a) append to the names array
typeset -ga _DRAGON_PRESET_NAMES=(
    ... existing names ... <name>
)

# (b) add a description (one sentence, ≤ 80 chars, no trailing period)
[<name>]='Short description of palette and layout style.'

# (c) add an ASCII example showing what the prompt looks like
[<name>]='user · myhost · ~/projects
          ❯'
```

The example is shown in `--pick` and `--gallery`. Keep it to 1–3 lines; use
real prompt chars and branch symbols so it looks like an actual prompt.

**3. Update the preset count in `omz-custom/themes/dragon/README.md`**

Search for the line like `26 presets ship in` and increment the number.

---

## Adding a theme configuration variable

`schema.zsh` is the **single source of truth** for every `DRAGON__*` variable.
The defaults loop in `dragon.zsh` iterates over it and calls `set_if_unset "DRAGON__${key}" "$default"`
for each entry, so the live variable name is always `DRAGON__` + the schema key
(e.g. schema key `ENABLE_GIT_STATUS` → runtime variable `$DRAGON__ENABLE_GIT_STATUS`).

You must touch **all five** of the following — missing any one means the variable
either has no default, is invisible to `dragon-configure`, or renders nothing.
(This rule is also summarised in `CLAUDE.md` under "Adding a `DRAGON__*` variable".)

### 1. `_DRAGON_DEFAULTS` — declare the key and its default value

```zsh
typeset -gA _DRAGON_DEFAULTS=(
    ...
    [MY_NEW_VAR]="default_value"
    ...
)
```

### 2. `_DRAGON_TYPE` — declare the type for the configurator wizard

```zsh
typeset -gA _DRAGON_TYPE=(
    ...
    [MY_NEW_VAR]="bool"     # or: color | string | enum:opt1|opt2|opt3
    ...
)
```

Types:

- `bool` — wizard shows a yes/no toggle
- `color` — wizard shows a color picker; empty string `""` means no background color applied
- `integer` — wizard shows a numeric-only prompt; non-integers are rejected before saving
- `string` — wizard shows a free-text prompt
- `enum:a|b|c` — wizard shows a selection menu

> **`*_BACKGROUND_COLOR` convention:** every background-color variable defaults to `""` (empty string),
> meaning "use the terminal's default background". Only set hints for vars where the semantics deviate
> from this rule (e.g. `GIT_CLEAN_BACKGROUND_COLOR` has a non-empty default and a hint explaining it).

### 3. `_DRAGON_GROUP_VARS` — assign the key to a wizard group

Add the key to the space-separated value of the appropriate group:

```zsh
typeset -gA _DRAGON_GROUP_VARS=(
    ...
    [git_status]="ENABLE_GIT_STATUS GIT_STATUS_ON_NEW_LINE ... MY_NEW_VAR"
    ...
)
```

If you need a new group entirely, also add it to `_DRAGON_GROUPS` (ordered list),
`_DRAGON_GROUP_TITLE` (display name), and `_DRAGON_GROUP_DESC` (one-line description).

### 4. Optionally — `_DRAGON_HINT` — add a hint shown in the wizard

Only needed when the value format or semantics aren't obvious from the type alone:

```zsh
typeset -gA _DRAGON_HINT=(
    ...
    [MY_NEW_VAR]="Explanation of what the value controls and valid values."
    ...
)
```

### 5. Consume the variable in the appropriate `parts/*.zsh` segment

Reference it as `$DRAGON__MY_NEW_VAR`. If you're adding a whole new segment,
also call it from `dragon__set_lprompt` or `dragon__set_rprompt` in `prompt.zsh`.

---

Users are notified on next shell start that new variables are available
(`dragon-configure --new-only` to configure just the new ones).

If the new variable is user-facing, also update the [README.md](README.md)
"Theme configurator" section.

---

## Theme architecture

`dragon.zsh-theme` is the entry point. It:
1. Sources `schema.zsh` and calls `_dragon_init_defaults` (populates `_DRAGON_DEFAULTS`)
2. Runs the defaults loop: for each key in `_DRAGON_DEFAULTS`, calls `set_if_unset`
   so user-set `DRAGON__*` vars are never overwritten
3. Sources all 9 `parts/*.zsh` files
4. Registers zle hooks (via `transient.zsh`) and the gitstatus callback

**Prompt render path** (per keypress):
```
gitstatus callback → __refresh_prompt (transient.zsh)
                   → dragon__set_lprompt / dragon__set_rprompt (prompt.zsh)
                   → __dragon__show per segment (helpers.zsh)
                   → PROMPT / RPROMPT strings assembled
```

**SSH theme forwarding:**
The generated `~/.config/master-oogway/conf.zsh` (written by `dragon-configure`)
both **exports** `DRAGON__FORWARDED=1` after the early-return guard, and
**checks** it on entry: `[[ "${DRAGON__FORWARDED:-}" == "1" ]] && return`.
On the sending machine the export sets the var so SSH's `SendEnv DRAGON__*`
carries it; on the receiving machine the guard short-circuits, so any forwarded
`DRAGON__*` values stay untouched. (`.zshenv` is not involved — it only sets
`EDITOR`/`VISUAL`.)

