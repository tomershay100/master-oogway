# master-oogway

A complete zsh shell environment — custom prompt theme (dragon), interactive
configurator, git aliases, fuzzy-finder functions, and 19 opt-in
oh-my-zsh plugins — distributed as a standalone git repo.

## What it does

- Clones itself to `~/.master-oogway/` (or symlinks when run from a dotfiles repo)
- Replaces `~/.zshrc` on first install with a curated template;
  never overwrites it again
- Copies `gitconfig.master-oogway` → `~/.gitconfig.master-oogway`,
  `zshenv.master-oogway` → `~/.zshenv`, and `editorconfig.master-oogway` → `~/.editorconfig`
- Adds `SendEnv DRAGON__*` to `~/.ssh/config` (creates it if missing) so
  your theme settings forward over SSH
- Adds `AcceptEnv DRAGON__*` to `/etc/ssh/sshd_config` (via sudo) so this
  machine accepts forwarded theme vars from other master-oogway clients
- Initialises plugin submodules (gitstatus, zsh-autosuggestions,
  zsh-syntax-highlighting, you-should-use)
- Loads the `dragon` prompt theme via `ZSH_CUSTOM=~/.master-oogway/omz-custom`
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

The installer auto-installs the **must-have** packages it needs via
`sudo apt install` (zsh, git, curl) and prints a post-install reminder for
**nice-to-have** packages that improve specific plugins (`bat`, `eza`, `fzf`,
`fd`, `meld`, `direnv`, `lsof`, `ripgrep`). Every nice-to-have plugin guards
its dependency at runtime, so the shell stays usable even if you skip them.

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

## Installed templates (re-copied on every `install.sh` run)

These three files in the repo (`*.master-oogway`) get copied to your home
directory as dotfiles every time you run the installer. Edit the repo
template and re-run `install.sh` to redeploy.

| Template (in repo) | Installed at | What it does |
|---|---|---|
| `zshenv.master-oogway` | `~/.zshenv` | Sourced for *every* zsh invocation (interactive shells, scripts, cron, sudoedit). Sets `EDITOR` / `VISUAL` (prefers `nvim` → `vim` → `vi`) so anything that consults them — git commit, `crontab -e`, `sudoedit` — uses your editor of choice. Kept minimal because non-interactive shells source it too. |
| `gitconfig.master-oogway` | `~/.gitconfig.master-oogway` | Curated git defaults — `init.defaultBranch=main`, `pull.rebase=true`, `push.autoSetupRemote=true`, `fetch.prune=true`, `rerere.enabled=true`, meld for diff/merge, sensible `branch.sort`/`tag.sort`, etc. Wired into your `~/.gitconfig` via `[include]` so your own `[user]` settings win. |
| `editorconfig.master-oogway` | `~/.editorconfig` | EditorConfig conventions (tab indentation, LF endings, UTF-8). Lives at `$HOME` so EditorConfig-aware editors apply it everywhere — they walk up from the file being edited and stop at the first match. |

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

Each override provides an escape hatch alias (`rls`, `rcat`, `rless`, `rvim`, `rcp`, `rmv`, `rmkdir`)
that bypasses the override and calls the original binary directly.

#### When the override gets in the way

Override plugins replace common commands with enhanced alternatives — but the
enhanced version is occasionally the wrong choice (concatenating binaries with
`cat`, scripting around `mv` that expects no `-i` prompt, copy-pasting commands
that assume the system `ls` flags, etc.). Two ways to bypass per command:

| You want to run… | Use either |
|------------------|------------|
| system `cat` (binary-safe) | `rcat <file>` or `\cat <file>` or `command cat <file>` |
| system `less` | `rless <file>` or `\less <file>` |
| system `vim` (not nvim) | `rvim <file>` or `\vim <file>` |
| system `cp` (no `-i` prompt) | `rcp src dst` or `\cp src dst` |
| system `mv` (no `-i` prompt) | `rmv src dst` or `\mv src dst` |
| system `mkdir` (no `-pv`) | `rmkdir dir` or `\mkdir dir` |
| system `ls` (not eza) | `rls` or `\ls` |
| system `tree` (not `eza --tree`) | `rtree` or `\tree` |

The `r<name>` aliases are defined by each override plugin; `\<name>` is a
shell-level trick that suppresses alias expansion for that one invocation.
Scripts running under `#!/usr/bin/env zsh` don't inherit interactive aliases,
so this only matters at the prompt.

### Additive plugins — new commands only

These only add new commands and never change existing behavior.

| Plugin | Provides |
|--------|---------|
| `mo-utils` | internal: `_mo_require` dependency-check helper (must be first additive plugin) |
| `mo-apps` | launcher aliases for GUI applications installed via flatpak |
| `mo-auto-ls` | auto-ls — runs ls automatically after every cd |
| `mo-build` | m (parallel make with optional colormake+banner) and mc (make clean) |
| `mo-cli` | `master-oogway` CLI — update / uninstall / version / doctor / configure / edit / path / help |
| `mo-dev` | calc, epoch, serve, md2pdf — developer utility functions |
| `mo-env` | fenv — fuzzy browser and inline editor for environment variables |
| `mo-files` | file management helpers — extract, bak, sizeof, fp |
| `mo-git` | git aliases, repo summary, and fuzzy branch/log pickers |
| `mo-navigation` | directory navigation helpers — mkcd, up, tmpcd, fcd |
| `mo-network` | natip (public IP lookup) and sshto (fuzzy SSH host picker) |
| `mo-lan-ssh` | bare-`<host>` aliases (fallback `s-<host>` on name collision) + ssh tab-completion for every SSH host discovered on your LAN (auto-refreshed) |
| `mo-process` | psgrep (search processes), port (what's on a port), fkill (fuzzy kill) |
| `mo-search` | grep aliases, find shortcut, and fuzzy history/man/ripgrep pickers |
| `mo-shell-tools` | shell inspection and config helpers — h, ?, cwhich, vwhich, vizsh, soursh, please |
| `mo-welcome` | welcome banner — system snapshot printed on every shell open |

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
| `fbranch` | fuzzy-select a branch and switch to it (hides branches with shell-unsafe names) |
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
| `extract <file>` | extract any archive format (`.zip` into `<file-basename>/` after a path-traversal pre-scan) |
| `bak <file>` | copy file to `<file>.bak.YYYYMMDD_HHMMSS` |
| `sizeof <path>` | disk usage of paths, sorted by size |
| `fp [dir]` | fuzzy-select a file and copy its full path to clipboard |

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
| `cwhich <cmd>` | cat the source of a command (syntax-highlighted via bat/batcat if installed) |
| `vwhich <cmd>` | open the source of a command in `$EDITOR` (falls back to vim) |
| `vizsh` | open `~/.zshrc` in `$EDITOR` (falls back to vim) |
| `soursh` | reload `~/.zshrc` |
| `please` | re-run the previous command with sudo |

### mo-cli — `master-oogway` command dispatcher

| Command | Description |
|---------|-------------|
| `master-oogway update` | pull latest master-oogway and re-run `install.sh` |
| `master-oogway uninstall` | run `install.sh --uninstall` (interactive) |
| `master-oogway version` | print the installed dragon version (date + commit) |
| `master-oogway doctor` | check which optional tools are installed and which apt packages provide the missing ones |
| `master-oogway configure [args]` | open `dragon-configure` (forwards args, e.g. `--preset short`) |
| `master-oogway edit` | open `~/.zshrc` in `$EDITOR` |
| `master-oogway path` | print the master-oogway install dir |
| `master-oogway help` | show all subcommands |

### mo-network — network helpers

| Command | Description |
|---------|-------------|
| `natip` | print your public IP address |
| `sshto` | fuzzy-select an SSH host and connect |

### mo-lan-ssh — LAN-wide SSH host discovery

Auto-discovers every SSH-listening host on your LAN, defines a bare-`<hostname>` alias per host (or `s-<hostname>` if the bare name would clash with an existing command/alias/function/builtin/reserved-word), and feeds the hosts to zsh's ssh/scp tab-completion. Re-scans on its own when the cache is stale (default 24h TTL) or when you move to a different network.

| Command | Description |
|---------|-------------|
| `<host>` | shorthand for `ssh <host>` — one alias per discovered host (or `s-<host>` if the bare name conflicts) |
| `mo-lan-ssh list` | print all known hosts (auto + manual, with `:port` if non-22, source tagged) |
| `mo-lan-ssh refresh [--background]` | re-scan the LAN; `--background` returns immediately |
| `mo-lan-ssh status` | show cache age, network ID, host counts (auto + manual), SSH config state |
| `mo-lan-ssh setup` | one-time: ensure `~/.ssh/config` has `Include config.d/*`, run first scan |
| `mo-lan-ssh add <host>[:<port>]` | persist a host in the manual overlay (takes effect immediately) |
| `mo-lan-ssh remove <host>` | remove from the manual overlay only (inverse of `add`) |
| `mo-lan-ssh trust <host>` | run `ssh-copy-id` if no key works (any host, including non-LAN) |
| `mo-lan-ssh forget <host>` | remove from auto cache + manual + `known_hosts` + ssh-config |
| `mo-lan-ssh help` | show all subcommands + env-var configuration |

**First-run behavior:** the first shell after install has no aliases (discovery runs in the background and takes ~3-15s depending on LAN size). The second shell you open has them.

**Discovery strategy:** tries DNS zone-transfer (AXFR) first; falls back to `nmap` ping-sweep + reverse DNS; then `arp-scan` (with passwordless sudo); finally parses `~/.ssh/known_hosts`. First strategy that returns ≥1 host wins. Each candidate is then port-probed to confirm an SSH listener.

**Non-default SSH ports:** set `MO_LAN_SSH_PORTS=22,2222,22022` to probe additional ports. Hosts on non-22 ports get a `Port` directive in `~/.ssh/config.d/lan-hosts` so `ssh <host>` automatically uses the right port.

**Tunable via env vars:** `MO_LAN_TTL`, `MO_LAN_SSH_PORTS`, `MO_LAN_PROBE_TIMEOUT`, `MO_LAN_PROBE_PARALLEL`, `MO_LAN_EXCLUDE`, `MO_LAN_SUBNET`, `MO_LAN_DNS_SERVER`, `MO_LAN_DNS_ZONE`, `MO_LAN_VERBOSE` — see `mo-lan-ssh help`.

**Auto SSH-key install** (the `ssh` wrapper): when you `ssh` (or `s-<host>`) any LAN host for the first time, the wrapper detects you don't have a key installed yet, runs `ssh-copy-id` for you (you'll be prompted once for your password), then connects. Next time you ssh to that host, you go straight in — no password. If the host gets reinstalled and its host key changes, the wrapper auto-purges the old key and accepts the new one (LAN-trust assumption). Set `MO_LAN_AUTO_TRUST=false` to disable both the auto-copy-id and the auto-purge.

The wrapper is gated tightly: only LAN hosts (per the cache) ever go through the probe. `ssh github.com`, `ssh work.example.com`, etc. pass straight through to system `ssh` with zero added latency or behavior change. The wrapper also auto-disables on piped/scripted ssh (`echo … | ssh foo cmd`) so it never interferes with non-interactive workflows.

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

The command prints the exact backup + restore one-liners and waits for `[y/N]`
before overwriting your config. If you backed up first (the printed `cp` to
`conf.zsh.bak`), you can revert any time with:

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
