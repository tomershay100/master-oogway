# master-oogway

A complete zsh shell environment — custom prompt theme (dragon), interactive
configurator, git aliases, fuzzy-finder functions, and 17 opt-in
oh-my-zsh plugins — distributed as a standalone git repo.

## What it does

- Clones itself to `~/.master-oogway/` (or symlinks when run from a dotfiles repo)
- Replaces `~/.zshrc` on first install with a curated template;
  never overwrites it again
- Copies `gitconfig.master-oogway` → `~/.gitconfig.master-oogway` and `.zshenv` → `~/.zshenv`
- Adds `SendEnv DRAGON__*` to `~/.ssh/config` (creates it if missing) so
  your theme settings forward over SSH
- Adds `AcceptEnv DRAGON__*` to `/etc/ssh/sshd_config` (via sudo) so this
  machine accepts forwarded theme vars from other master-oogway clients
- Initialises plugin submodules (gitstatus, zsh-autosuggestions,
  zsh-syntax-highlighting, you-should-use)
- Loads the `dragon` prompt theme via `ZSH_CUSTOM=~/.master-oogway/master-oogway-omz-custom`
- Stores user theme config in `~/.config/master-oogway/conf.zsh` — never
  overwritten after creation
- Notifies on shell start when new theme variables are available since the
  last `dragon-configure` run

## Installation

oh-my-zsh must be installed first:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

Then install master-oogway:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/tomershay100/master-oogway/main/install.sh)"
```

## Updating

```bash
~/.master-oogway/install.sh
```

## User-owned files (never overwritten after creation)

| File | Created by | Notes |
|------|-----------|-------|
| `~/.zshrc` | first install | edit freely |
| `~/.config/master-oogway/conf.zsh` | `dragon-configure` | theme settings |

`~/.gitconfig` is created once with an `[include]` pointing to
`~/.gitconfig.master-oogway`. Your `user.name` and `user.email` live in
`~/.gitconfig` and are never touched by the installer after creation.

## Plugins

All master-oogway functionality is delivered as opt-in oh-my-zsh plugins.
They are listed in two groups in `~/.zshrc`. Comment out any line to disable it.

### Override plugins — replace system commands

These shadow existing commands. Remove any you don't want.

| Plugin | What it overrides |
|--------|------------------|
| `mo-eza-override` | `ls/ll/l/la/tree` → eza |
| `mo-bat-override` | `cat/less` → bat (syntax highlighting) |
| `mo-nvim-override` | `vim` → nvim |
| `mo-safety-override` | `cp/mv/mkdir/reboot` with confirmation prompts |
| `mo-colorize-override` | `ip/diff` → colorized output |

Each override provides an escape hatch alias (`rls`, `rcat`, `rless`, `rvim`)
that bypasses the override and calls the original binary directly.

### Additive plugins — new commands only

These only add new commands and never change existing behavior.

<!-- mo-plugins-start -->
| Plugin | Provides |
|--------|---------|
| `mo-apps` | launcher aliases for GUI applications installed via flatpak |
| `mo-auto-ls` | auto-ls — runs ls automatically after every cd |
| `mo-build` | m (parallel make with optional colormake+banner) and mc (make clean) |
| `mo-dev` | calc, epoch, serve, md2pdf — developer utility functions |
| `mo-env` | fenv — fuzzy browser and inline editor for environment variables |
| `mo-files` | file management helpers — extract, bak, sizeof, fp |
| `mo-git` | git aliases, repo summary, and fuzzy branch/log pickers |
| `mo-navigation` | directory navigation helpers — mkcd, up, tmpcd, fcd |
| `mo-network` | natip (public IP lookup) and sshto (fuzzy SSH host picker) |
| `mo-process` | psgrep (search processes), port (what's on a port), fkill (fuzzy kill) |
| `mo-search` | grep aliases, find shortcut, and fuzzy history/man/ripgrep pickers |
| `mo-shell-tools` | shell inspection and config helpers — h, ?, cwhich, vwhich, vizsh, soursh |
<!-- mo-plugins-end -->

> **Load order:** override plugins must appear before additive plugins in
> `~/.zshrc` so additive plugins inherit the overridden commands.

## Command reference

### mo-git — git shortcuts

| Command | Description |
|---------|-------------|
| `ga` | `git add` |
| `gaa` | `git add --all` |
| `gs` | `git status` |
| `gd` | `git difftool -y` |
| `gds` | `gd --staged` |
| `gl` | pretty graph log (all branches) |
| `glc` | pretty graph log (current branch) |
| `gls` | `glc --stat` |
| `glog` | compact one-line graph log |
| `gcm` / `gc` | `git commit -m` |
| `gco` | `git checkout` |
| `gcb` | `git checkout -b` |
| `gsw` | `git switch` |
| `gswc` | `git switch -c` |
| `grs` | `git restore` |
| `grss` | `git restore --staged` |
| `gb` | `git branch` |
| `gbd` | `git branch -d` |
| `gp` | `git push` |
| `gpl` | `git pull` |
| `gf` | `git fetch` |
| `gst` | `git stash` |
| `grb` | `git rebase` |
| `gcp` | `git cherry-pick` |
| `gundo` | undo last commit (keep changes staged) |
| `gclean` | remove untracked files and dirs |
| `gsum` | print branch + staged/unstaged summary |
| `fbranch` | fuzzy-select a branch and switch to it |
| `flog` | fuzzy-browse git log and show diff |

### mo-navigation — directory movement

| Command | Description |
|---------|-------------|
| `mkcd <dir>` | `mkdir -p` then `cd` into it |
| `up [n]` | go up `n` directory levels (default 1) |
| `tmpcd` | create a temp dir and `cd` into it |
| `fcd [dir]` | fuzzy-select a subdirectory and `cd` into it |

### mo-files — file management

| Command | Description |
|---------|-------------|
| `extract <file>` | extract any archive format |
| `bak <file>` | copy file to `<file>.bak.YYYYMMDD_HHMMSS` |
| `sizeof <path>` | disk usage of paths, sorted by size |
| `fpath [dir]` | fuzzy-select a file and copy its full path to clipboard |

### mo-search — search and fuzzy pickers

| Command | Description |
|---------|-------------|
| `grep` / `grepi` | colorized grep (case-sensitive / case-insensitive) |
| `f <pattern>` | `find . \| grepi <pattern>` |
| `fhist` | fuzzy-select a past command and load it into the prompt |
| `fman` | fuzzy-select and open a man page |
| `frg` | fuzzy ripgrep across file contents, open result in `$EDITOR` |

### mo-process — process management

| Command | Description |
|---------|-------------|
| `psgrep <name>` | list running processes matching name (case-insensitive) |
| `port <n>` | show which process is listening on port `n` |
| `fkill [signal]` | fuzzy-select processes to kill (TAB for multi-select) |

### mo-dev — developer utilities

| Command | Description |
|---------|-------------|
| `calc <expr>` | evaluate a math expression (`bc -l`; supports sqrt, s, c, l, e) |
| `epoch [ts]` | convert unix timestamp ↔ human date; no arg = current timestamp |
| `serve [port]` | start a local HTTP file server (default port 8000) |
| `md2pdf <file>` | convert Markdown to PDF via pandoc + xelatex |

### mo-shell-tools — shell introspection

| Command | Description |
|---------|-------------|
| `h` | last 50 history entries |
| `?` | print exit code of the last command |
| `cwhich <cmd>` | cat the source of a command |
| `vwhich <cmd>` | open the source of a command in vim |
| `vizsh` | open `~/.zshrc` in vim |
| `soursh` | reload `~/.zshrc` |

### mo-network — network helpers

| Command | Description |
|---------|-------------|
| `natip` | print your public IP address |
| `sshto` | fuzzy-select an SSH host and connect |

### mo-env — environment

| Command | Description |
|---------|-------------|
| `fenv` | fuzzy-browse and copy an environment variable value |

### mo-build — build helpers

| Command | Description |
|---------|-------------|
| `m` | `make -j$(nproc)` (with colormake + banner if installed) |
| `mc` | `make clean` |

### mo-apps — application launchers

Provides short aliases for GUI applications installed via flatpak.
Each alias is silently skipped if flatpak is not installed.

| Command | Description |
|---------|-------------|
| `gnucash` | launch GnuCash (personal finance) via flatpak |

---

## Theme configurator

Interactive wizard that steps through every theme feature group and writes
`~/.config/master-oogway/conf.zsh` with your choices.

```bash
dragon-configure                   # full interactive wizard
dragon-configure --new-only        # step through only newly added variables
dragon-configure --preset <name>   # instantly switch to a preset (no wizard)
dragon-configure --dismiss         # silence the notifier until the next theme update
dragon-configure --version         # print the installed dragon version
dragon-configure --help            # show all options
```

### Preset quick-switch

Switch to a named preset without running the full wizard:

```bash
dragon-configure --preset short     # minimal — hostname:dir$, inline git, no rprompt extras
dragon-configure --preset default   # balanced — user@host:dir ❯, git, time, exec-timer
dragon-configure --preset verbose   # maximum — multiline, full paths, rich git indicators
```

Before applying the switch you are shown the exact backup and restore commands.
To revert any time:

```bash
cp ~/.config/master-oogway/conf.zsh.bak ~/.config/master-oogway/conf.zsh && soursh
```

### Theme aliases

| Command | Description |
|---------|-------------|
| `rezsh` | reset all `DRAGON__*` vars to defaults, then reload the shell |
| `reset_theme_variables` | unset all `DRAGON__*` variables without reloading |

## SSH theme forwarding

master-oogway forwards your theme settings over SSH so you get your own
prompt on remote machines that also have master-oogway installed.

**Client side** (done automatically by `install.sh`):

```sshconfig
# ~/.ssh/config
Host *
    SendEnv DRAGON__*
```

**Server side** (done automatically by `install.sh` via sudo):

```text
# /etc/ssh/sshd_config
AcceptEnv DRAGON__*
```

If you are setting up a remote manually, add the `AcceptEnv` line and reload sshd:

```bash
sudo systemctl reload ssh
```
