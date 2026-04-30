# appa-fino — Audit TODO

Generated from a deep audit of every file in the submodule (excluding plugins).
Grouped by priority: 🔴 bugs → 🟠 issues → 🟡 enhancements.

---

## 🟠 Issues

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

### fzf Ctrl+T file preview (zshrc.template)

- [ ] **Make `Ctrl+T` show file contents in a preview pane**
  Add to `zshrc.template` after `FZF_DEFAULT_OPTS`:

  ```zsh
  export FZF_CTRL_T_OPTS="
    --preview 'bat --color=always --style=plain {} 2>/dev/null || cat {}'
    --preview-window=right:60%:wrap"
  ```

  Falls back to plain `cat` when `bat` is not installed.

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
