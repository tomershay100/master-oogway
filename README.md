# appa-fino

A complete zsh shell environment — custom prompt theme, interactive
configurator, aliases, fzf functions, and oh-my-zsh plugins — distributed
as a standalone git repo.

## What it does

- Clones itself to `~/.appa-fino/` (or symlinks when run from the dotfiles
  repo)
- Replaces `~/.zshrc` on first install with a curated template; never
  overwrites it again
- Copies `.zshenv` and `.gitconfig` to `~/`
- Initialises plugin submodules (gitstatus, zsh-autosuggestions,
  zsh-syntax-highlighting, you-should-use)
- Loads the `appa-fino` prompt theme via `ZSH_CUSTOM=~/.appa-fino/zsh-custom.d`
- Stores user theme config in `~/.config/appa-fino/conf.zsh` — never
  overwritten after creation
- Notifies on shell start when new theme variables are available since the
  last `appa-fino-configure` run

## Installation

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/tomershay100/appa-fino/main/install.sh)"
```

oh-my-zsh must be installed first:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

## Updating

```bash
~/.appa-fino/install.sh
```

## User-owned files (never overwritten after creation)

| File | Created by |
|------|-----------|
| `~/.zshrc` | first install |
| `~/.config/appa-fino/conf.zsh` | `appa-fino-configure` wizard |
| `~/.gitconfig.local` | identity prompt during install |

## appa-fino theme configurator

Interactive wizard that steps through every theme feature group and writes
`~/.config/appa-fino/conf.zsh` with your choices.

```bash
appa-fino-configure            # full wizard
appa-fino-configure --new-only # only new variables since last run
```
