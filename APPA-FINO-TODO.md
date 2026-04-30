# appa-fino — Audit TODO

Generated from a deep audit of every file in the submodule (excluding plugins).
Grouped by priority: 🔴 bugs → 🟠 issues → 🟡 enhancements.

---

## 🔴 Bugs

- [ ] **`appa-fino-conf.zsh` default values contradict the configure wizard**
  `zsh-custom.d/appa-fino-conf.zsh` lines 149–150 document
  `ENABLE_GIT_STASH_COUNT` and `ENABLE_GIT_REMOTE_STATE` as `true`, but
  `appa-fino-configure.zsh:_af_init_defaults` sets both to `"false"`. All
  commented out so no runtime impact, but it gives readers wrong information.

- [ ] **`_af_render_preview` leaks `_af_flag` into the shell namespace**
  `appa-fino-configure.zsh` line 557: `for _af_flag in "$@"` — `_af_flag`
  is not declared `local`, so it persists after `appa-fino-configure` returns.
  Fix: add `local _af_flag` at the top of the function.

- [ ] **`appa-fino-conf.zsh` line 191: missing space after `#`**
  `#set_if_unset APPA_FINO__ENABLE_JOB_COUNT false` — should be
  `# set_if_unset ...` for consistency with every other commented line.

---

## 🟠 Issues

- [ ] **Arrow key bindings fragile across terminals / tmux / SSH**
  `zshrc.template` lines 37–38 bind raw VT100 escape codes `^[[A` / `^[[B`.
  These break in tmux panes and some SSH sessions. Replace with:
  ```zsh
  bindkey "${terminfo[kcuu1]}" history-substring-search-up
  bindkey "${terminfo[kcud1]}" history-substring-search-down
  ```

- [ ] **`~/.local/bin` missing from PATH**
  `zshrc.template` adds `~/.npm-global/bin` but not `~/.local/bin`. Ubuntu
  puts `pip install --user`, `pipx`, and many other user-installed tools there.
  Add after the npm PATH block:
  ```zsh
  [[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"
  ```

- [ ] **`gnucash` alias is unconditional — loads on Pi and servers too**
  `utilities-aliases.zsh` line 92: the alias is defined regardless of whether
  `flatpak` is installed. Wrap it:
  ```zsh
  command -v flatpak &>/dev/null && alias gnucash="WEBKIT_DISABLE_COMPOSITING_MODE=1 flatpak run org.gnucash.GnuCash"
  ```

- [ ] **`gmake` alias requires `colormake` and `banner` with no fallback**
  `utilities-aliases.zsh` line 96: if `colormake` is not installed, `gmake`
  fails entirely instead of falling back to `make`. Guard or provide fallback:
  ```zsh
  if command -v colormake &>/dev/null && command -v banner &>/dev/null; then
      alias gmake="colormake -j$(nproc) && banner PASSED || (banner FAILED; false)"
  else
      alias gmake="make -j$(nproc)"
  fi
  ```
  Also note: `return 1` inside `(...)` is meaningless for the outer shell — use
  `false` or `exit 1` in the subshell instead.

- [ ] **`calc` is unsafe with shell metacharacters**
  `utilities-functions.zsh` line 174: `python3 -c "from math import *; print($*)"`.
  A user typing `calc '$(rm -rf ~)'` would execute it. Safer — pipe the
  expression as stdin so the shell never sees it:
  ```zsh
  python3 -c "from math import *; import sys; print(compile(sys.stdin.read(), '<calc>', 'eval'))" <<< "$*"
  # or simply use bc for arithmetic-only expressions:
  echo "$*" | bc -l
  ```

- [ ] **`appa-fino-conf.zsh` is a stale no-op, sourced every shell startup**
  Since this file lives in `ZSH_CUSTOM`, oh-my-zsh sources it on every shell
  start. It's ~267 lines of all-commented-out content — dead weight. The
  configure wizard generates its own richer conf at
  `~/.config/appa-fino/conf.zsh`. The preset blocks at the bottom duplicate
  the wizard's preset system. Consider deleting this file and pointing users
  to `appa-fino-configure`.

- [ ] **`sshto` shows no error when `~/.ssh/config` is absent or empty**
  `fzf-functions.zsh` line 15: fzf opens an empty picker with no feedback.
  Add an early exit:
  ```zsh
  [[ -s "$HOME/.ssh/config" ]] || { echo "sshto: ~/.ssh/config is empty or missing" >&2; return 1; }
  ```

---

## 🟡 Enhancements

### .gitconfig — many widely-adopted options are missing

- [ ] Add quality-of-life options:
  ```ini
  [pull]
      rebase = true           # no merge bubbles on pull
  [fetch]
      prune = true            # auto-delete stale remote refs
  [push]
      autoSetupRemote = true  # git 2.37+: auto-track on first push
  [rerere]
      enabled = true          # reuse recorded conflict resolutions
  [branch]
      sort = -committerdate   # most-recently-active branches first
  [tag]
      sort = version:refname  # semantic version sorting
  [log]
      date = iso              # consistent YYYY-MM-DD HH:MM everywhere
  ```

### zshrc.template — missing shell options

- [ ] Add useful zsh options near the HISTSIZE block:
  ```zsh
  setopt HIST_IGNORE_DUPS     # don't record duplicate consecutive commands
  setopt HIST_IGNORE_SPACE    # commands prefixed with space are not saved
  setopt HIST_FIND_NO_DUPS    # don't show duplicates in history search
  setopt AUTO_CD              # type dir name alone to cd into it
  ```

### New fzf functions (fzf-functions.zsh)

- [ ] **`fbranch`** — fuzzy git branch checkout (most-wanted missing function):
  ```zsh
  fbranch() {
      local branch
      branch=$(git branch -a --color=always \
          | grep -v '\->' \
          | fzf --ansi --height=40% --reverse \
                --preview 'git log --oneline --color=always {-1} | head -20') \
      && git switch "${branch##* }"
  }
  ```

- [ ] **`fhist`** — fuzzy history: select a past command and put it in the buffer:
  ```zsh
  fhist() {
      local cmd
      cmd=$(fc -ln 1 | fzf --tac --height=40% --reverse --no-sort)
      [[ -n "$cmd" ]] && print -z "$cmd"   # puts into readline buffer, not executed
  }
  ```

- [ ] **`fman`** — fuzzy man page browser:
  ```zsh
  fman() {
      local page
      page=$(man -k '' 2>/dev/null \
          | fzf --height=50% --reverse --preview 'man {1}' \
          | awk '{print $1}')
      [[ -n "$page" ]] && man "$page"
  }
  ```

- [ ] **`frg`** — fuzzy ripgrep: search file contents and open in editor:
  ```zsh
  frg() {
      command -v rg &>/dev/null || { echo "frg: rg not installed" >&2; return 1; }
      local result
      result=$(rg --color=always --line-number "" 2>/dev/null \
          | fzf --ansi --height=60% --reverse \
                --delimiter ':' --nth='1,3..' \
                --preview 'bat --color=always --highlight-line {2} {1}')
      [[ -n "$result" ]] && ${EDITOR:-vim} "$(cut -d: -f1 <<< "$result")" "+$(cut -d: -f2 <<< "$result")"
  }
  ```

### New utility functions (utilities-functions.zsh)

- [ ] **`tmpcd`** — create a temp dir and cd into it:
  ```zsh
  tmpcd() { local d; d=$(mktemp -d) && cd "$d" && echo "$d"; }
  ```

- [ ] **`bak`** — backup a file with a timestamp suffix:
  ```zsh
  bak() {
      local ts; ts=$(date +%Y%m%d_%H%M%S)
      for f in "$@"; do cp -v "$f" "${f}.bak.${ts}"; done
  }
  ```

- [ ] **`psgrep`** — search running processes by name:
  ```zsh
  psgrep() { ps aux | grep -v grep | grep -i "$1"; }
  ```

- [ ] **`serve`** — add a `command -v python3` guard (currently assumes it exists)

### New aliases (utilities-aliases.zsh)

- [ ] Add general quality-of-life aliases:
  ```zsh
  alias df="df -h"
  alias free="free -h"
  alias ..="cd .."
  alias ...="cd ../.."
  alias cp="cp -i"              # prompt before overwrite
  alias mv="mv -i"
  alias mkdir="mkdir -pv"       # always create parents, always verbose
  alias ip="ip --color=auto"    # Ubuntu 20.04+ colored ip output
  alias diff="diff --color=auto"
  alias h="history 50"          # quick recent history
  ```

### New git aliases (git-aliases.zsh)

- [ ] Add missing git workflow aliases:
  ```zsh
  alias grpo="git remote prune origin"    # clean stale remote branches
  alias gclean="git clean -fd"            # remove untracked files/dirs
  alias gwip="git add -A && git commit -m 'WIP'"
  alias gdiff="git diff"                  # inline diff without opening difftool
  alias gtag="git tag"
  alias gwtl="git worktree list"
  ```

### Plugin suggestions (zshrc.template)

- [ ] **zoxide** — frecency-based smart `cd` replacement. Far better than manual
  `up` + `fcd` for navigation.
  Install: `sudo apt install zoxide`
  Add to zshrc (after direnv block):
  ```zsh
  command -v zoxide &>/dev/null && source <(zoxide init zsh)
  ```

- [ ] **atuin** — SQLite-backed shell history with fuzzy search and timestamps.
  Replaces raw `HISTFILE`. Drop-in for Ctrl+R.
  See: https://github.com/atuinsh/atuin

- [ ] Enable existing oh-my-zsh plugins already available (zero install cost):
  - `docker` — tab completions for docker subcommands
  - `npm` — npm completions and aliases
  - `gh` — GitHub CLI completions

---

## 📋 Quick-win summary (highest impact / lowest effort)

| Fix | Effort | Impact |
|-----|--------|--------|
| Arrow key terminfo bindings | 2 lines | High — affects everyone on tmux/SSH |
| `~/.local/bin` in PATH | 1 line | High — pipx/pip tools invisible without it |
| `fbranch` fzf function | ~10 lines | High — most-used missing workflow |
| `.gitconfig` quality options | ~8 lines | High — daily git ergonomics |
| zoxide plugin | 2 lines + apt | High — transforms daily navigation |
| `reset_theme_variables` SSH_CONNECTION_COUNT | ~7 lines | Medium — theme testing correctness |
| `venv-autoactivate.zsh` — create or remove docs | varies | Medium — broken promise |
| `AUTO_CD` + history dedup options | 4 lines | Medium — shell ergonomics |
| `gnucash` flatpak guard | 2 lines | Medium — silent noise on non-desktop hosts |
| `gmake` colormake fallback | ~5 lines | Medium — alias unusable without colormake |
