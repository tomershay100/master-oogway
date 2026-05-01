# appa-fino

A complete zsh shell environment — custom prompt theme, interactive
configurator, git aliases, fuzzy-finder functions, and 17 opt-in
oh-my-zsh plugins — distributed as a standalone git repo.

## What it does

- Clones itself to `~/.appa-fino/` (or symlinks when run from a dotfiles repo)
- Replaces `~/.zshrc` on first install with a curated template;
  never overwrites it again
- Copies `gitconfig` → `~/.gitconfig` and `.zshenv` → `~/.zshenv`
- Adds `SendEnv APPA_FINO__*` to `~/.ssh/config` (creates it if missing) so
  your theme settings forward over SSH
- Adds `AcceptEnv APPA_FINO__*` to `/etc/ssh/sshd_config` (via sudo) so this
  machine accepts forwarded theme vars from other appa-fino clients
- Initialises plugin submodules (gitstatus, zsh-autosuggestions,
  zsh-syntax-highlighting, you-should-use)
- Loads the `appa-fino` prompt theme via `ZSH_CUSTOM=~/.appa-fino/zsh-custom.d`
- Stores user theme config in `~/.config/appa-fino/conf.zsh` — never
  overwritten after creation
- Notifies on shell start when new theme variables are available since the
  last `appa-fino-configure` run

## Installation

oh-my-zsh must be installed first:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

Then install appa-fino:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/tomershay100/appa-fino/main/install.sh)"
```

## Updating

```bash
~/.appa-fino/install.sh
```

## User-owned files (never overwritten after creation)

| File | Created by | Notes |
|------|-----------|-------|
| `~/.zshrc` | first install | edit freely |
| `~/.config/appa-fino/conf.zsh` | `appa-fino-configure` | theme settings |
| `~/.gitconfig.local` | you | machine-specific git overrides (auto-included) |

`~/.gitconfig` is updated on every install run. Your `user.name` and `user.email`
are preserved automatically. Use `~/.gitconfig.local` for any machine-specific
git settings — it is included by `~/.gitconfig` and is never touched by the installer.

## Plugins

All appa-fino functionality is delivered as opt-in oh-my-zsh plugins.
They are listed in two groups in `~/.zshrc`. Comment out any line to disable it.

### Override plugins — replace system commands

These shadow existing commands. Remove any you don't want.

| Plugin | What it overrides |
|--------|------------------|
| `af-eza-override` | `ls/ll/l/la/tree` → eza |
| `af-bat-override` | `cat/less` → bat (syntax highlighting) |
| `af-nvim-override` | `vim` → nvim |
| `af-safety-override` | `cp/mv/mkdir/reboot` with confirmation prompts |
| `af-colorize-override` | `ip/diff` → colorized output |

Each override provides an escape hatch alias (`rls`, `rcat`, `rless`, `rvim`)
that bypasses the override and calls the original binary directly.

### Additive plugins — new commands only

These only add new commands and never change existing behavior.

| Plugin | Provides |
|--------|---------|
| `af-auto-ls` | run `ls` automatically after every `cd` |
| `af-git` | git aliases (`ga`, `gs`, `gp`, ...), `gsum`, `fbranch`, `flog` |
| `af-navigation` | `mkcd`, `up`, `tmpcd`, `fcd` (fuzzy cd) |
| `af-files` | `extract`, `bak`, `sizeof`, `fpath` (fuzzy file picker) |
| `af-search` | `grep`/`grepi` aliases, `f` (find shortcut), `fhist`, `fman`, `frg` |
| `af-network` | `natip` (public IP), `sshto` (fuzzy SSH host picker) |
| `af-process` | `psgrep`, `port`, `fkill` (fuzzy process kill) |
| `af-build` | `m` (parallel make), `mc` (make clean) |
| `af-dev` | `calc`, `epoch`, `serve` (HTTP server), `md2pdf` |
| `af-env` | `fenv` (fuzzy environment variable browser) |
| `af-shell-tools` | `h`, `?`, `cwhich`, `vwhich`, `vizsh`, `soursh` |
| `af-apps` | GUI app launchers (`gnucash` via flatpak) |

> **Load order:** override plugins must appear before additive plugins in
> `~/.zshrc` so additive plugins inherit the overridden commands.

## Command reference

### af-git — git shortcuts

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

### af-navigation — directory movement

| Command | Description |
|---------|-------------|
| `mkcd <dir>` | `mkdir -p` then `cd` into it |
| `up [n]` | go up `n` directory levels (default 1) |
| `tmpcd` | create a temp dir and `cd` into it |
| `fcd [dir]` | fuzzy-select a subdirectory and `cd` into it |

### af-files — file management

| Command | Description |
|---------|-------------|
| `extract <file>` | extract any archive format |
| `bak <file>` | copy file to `<file>.bak.YYYYMMDD_HHMMSS` |
| `sizeof <path>` | disk usage of paths, sorted by size |
| `fpath [dir]` | fuzzy-select a file and copy its full path to clipboard |

### af-search — search and fuzzy pickers

| Command | Description |
|---------|-------------|
| `grep` / `grepi` | colorized grep (case-sensitive / case-insensitive) |
| `f <pattern>` | `find . \| grepi <pattern>` |
| `fhist` | fuzzy-select a past command and load it into the prompt |
| `fman` | fuzzy-select and open a man page |
| `frg` | fuzzy ripgrep across file contents, open result in `$EDITOR` |

### af-process — process management

| Command | Description |
|---------|-------------|
| `psgrep <name>` | list running processes matching name (case-insensitive) |
| `port <n>` | show which process is listening on port `n` |
| `fkill [signal]` | fuzzy-select processes to kill (TAB for multi-select) |

### af-dev — developer utilities

| Command | Description |
|---------|-------------|
| `calc <expr>` | evaluate a math expression (`bc -l`; supports sqrt, s, c, l, e) |
| `epoch [ts]` | convert unix timestamp ↔ human date; no arg = current timestamp |
| `serve [port]` | start a local HTTP file server (default port 8000) |
| `md2pdf <file>` | convert Markdown to PDF via pandoc + xelatex |

### af-shell-tools — shell introspection

| Command | Description |
|---------|-------------|
| `h` | last 50 history entries |
| `?` | print exit code of the last command |
| `cwhich <cmd>` | cat the source of a command |
| `vwhich <cmd>` | open the source of a command in vim |
| `vizsh` | open `~/.zshrc` in vim |
| `soursh` | reload `~/.zshrc` |

### af-network — network helpers

| Command | Description |
|---------|-------------|
| `natip` | print your public IP address |
| `sshto` | fuzzy-select an SSH host and connect |

### af-env — environment

| Command | Description |
|---------|-------------|
| `fenv` | fuzzy-browse and copy an environment variable value |

### af-build — build helpers

| Command | Description |
|---------|-------------|
| `m` | `make -j$(nproc)` (with colormake + banner if installed) |
| `mc` | `make clean` |

---

## Theme configurator

Interactive wizard that steps through every theme feature group and writes
`~/.config/appa-fino/conf.zsh` with your choices.

```bash
appa-fino-configure            # full wizard
appa-fino-configure --new-only # only new variables since last run
```

## SSH theme forwarding

appa-fino forwards your theme settings over SSH so you get your own prompt
on remote machines that also have appa-fino installed.

**Client side** (done automatically by `install.sh`):

```sshconfig
# ~/.ssh/config
Host *
    SendEnv APPA_FINO__*
```

**Server side** (done automatically by `install.sh` via sudo):

```text
# /etc/ssh/sshd_config
AcceptEnv APPA_FINO__*
```

If you are setting up a remote manually, add the `AcceptEnv` line and reload sshd:

```bash
sudo systemctl reload ssh
```
