# master-oogway — Project Roadmap

Tracks all items from the comprehensive codebase audit. Each item records its
status, rationale, and the commit or PR where it landed.

---

## ✅ Completed

| Item | Description | Resolved in |
|------|-------------|-------------|
| BUG-1 | `dragon-configure` option [2] "Full wizard" was silently resetting all user settings (same as [3]). Fixed: [2] now preserves current config. | PR #1 |
| BUG-2 | `_dragon_write_state` was dropping `dismissed_hash` on every configure run, causing the notifier to nag repeatedly. Fixed: state file rewritten atomically, all keys preserved. | PR #1 |
| BUG-3 | `dragon-notifier.zsh` accumulated duplicate `dismissed_hash=` lines; `grep` returned multi-line content, breaking the comparison. Fixed: `-m1` + atomic rewrite. | PR #1 |
| BUG-4 | `install.sh` overwrote `.zshrc.pre-master-oogway` on every run, silently destroying the original backup. Fixed: only backs up if no backup exists yet. | PR #1 |
| ARCH-3 | `configure.zsh` hard-coded `${HOME}/.master-oogway/` as themes dir. Fixed: derives from `${0:a:h}` like every other part file. | PR #1 |
| ARCH-6 | `exit_code` global was implicit and zero-uninitialized, risking stale reads. Fixed: `typeset -g _DRAGON_EXIT_CODE=0` in `dragon.zsh`. | PR #1 |
| ARCH-7 | `__get_readable_time` shadowed parameter `seconds` with a same-named local. Fixed: renamed to `secs`. | PR #1 |
| PERF-1 | `dragon-notifier.zsh` ran a full `grep -roh` scan on every shell start. Fixed: mtime cache — skip grep when theme files unchanged. | PR #1 |
| SEC-2 | `sshto` read only `~/.ssh/config`, silently omitting hosts behind `Include` directives. Fixed: enumerates `~/.ssh/config` + `~/.ssh/config.d/*`; handles multi-name `Host` stanzas. | PR #2 |
| FEAT-5 | No Nerd Font detection at configure time. Fixed: glyph probe in `_dragon_guided_tour()` — prints U+E0B0 + U+F07B, asks y/N, sets `USE_NERD_FONT=false` if not rendered. Only runs on first-run (when conf.zsh doesn't exist). | PR #2 |
| PERF-3 | `__get_readable_time` was called in a subshell `$()`, forking on every prompt render when exec-timer was active. Fixed: writes to `_DRAGON_READABLE_TIME` global; caller reads the var directly. | PR #1 |
| SEC-1 | `serve()` bound to `0.0.0.0` with no warning. Fixed: defaults to `127.0.0.1`; `SERVE_BIND` env var for intentional LAN exposure. | PR #1 |
| SEC-3 | `calc` whitelist comment was insufficient. Fixed: added comment explaining why `system("cmd")` is blocked. | PR #1 |
| DX-1 | `install.sh` had no `--help` flag. Fixed: added usage text documenting three modes and all options. | PR #1 |
| DX-2 | No `.editorconfig`. Fixed: added with tab indentation, LF endings, UTF-8 for all shell/make files. | PR #1 |
| DX-3 | `gsum()` called 5+ serial git subprocesses with `wc -l \| tr -d ' '` chains. Fixed: uses pure zsh array counting. | PR #1 |
| DX-6 | `declare -A COLORS` used bash syntax. Fixed: `typeset -A`. | PR #1 |
| FEAT-7 | Color validation in `dragon-configure` — invalid names silently produced no color. Fixed: validates against `COLORS` map, rejects out-of-range 0-255 values. | PR #1 |

---

## 🚧 In Progress

| Item | Description | Branch |
|------|-------------|--------|
| UNINSTALL | Backup files (`.zshrc.pre-master-oogway`, `.gitconfig.pre-master-oogway`) stranded after restore; `.zshenv` warning too vague. | `claude/uninstall-cleanup` → PR #3 |
| PRESET | `dragon-configure --preset <name>` for instant preset switching with backup instructions. | `claude/preset-switcher` → PR #4 |
| DOCS | README and CONTRIBUTING.md sweep — document `--preset`, `--dismiss`, `rezsh`, completeness pass. | `claude/docs-sweep` → PR #5 |

---

## ❌ Declined

| Item | Reason |
|------|--------|
| BUG-5 · trap shadowing in `_dragon_read_key` | No parent trap exists; theoretical risk, no real-world path to trigger it. |
| BUG-6 · conf parser `%%` edge case | Round-trip is safe because `_dragon_write_conf` controls the format; only affects hand-edited values outside supported workflow. |
| ARCH-5 · global variable pollution | Globals are in an owned `DRAGON__`/`REAL_DRAGON__`/`FINAL_DRAGON__` namespace; nameref refactor adds complexity for a cosmetic gain. |
| ARCH-4 · submodule version pinning | Deferred: adds maintenance burden; upstream projects are stable. Revisit if a breaking upstream change lands. |
| PERF-2 · preview subshell caching | Wizard is interactive at human speed; 200–500ms per preview is imperceptible in that context. |
| SEC-2 (recursive Include) | One level of includes (`~/.ssh/config → ~/.ssh/config.d/*`) covers the real-world bug. Recursive parsing is `ssh -G` territory — out of scope for a bugfix. |
| DX-4 · enum selection > 9 options | Current max is 3; single-keypress UX is a feature, not a bug. Revisit only if an enum ever needs ≥10 options. |
| DX-5 · `gen_readme.sh` plugin ordering | Script works; README is accurate; automating sort order has no functional impact. |
| FEAT-2 · atuin integration | Over-engineered for an installer; atuin is a personal choice, not a shell environment feature. |
| FEAT-3 · `dragon-configure --export/--import` | Solved adequately by sharing `conf.zsh` directly; the abstraction adds ~150 lines for no meaningful gain. |
| FEAT-4 · `dragon-theme` instant switcher | Redundant with `dragon-configure --new-only`; extra surface area without clear benefit. |
| FEAT-6 · `mo-docker` plugin | Out of scope; the existing `docker` OMZ plugin covers completion. Opinionated aliases belong in a user's `custom-zsh/`. |
| FEAT-8 · macOS/BSD support | Requires replacing GNU-specific sed, apt hints, and `stat` throughout. 1–2 days of testing; not scheduled. |
| FEAT-9 · `dragon-bench` startup profiler | `time zsh -i -c exit` is a one-liner any developer already knows; a wrapper adds no value. |

---

## 🅿️ Someday / Parked

These items have real merit but are not worth scheduling until a specific trigger occurs.

### FEAT-2 · atuin — SQLite shell history

- **Value**: Every command gets a timestamp, working directory, exit code, and duration. `Ctrl+R` becomes fuzzy search across all of that. Optional cross-machine sync.
- **Cost**: Requires its own installer (not just `apt`); adds a binary dependency. Integration in `install.sh` + `zshrc.master-oogway` is ~1 hour; testing across distros is more.
- **Trigger to revisit**: Once atuin ships stable multi-distro install scripts that can be embedded safely. See https://github.com/atuinsh/atuin
- **Notes**: Conflicts with `history-substring-search` Up/Down arrow behavior — needs `--disable-up-arrow` flag and testing.

---

### ARCH-1 · Drop oh-my-zsh dependency

- **Saving**: ~100ms per shell start; removes OMZ as a hard prerequisite.
- **Cost**: ~1–2 days of work replacing OMZ plugin loading, `compinit` setup, and `add-zsh-hook` compatibility shim.
- **Trigger to revisit**: If measured shell startup time exceeds ~250ms, or if a second user reports OMZ as a blocker.
- **Notes**: `add-zsh-hook` is already a native zsh built-in (`autoload -U add-zsh-hook`). The main OMZ dependency is completion init and plugin path management — both replaceable with ~30 lines of native zsh.
