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
      configure.zsh               interactive wizard (~750 lines)
      aliases.zsh                 rezsh, reset_theme_variables
      notifier.zsh                shell-start notifier — fires when new theme vars exist
      parts/
        helpers.zsh               __get_xterm_*, __dragon__show (segment renderer)
        segments_left.zsh         username, hostname, directory, prompt_char, ssh_prefix
        segments_right.zsh        date_time, exec_timer, ssh_conn_count, jobs, exit_status
        separators.zsh            segment separators, multiline prompt lines
        git.zsh                   gitstatus integration, git segment
        prompt.zsh                __calc_prompt_length, dragon__set_lprompt/set_rprompt
        transient.zsh             zle hooks, gitstatus glue, prompt refresh
  plugins/
    mo-*/mo-*.plugin.zsh          19 oh-my-zsh plugins (override + additive)
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

---

## Adding a plugin

1. Create `omz-custom/plugins/mo-<name>/mo-<name>.plugin.zsh`.
2. First line must be a `# Provides:` comment — one line describing what it adds:

   ```zsh
   # Provides: mycommand (does X) and myalias (does Y).
   ```

3. Add `mo-<name>` to the plugins list in `zshrc.master-oogway` (override or additive group), with a one-line trailing comment summarising what it provides.
4. **Update [README.md](README.md) by hand — there is no generator.** Two places to touch:
   - The "Additive plugins" table (under `## Plugins → ### Additive plugins — new commands only`) — add a new row matching the format of its siblings: <code>&#124; `mo-&lt;name&gt;` &#124; one-line description &#124;</code>. Keep the table sorted alphabetically by plugin name.
   - The "Command reference" section — add a new `### mo-<name> — short heading` subsection with a `Command | Description` table listing every command the plugin exposes.
5. Run the four validation checks above.

Override plugins (those that shadow system commands) must appear **before** additive
plugins in `zshrc.master-oogway` so additive plugins inherit the overridden commands.
Each override should also define an escape-hatch alias (`r<name>`) that calls the
original binary directly. Override plugins go in the "Override plugins" table at the top
of the README's `## Plugins` section, not in the additive table.

**Plugin-order constraints in `zshrc.master-oogway`:**

1. `zsh-autosuggestions` must come **before** `zsh-syntax-highlighting`.
2. `zsh-syntax-highlighting` must be **the very last entry** in the `plugins=()`
   array. It wraps every ZLE widget defined by earlier plugins; widgets defined
   after it will not be re-highlighted on each keystroke. New plugins go above
   it, never below.
3. Override plugins (`mo-*-override`) come before additive plugins.
4. `mo-utils` is the first additive plugin (defines `_mo_require` used by all
   other additive `mo-*`).

If a plugin requires a tool that may not be installed, **always guard usage with
`command -v <tool> &>/dev/null`** so the plugin loads silently when the dependency
is absent. See `mo-bat-override` for the canonical pattern.

---

## Adding a theme configuration variable

`schema.zsh` is the **single source of truth** for every `DRAGON__*` variable.
The defaults loop in `dragon.zsh` iterates over it and calls `set_if_unset "DRAGON__${key}" "$default"`
for each entry, so the live variable name is always `DRAGON__` + the schema key
(e.g. schema key `ENABLE_GIT_STATUS` → runtime variable `$DRAGON__ENABLE_GIT_STATUS`).

You must touch **all five** of the following — missing any one means the variable
either has no default, is invisible to `dragon-configure`, or renders nothing.

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
- `color` — wizard shows a color picker
- `string` — wizard shows a free-text prompt
- `enum:a|b|c` — wizard shows a selection menu

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
3. Sources all 7 `parts/*.zsh` files
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

