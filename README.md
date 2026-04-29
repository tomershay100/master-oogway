# shared/shell

Shell configuration files for zsh (primary) and bash (fallback).
Install manually:

```bash
sudo ./shared/shell/install.sh
```

## What gets installed

| Repo file | Installed to |
|-----------|--------------|
| `.zshenv` | `~/.zshenv` |
| `.zshrc` | `~/.zshrc` |
| `.bashrc` | `~/.bashrc` |
| `.profile` | `~/.profile` |
| `.bash_logout` | `~/.bash_logout` |
| `.gitconfig` | `~/.gitconfig` |
| `zsh-custom.d/` | `~/.zsh-custom.d/` |

## Dependencies

The install script auto-installs `zsh`, `git`, and `curl`. The rest are
optional — install them to enable the corresponding aliases and features:

```bash
# Ubuntu
sudo apt install fzf bat eza meld direnv
# Raspberry Pi (eza unavailable — use exa instead)
sudo apt install fzf bat exa meld direnv
```

oh-my-zsh must be installed separately before running the install script:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

oh-my-zsh plugins (git submodules in `zsh-custom.d/plugins/`, initialized by install):
- `gitstatus` — fast git status (replaces slow `git status` in prompt)
- `zsh-autosuggestions`
- `zsh-syntax-highlighting`
- `you-should-use`

## Local git identity

`.gitconfig` does not contain `user.name` or `user.email`. The install script
will prompt you to create `~/.gitconfig.local`:

```ini
[user]
    name  = Your Name
    email = you@example.com
```

## Uninstalling

Remove the installed copies to restore stock shell config:

```bash
rm ~/.zshenv ~/.zshrc ~/.bashrc ~/.profile ~/.bash_logout ~/.gitconfig ~/.zsh-custom.d
```

Then restore Ubuntu's default files (they were overwritten, not backed up by the installer):

```bash
cp /etc/skel/.bashrc ~/.bashrc
cp /etc/skel/.profile ~/.profile
```

Git identity (`~/.gitconfig.local`) and oh-my-zsh (`~/.oh-my-zsh/`) are untouched by the installer — remove them separately if desired.

## appa-fino theme configurator

`appa-fino-configure` is an interactive wizard sourced automatically by oh-my-zsh
(via `zsh-custom.d/appa-fino-configure.zsh`). It steps through every theme feature
group and rewrites `~/.zsh-custom.d/appa-fino-conf.zsh` with your choices.

```bash
appa-fino-configure            # full wizard (preset → step through all groups)
appa-fino-configure --new-only # only when new variables were added to the theme
```

State is stored in `~/.config/appa-fino/state`
(hash of known var names + chosen preset).

### Adding a new variable to the wizard

All wizard metadata lives in
`zsh-custom.d/appa-fino-configure.zsh`. To add a variable:

**1. Add the default value** — in `_af_init_defaults()`:

```zsh
[MY_NEW_VAR]="default_value"
```

**2. Add the type** — in `_af_init_types()`:

```zsh
[MY_NEW_VAR]="bool"   # bool | color | string | enum:opt1|opt2|opt3
```

**3. Add it to a group** — in `_af_init_groups()`, append the short
name to the relevant `_AF_GROUP_VARS` entry:

```zsh
[git_status]="ENABLE_GIT_STATUS ... MY_NEW_VAR"
```

Or create a new group by adding a key to `_AF_GROUPS`,
`_AF_GROUP_TITLE`, `_AF_GROUP_DESC`, and `_AF_GROUP_VARS`.

**4. Optional: add a hint** — in `_af_init_hints()`:

```zsh
[MY_NEW_VAR]="Explain allowed values here."
```

**5. Add the theme default** — also add
`set_if_unset APPA_FINO__MY_NEW_VAR ...` to `themes/appa-fino.zsh`
if the variable is actually used by the theme.

After adding the variable, the next `install.sh` run detects the hash
change and prints a `todo_item` prompting the user to run
`appa-fino-configure --new-only`.

### Removing a variable

1. Remove it from `_af_init_defaults()`, `_af_init_types()`,
   `_af_init_hints()`, and the relevant `_AF_GROUP_VARS` entry in
   `_af_init_groups()`.
2. If the group becomes empty, remove it from `_AF_GROUPS` and delete
   its entries in `_AF_GROUP_TITLE`, `_AF_GROUP_DESC`, `_AF_GROUP_VARS`.
3. Remove the `set_if_unset` line from `themes/appa-fino.zsh`.

The wizard writes only variables it knows about — removed variables will
be absent from newly generated conf files, but existing user conf files
are untouched until the user re-runs the wizard.

### Updating a preset

The three built-in presets (`short`, `default`, `verbose`) are defined
in `_af_apply_preset()`. Each preset is a list of
`_AF_CURRENT[VAR]=value` assignments applied on top of defaults.
`default` is implicit — it applies nothing (pure defaults).

### How the live preview works

Before spawning a preview subshell, `_af_render_preview` exports all
`APPA_FINO__*` vars from `_AF_CURRENT`. The subshell stubs out
`gitstatus_start`/`gitstatus_query` and fakes `VCS_STATUS_*` variables
(git shows as `main ✔`), sources the theme file, calls
`appa_fino__update_zsh_prompt`, and prints `$PROMPT`/`$RPROMPT` with
`print -rP`. Because `set_if_unset` only sets a var when it is **not**
already set, the pre-exported vars win over theme defaults — giving a
true live preview.

### How new-var detection works

`install.sh` and `appa-fino-configure --new-only` both compute an md5
hash of all `APPA_FINO__*` variable names in `themes/appa-fino.zsh`.
The hash from the last configuration run is stored in
`~/.config/appa-fino/state`. A mismatch means new variables were added
and the user should re-run the wizard.

## SSH prompt forwarding

To carry your appa-fino theme settings over SSH, append to `/etc/ssh/ssh_config`:

```
Host *
    SendEnv APPA_FINO__*
```

And on the remote server, append to `/etc/ssh/sshd_config`:

```
AcceptEnv APPA_FINO__*
```
