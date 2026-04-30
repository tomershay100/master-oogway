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

### atuin — SQLite shell history (future)

- [ ] **atuin** — replaces `HISTFILE` with a SQLite database. Every command gets
  a timestamp, working directory, exit code, and duration. `Ctrl+R` becomes a
  full fuzzy search across all of that. Optional cross-machine sync.
  Requires its own install script (not just apt on all distros).
  See: https://github.com/atuinsh/atuin
  Add to `install.sh` and `zshrc.template` once install flow is designed.
