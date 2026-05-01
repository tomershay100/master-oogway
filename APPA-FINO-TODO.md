# appa-fino — Audit TODO

Generated from a deep audit of every file in the submodule (excluding plugins).
Grouped by priority: 🔴 bugs → 🟠 issues → 🟡 enhancements.

---

---

## 🟡 Enhancements

### aliases — split into focused, opt-in files

- [ ] **Split aliases into per-topic files in `zsh-custom.d/`** so users can
  remove any group they don't want by deleting a single file. Suggested split:

  | File | Contents |
  |---|---|
  | `aliases-git.zsh` | all `g*` git aliases + `gsum` function |
  | `aliases-nav.zsh` | `ls`/`eza`, `cat`/`bat`, `less`/`bat`, `cd`-related |
  | `aliases-tools.zsh` | `grep`, `find`, `diff`, `ip`, `vim`/`nvim`, `mkdir`, `cp`, `mv` |
  | `aliases-safe.zsh` | `cp -i`, `mv -i`, safety-focused overrides |
  | `aliases-build.zsh` | `m`, `mc` (make / colormake) |
  | `aliases-misc.zsh` | `natip`, `gnucash`, `h`, `?`, `reboot`, `vizsh`, `soursh`, `cwhich`, `vwhich` |

  Current files `git-aliases.zsh` and `utilities-aliases.zsh` are merged into
  these. The **override aliases** (ones that shadow system commands like `cat`,
  `ls`, `vim`, `cp`, `mv`, `diff`, `ip`) should be clearly marked and easy to
  remove as a group.

### zshrc.template — comments and readability

- [ ] **Add inline comments throughout `zshrc.template`** so any user can
  understand and customize every section without reading external docs:
  - Each option/setopts line: one-liner explaining what it does
  - Each plugin: one-liner on what it adds
  - Each tool initialization block (fzf, direnv, zoxide): what it does + when
    to remove it if the tool isn't installed
  - Each PATH entry: why it's there and when to remove it
  - Consider reordering sections for readability:
    1. PATH additions (already at top — keep)
    2. History options (HISTSIZE, SAVEHIST, setopts)
    3. oh-my-zsh setup (ZSH, ZSH_THEME, ZSH_CUSTOM, flags)
    4. appa-fino conf source
    5. Plugins list
    6. `source oh-my-zsh.sh`
    7. Tool initializations (fzf opts, direnv, zoxide)
    8. Key bindings
    9. appa-fino update check

### atuin — SQLite shell history (future)

- [ ] **atuin** — replaces `HISTFILE` with a SQLite database. Every command gets
  a timestamp, working directory, exit code, and duration. `Ctrl+R` becomes a
  full fuzzy search across all of that. Optional cross-machine sync.
  Requires its own install script (not just apt on all distros).
  See: https://github.com/atuinsh/atuin
  Add to `install.sh` and `zshrc.template` once install flow is designed.
