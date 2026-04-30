# appa-fino — Audit TODO

Generated from a deep audit of every file in the submodule (excluding plugins).
Grouped by priority: 🔴 bugs → 🟠 issues → 🟡 enhancements.

---

## 🟠 Issues

- [ ] **SSH forwarding: add `SendEnv APPA_FINO__*` to `~/.ssh/config`**
  The conf.zsh SSH guard is in place, but forwarding only works if the client
  sends the vars. Add to the `Host *` block in `~/.ssh/config` (or create one):

  ```sshconfig
  Host *
      SendEnv APPA_FINO__*
  ```

  The remote sshd also needs `AcceptEnv APPA_FINO__*` — this requires root on
  the remote, so document it rather than automate it.
  Consider adding the `SendEnv` line automatically during `install.sh`.

---

## 🟡 Enhancements

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
