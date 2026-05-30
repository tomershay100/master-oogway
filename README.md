# master-oogway

A complete zsh environment — dragon prompt theme, git aliases, fuzzy-finder functions, and 25 opt-in plugins — distributed as a standalone git repo.

## Installation

oh-my-zsh must be installed first:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

Then install master-oogway:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/tomershay100/master-oogway/main/install.sh)"
```

The installer sets up `~/.zshrc`, `~/.gitconfig`, `~/.editorconfig`, `~/.zshenv`, and SSH env forwarding. Run it again to update.

## What gets installed

- `~/.zshrc` — created once, never overwritten again; edit freely
- `~/.config/master-oogway/conf.zsh` — theme settings; edit via `dragon-configure`
- `~/.gitconfig` — gets an `[include]` pointing to the curated git defaults; your `[user]` section is untouched. Notable opinion: `pull.rebase = true` (linear history). Override in your `~/.gitconfig` if you prefer merge commits.

## Plugins

Override plugins replace system commands. Comment out any you don't want.

| Plugin | Replaces |
|--------|----------|
| [mo-eza-override](omz-custom/plugins/mo-eza-override/README.md) | `ls/ll/la/tree` → eza |
| [mo-bat-override](omz-custom/plugins/mo-bat-override/README.md) | `cat/less` → bat |
| [mo-nvim-override](omz-custom/plugins/mo-nvim-override/README.md) | `vim` → nvim |
| [mo-safety-override](omz-custom/plugins/mo-safety-override/README.md) | `cp/mv/mkdir/reboot` with confirmation prompts |
| [mo-colorize-override](omz-custom/plugins/mo-colorize-override/README.md) | `ip/diff` → colorized output |
| [mo-trash](omz-custom/plugins/mo-trash/README.md) | `rm` → trash-put (restorable) |

Additive plugins add new commands and never change existing behavior.

| Plugin | What it adds |
|--------|-------------|
| [mo-git](omz-custom/plugins/mo-git/README.md) | git aliases (`gs`, `gp`, `gl`, …) and fuzzy branch/log pickers |
| [mo-dirs](omz-custom/plugins/mo-dirs/README.md) | `mkcd`, `up`, `tmpcd`, `fcd` |
| [mo-files](omz-custom/plugins/mo-files/README.md) | `extract`, `compress`, `bak`, `sizeof`, `fp` |
| [mo-search](omz-custom/plugins/mo-search/README.md) | `grep` aliases, `f`, `fhist`, `fman`, `frg` |
| [mo-process](omz-custom/plugins/mo-process/README.md) | `psgrep`, `port`, `fkill` |
| [mo-docs](omz-custom/plugins/mo-docs/README.md) | `md2pdf` — Markdown to PDF |
| [mo-network](omz-custom/plugins/mo-network/README.md) | `natip`, `serve`, `sshto` |
| [mo-lan-ssh](omz-custom/plugins/mo-lan-ssh/README.md) | LAN PC aliases + USB gadget ssh-config + SSH hint wrapper |
| [mo-projects](omz-custom/plugins/mo-projects/README.md) | `<project-name>` aliases + `p` (fzf picker) for every dir in `~/projects` |
| [mo-mkscript](omz-custom/plugins/mo-mkscript/README.md) | `mkscript` — scaffold a new shell script from template |
| [mo-shell-tools](omz-custom/plugins/mo-shell-tools/README.md) | `h`, `?`, `cwhich`, `vwhich`, `clip`, `vizsh`, `soursh`, `calc`, `epoch`, `please`, `mo-where` |
| [mo-env](omz-custom/plugins/mo-env/README.md) | `fenv` |
| [mo-build](omz-custom/plugins/mo-build/README.md) | `m`, `mc` |
| [mo-welcome](omz-custom/plugins/mo-welcome/README.md) | system snapshot banner on shell open |
| [mo-cli](omz-custom/plugins/mo-cli/README.md) | `master-oogway` meta CLI |
| [mo-auto-ls](omz-custom/plugins/mo-auto-ls/README.md) | auto-`ls` after `cd` |
| [mo-color](omz-custom/plugins/mo-color/README.md) | terminal color preview, palette, and text colorizer |
| [mo-ssh-tunnel](omz-custom/plugins/mo-ssh-tunnel/README.md) | `tunnel` — SSH port-forward helper |
| [mo-man](omz-custom/plugins/mo-man/README.md) | `mo-man` — view any mo-* plugin README in the terminal |

## Shell behaviour differences from stock zsh

- `WORDCHARS` is set to `*?[]~&;!#$%^(){}<>` — `/`, `.`, `_`, and `-` are removed from the default. This means `Ctrl+W` and word-motion commands stop at every path component and word boundary. Restore the originals by setting `WORDCHARS` in your `~/.zshrc` after the master-oogway block.

## User extensions

Drop a folder `my-thing/my-thing.plugin.zsh` into `~/.config/master-oogway/custom-plugins/` to load it as a plugin automatically — no `~/.zshrc` edit needed.

## Theme

The [dragon theme](omz-custom/themes/dragon/README.md) is configured interactively:

```bash
dragon-configure
```
