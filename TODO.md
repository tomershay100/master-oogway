# master-oogway — Audit TODO

Generated from a deep audit of every file in the submodule (excluding plugins).
Grouped by priority: 🔴 bugs → 🟠 issues → 🟡 enhancements.

---

---

## 🟡 Enhancements

### atuin — SQLite shell history (future)

- [ ] **atuin** — replaces `HISTFILE` with a SQLite database. Every command gets
  a timestamp, working directory, exit code, and duration. `Ctrl+R` becomes a
  full fuzzy search across all of that. Optional cross-machine sync.
  Requires its own install script (not just apt on all distros).
  See: https://github.com/atuinsh/atuin
  Add to `install.sh` and `zshrc.template` once install flow is designed.
