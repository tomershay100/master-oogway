# Contributing to master-oogway

This document is for developers working on the master-oogway repo itself.
For user documentation see [README.md](README.md).

---

## Repo layout

```
install.sh                        entry point — 3 modes (see below)
zshrc.master-oogway                    user's ~/.zshrc (installed once, never overwritten)
.zshenv                           always re-copied to ~/.zshenv on each install run
gitconfig.master-oogway           always re-copied to ~/.gitconfig.master-oogway
dragon-notifier.zsh               sourced by ~/.zshrc — notifies when new vars exist
.editorconfig                     enforces tab indentation + LF endings across editors

omz-custom/                       ZSH_CUSTOM directory (sourced by oh-my-zsh)
  themes/
    dragon.zsh-theme              OMZ entry point shim — sources dragon/dragon.zsh
    dragon/                       all dragon theme code lives here
      dragon.zsh                  theme entry point — defaults loop, hook registration
      schema.zsh                  _DRAGON_DEFAULTS: single source of truth for all vars
      configure.zsh               interactive wizard (~750 lines)
      aliases.zsh                 rezsh, reset_theme_variables
      parts/
        helpers.zsh               __get_xterm_*, __dragon__show (segment renderer)
        segments_left.zsh         username, hostname, directory, prompt_char, ssh_prefix
        segments_right.zsh        date_time, exec_timer, ssh_conn_count, jobs, exit_status
        separators.zsh            segment separators, multiline prompt lines
        git.zsh                   gitstatus integration, git segment
        prompt.zsh                __calc_prompt_length, dragon__set_lprompt/set_rprompt
        transient.zsh             zle hooks, gitstatus glue, prompt refresh
  plugins/
    mo-*/mo-*.plugin.zsh          18 oh-my-zsh plugins (override + additive)

tests/
  check_schema.sh                 validates schema var count vs theme; run directly with bash
scripts/
  gen_readme.sh                   regenerates README plugin table from # Provides: comments
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
| Any `omz-custom/` file (plugins, theme parts, configure) | `soursh` — live via symlink |
| `dragon-notifier.zsh` | `soursh` |
| `.zshenv` | re-run `./install.sh`, then `soursh` |
| `gitconfig.master-oogway` | re-run `./install.sh` |
| `zshrc.master-oogway` | `rm ~/.zshrc && ./install.sh` |
| `install.sh` itself | just run `./install.sh` — idempotent |

---

## Validation

Always run these four checks before committing — every change should pass all four:

```bash
# 1. bash syntax check on install.sh
bash -n install.sh

# 2. zsh syntax check on all theme + plugin + notifier files
zsh -n omz-custom/themes/dragon.zsh-theme \
       omz-custom/themes/dragon/*.zsh \
       omz-custom/themes/dragon/parts/*.zsh \
       omz-custom/plugins/mo-*/mo-*.plugin.zsh \
       dragon-notifier.zsh

# 3. static analysis on the bash files
shellcheck install.sh tests/check_schema.sh

# 4. schema/theme consistency check
bash tests/check_schema.sh
```

If any of these fail, fix the underlying issue — never commit a file that fails parsing.

---

## Adding a plugin

1. Create `omz-custom/plugins/mo-<name>/mo-<name>.plugin.zsh`
2. First line must be a `# Provides:` comment — one line describing what it adds:
   ```zsh
   # Provides: mycommand (does X) and myalias (does Y).
   ```
3. Add `mo-<name>` to the plugins list in `zshrc.master-oogway` (override or additive group)
4. **Update the README** — regenerate the auto-generated plugin table:
   ```bash
   bash scripts/gen_readme.sh
   ```
   Then add a `### mo-<name>` command-reference section to [README.md](README.md)
   under "Command reference" describing each command the plugin provides.
5. Run the four validation checks above.

Override plugins (those that shadow system commands) must appear **before** additive
plugins in `zshrc.master-oogway` so additive plugins inherit the overridden commands.
Each override should also define an escape-hatch alias (`r<name>`) that calls the
original binary directly.

---

## Adding a theme configuration variable

All theme variables live in `omz-custom/themes/dragon/schema.zsh` inside `_DRAGON_DEFAULTS`.
This is the **single source of truth** — add a variable here and it is automatically:
- initialized on shell startup via the defaults loop in `dragon.zsh-theme`
- exposed in `dragon-configure` (grouped under its schema group)
- validated by `tests/check_schema.sh`

```zsh
# In schema.zsh _DRAGON_DEFAULTS — format: "KEY" "type:group:default"
"MY_NEW_VAR"    "bool:appearance:true"
```

Types: `bool`, `color`, `string`, `int`.
Groups map to the wizard sections in `dragon-configure`.

After adding, run `bash tests/check_schema.sh` — verifies the count is consistent.
Also update the [README.md](README.md) "Theme configurator" section if the new
variable belongs in user-facing documentation.

Users will be notified on next shell start that new variables are available
(`dragon-configure --new-only` to configure just the new ones).
Run `dragon-configure --help` to see all available subcommands.

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
`~/.zshenv` exports `DRAGON__FORWARDED=1`. `conf.zsh` checks this var on remote
machines to skip re-applying local defaults over the forwarded values.

---

## Generating the README plugin table

```bash
bash scripts/gen_readme.sh
```

Reads `# Provides:` comments from all `mo-*.plugin.zsh` files and rewrites the
additive plugins table in `README.md` between the sentinel markers:

```text
<!-- mo-plugins-start -->
...
<!-- mo-plugins-end -->
```

Run this after adding or modifying a plugin's `# Provides:` comment.

> **Reminder:** the script only regenerates the auto-table at the top.
> If you add a new plugin or a new command to an existing plugin, also add or
> update its dedicated `### mo-<name>` section under "Command reference" in
> README.md by hand — those tables are not auto-generated.
