# zsh-custom.d

oh-my-zsh custom directory. All `*.zsh` files here are sourced automatically on shell startup.

---

## Theme — dragon

A fully hand-rolled zsh theme. No framework dependency.

### Left prompt segments
| Segment | Description |
|---|---|
| SSH prefix | Shows `via ssh:` when connected over SSH |
| username | Current user (different color when via SSH) |
| hostname | Machine name (different color when via SSH) |
| directory | Current path — configurable as `short`, `regular`, or `full` |
| git status | Branch name + clean/dirty indicator + remote tracking state |
| prompt char | `❯` — green on success, red on failure |

### Right prompt segments
| Segment | Description |
|---|---|
| exit status | Exit code of last command (hidden on success) — shows signal name for signals (e.g. `SIGTERM`) |
| job count | Number of background jobs |
| exec timer | How long the last command took (shown above a configurable threshold) |
| date/time | Current time |

### Git status indicators
- `≡` — in sync with remote
- `↑N` — N commits ahead of remote
- `↓N` — N commits behind remote
- `*` suffix — dirty (unstaged or staged uncommitted changes)
- Green background — clean
- Aqua background — dirty

### Configuration
All settings are exposed as environment variables with the `DRAGON__` prefix.
See [`dragon-configure`](dragon-configure.zsh) or `dragon-configure --help` for the full reference.

To override a setting, set it before the theme loads (e.g. in `~/.zshrc`):
```zsh
DRAGON__ENABLE_USERNAME=false
DRAGON__DIRECTORY_FORMAT="short"
DRAGON__ENABLE_GIT_REMOTE_STATE=false
```

### Multiline separators (optional)
```zsh
DRAGON__FIRST_LINE_SEPARATOR_CHAR="╭ "
DRAGON__NEW_LINE_SEPARATOR_CHAR="│"
DRAGON__LAST_LINE_SEPARATOR_CHAR="╰╴"
```

---

## Aliases

### `dragon-aliases.zsh`
| Alias / Function | Description |
|---|---|
| `reset_theme_variables` | Unset all `DRAGON__*` variables (resets to defaults) |
| `rezsh` | Reset theme variables and re-source `~/.zshrc` |

### `git-aliases.zsh`
| Alias | Command |
|---|---|
| `gs` | `git status` |
| `ga` | `git add` |
| `gaa` | `git add --all` |
| `gc` / `gcm` | `git commit -m` |
| `gd` / `gds` | `git difftool` / `git difftool --staged` |
| `gl` / `glc` / `gls` | git log variants (graph, colored, with stats) |
| `gco` / `gcb` | `git checkout` / `git checkout -b` |
| `gsw` / `gswc` | `git switch` / `git switch -c` |
| `grs` / `grss` | `git restore` / `git restore --staged` |
| `gb` / `gbd` | `git branch` / `git branch -d` |
| `gp` / `gpl` / `gf` | push / pull / fetch |
| `gst` | `git stash` |
| `grb` / `gcp` | rebase / cherry-pick |
| `gundo` | Undo last commit, keep changes staged (`git reset --soft HEAD~1`) |
| `gsum` | Repo summary — branch, remote state, status, stashes |

### `utilities-aliases.zsh`
| Alias | Description |
|---|---|
| `cat` / `rcat` | `bat` with theme (use `rcat` for real `cat`) |
| `less` / `rless` | `bat` pager (use `rless` for real `less`) |
| `pcat` / `pless` | `bat` with full style (line numbers, git diff, etc.) |
| `ls` / `lsa` / `l` / `la` / `ll` | `eza` variants (use `rls` for real `ls`) |
| `tree` | `eza --tree` with git-ignore support |
| `vim` / `rvim` | `nvim` (use `rvim` for real `vim`) |
| `grep` / `grepi` | `grep` with color and sane excludes / case-insensitive |
| `cwhich` | `cat` the source of a command |
| `vwhich` | Open the source of a command in `$EDITOR` |
| `?` | Print exit code of last command |
| `natip` | Print your public IP address |
| `vizsh` | Open `~/.zshrc` in `$EDITOR` |
| `soursh` | Re-source `~/.zshrc` |
| `gmake` | `make -j$(nproc)` with color + PASSED/FAILED banner |

---

## Functions

### `utilities-functions.zsh`
| Function | Description |
|---|---|
| `mkcd <dir>` | Create directory (with parents) and cd into it |
| `up [n\|name]` | Go up N levels, or up to the nearest ancestor named `name` |
| `extract <file>` | Extract any archive format (tar, zip, gz, bz2, xz, zst, 7z, rar) |
| `port <number>` | Show which process is listening on a port |
| `md2pdf <file.md>` | Convert Markdown to PDF via pandoc + xelatex |

All functions support `-h` / `--help` for usage info.

### `fzf-functions.zsh`
Requires [fzf](https://github.com/junegunn/fzf). All functions are silently skipped if fzf is not installed.

| Function | Description |
|---|---|
| `fcd [base-dir]` | Fuzzy-select a directory and cd into it |
| `fpath [base-dir]` | Fuzzy-select a file and copy its absolute path to clipboard |
| `fkill [-signal]` | Fuzzy-select processes to kill (TAB for multi-select, default SIGTERM) |
| `flog` | Fuzzy-browse git log, copy selected commit hash to clipboard |
| `fenv [-e\|-E]` | Fuzzy-search env vars — print, edit inline (`-e`), or edit in `$EDITOR` (`-E`) |

All functions support `-h` / `--help` for usage info.
