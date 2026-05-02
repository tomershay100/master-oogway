# master-oogway — Audit TODO

Generated from a deep audit of every file in the submodule (excluding plugins).
Grouped by priority: 🔴 bugs → 🟠 issues → 🟡 enhancements.

---

---

## 🟡 Enhancements

### atuin — SQLite shell history ✅ done

- [x] **atuin** — replaces `HISTFILE` with a SQLite database. Every command gets
  a timestamp, working directory, exit code, and duration. `Ctrl+R` becomes a
  full fuzzy search across all of that. Optional cross-machine sync.
  - `install.sh` now suggests atuin if not installed (with curl one-liner + `atuin import auto` hint)
  - `zshrc.master-oogway` initializes atuin when present: `eval "$(atuin init zsh --disable-up-arrow)"`
  - `--disable-up-arrow` preserves history-substring-search's Up/Down arrow bindings
  - atuin overrides fzf's Ctrl+R with its richer TUI when both are installed
