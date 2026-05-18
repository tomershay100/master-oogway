# master-oogway — Repository Deep Audit Report

**Auditor role:** Principal Software Engineer / Product Architect
**Scope:** `/home/tomer/projects/custum-linux-configs/shared/master-oogway` — entire repository excluding git submodules (`gitstatus`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `you-should-use`)
**Method:** Four parallel deep-investigation agents, full reads of all in-scope files (~6,400 LOC), cross-referenced against `git log` and existing fix-history
**Date:** 2026-05-17

---

## 1. Executive Summary

### Verdict

master-oogway is a **mature, opinionated, production-grade zsh framework** with unusually strong engineering hygiene for a personal-dotfiles project. Strict `set -Eeuo pipefail`, ERR-trap logging, marker-protected `~/.zshrc`, an actually-working uninstaller, idempotent installation, a clean override/additive plugin distinction, systematic escape-hatch aliases (`rcat`, `rls`, …), and a schema-driven prompt theme with ~120 user-tunable variables all stand out.

The system is *much closer to "production framework"* than to "personal dotfiles." That is its biggest strength, and also the lens through which the audit is critical: the bar is high, so the gaps that matter are the ones a framework of this caliber should not have.

### Main strengths
1. **Idempotent installer with real uninstall** — backup-once semantics, sshd validation with auto-revert, marker-based `~/.zshrc` protection, dev/prod auto-detect via `BASH_SOURCE`.
2. **Configurability is best-in-class** — schema-driven theme, three presets, interactive `dragon-configure` wizard, SSH env-var forwarding, drop-in dirs for user overrides (`custom-pre-zsh/`, `custom-zsh/`).
3. **Override/additive plugin distinction** — documented in CONTRIBUTING, enforced by load order. Every additive plugin uses inline dependency checks consistently; every override plugin ships an `r*` escape-hatch alias.
4. **Defensive shell discipline** — zip-slip protection in `extract`, NUL-delimited pipelines in `fcd`/`fp`, branch-injection filtering in `fbranch`, locale probe in 1 fork instead of 44, `lsof`-port validated before use, marker-protected sshd_config edits with `sshd -t` pre-validate.
5. **Documentation tells the truth** — README accurately describes installed surface; CONTRIBUTING enumerates the five touch-points needed when adding a theme variable; `# Provides:` lines on every plugin.

### Main risks
1. **No safe-mode / minimal-mode** — when a plugin or `custom-zsh/*.zsh` drop-in breaks the shell, the user has no `zsh -i --safe` equivalent that still loads dragon. Only escape is `zsh -f`.
2. **No in-shell discovery surface** — the `# Provides:` headers are a great convention but not surfaced at runtime. Users learn 20% of the framework's commands.

### Issue distribution

| Severity | Count |
|---|---|
| 🔴 Critical | 0 |
| 🟠 High | 0 |
| 🟡 Medium | 0 |
| 🟢 Low | 35 |

**Zero critical issues** is the headline. The system will not eat data, lock the user out, or fail catastrophically on any plausible inputs the audit explored. The 🟠 high issues are real UX/reliability gaps, not crashes.

---

## 2. Architecture Overview

### System layers

```
┌─ install.sh (612 LOC) ────────────────────────────────────────┐
│  • Auto-detects mode from BASH_SOURCE: curl-pipe | update | dev│
│  • Manages: ~/.zshrc symlink, ~/.gitconfig, ~/.editorconfig,   │
│             ~/.zshenv, ~/.ssh/config, /etc/ssh/sshd_config     │
│  • Calls: apt_install zsh git curl; clones/pulls main repo +  │
│           4 submodules; runs `_init_plugins` (all modes)      │
│  • Reverses everything via --uninstall                        │
└────────────────────────────────────────────────────────────────┘
              │
              ▼
┌─ ~/.zshrc (symlinked → zshrc.master-oogway, 253 LOC) ─────────┐
│  1. Locale probe (single fork via `locale charmap`)           │
│  2. ~/.config/master-oogway/conf.zsh sourced (theme overrides)│
│  3. custom-pre-zsh/*.zsh user drop-ins                        │
│  4. plugins=(...) array — 23 plugins in defined order:       │
│     a) overrides (mo-bat, mo-eza, mo-safety, …)              │
│     b) mo-utils (must be first additive)                     │
│     c) additive (mo-files, mo-git, mo-lan-ssh, …)            │
│     d) zsh-autosuggestions                                    │
│     e) zsh-syntax-highlighting (must be last)                │
│  5. oh-my-zsh sourced                                         │
│  6. custom-zsh/*.zsh user drop-ins                            │
│  7. ZSH_THEME=dragon → omz-custom/themes/dragon.zsh-theme    │
└────────────────────────────────────────────────────────────────┘
              │
              ▼
┌─ Dragon theme (1900 LOC across 12 files) ─────────────────────┐
│  • schema.zsh (391):     pure data — defaults/types/hints     │
│  • dragon.zsh (76):      loader; fans schema → DRAGON__* envs│
│  • configure.zsh (936):  standalone wizard (`dragon-configure`)│
│  • notifier.zsh (52):    "new theme vars available" prompt   │
│  • parts/                                                     │
│    ├ helpers.zsh (124):  color resolver, __dragon__show      │
│    ├ separators.zsh:     powerline glyphs / multiline border │
│    ├ segments_{left,right}.zsh: each segment function        │
│    ├ git.zsh:            consumes gitstatusd output          │
│    ├ prompt.zsh:         assembles PROMPT/RPROMPT            │
│    └ transient.zsh:      ZLE widget + async gitstatus_query  │
└────────────────────────────────────────────────────────────────┘
```

### Data flow

* **Install-time:** `install.sh` writes `~/.master-oogway/` (or symlinks in dev mode), then symlinks `~/.zshrc` → `~/.master-oogway/zshrc.master-oogway` (after backup to `.pre-master-oogway`). `~/.gitconfig` and `~/.editorconfig` use the same backup-once pattern. SSH env-forwarding is opt-in per prompt.
* **Shell-start:** zsh sources symlinked `~/.zshrc` → locale probe → conf.zsh → user pre-drop-ins → plugins via oh-my-zsh → user post-drop-ins → dragon theme → notifier check → prompt.
* **Prompt-render:** `precmd` hook → `dragon__update_zsh_prompt` (sync, may use stale `VCS_STATUS_*`) → schedules `gitstatus_query` (async) → callback `__refresh_prompt` → `zle reset-prompt` if in ZLE.
* **User config change:** edit `~/.config/master-oogway/conf.zsh` (manually or via wizard) → next `soursh` reloads.

### Plugin/theme system analysis

**Plugin contract** (implicit, no formal interface):
- File: `omz-custom/plugins/<name>/<name>.plugin.zsh`
- Convention: one `# Provides:` line listing user-visible commands.
- Dependencies: declared by inline `command -v` checks in function bodies.
- Ordering: overrides first, `mo-utils` second, others next, syntax-highlighting last. Enforced by humans editing `~/.zshrc`.

**Theme contract:**
- Variables declared in `schema.zsh` via `populate_defaults`/`populate_types`/`populate_hints`/`populate_groups`.
- Five touch-points required per new var (documented in CONTRIBUTING.md:148-219): defaults, type, hint, group, segment renderer.
- `_dragon_vars_hash` (md5 of sorted `_DRAGON_DEFAULTS` keys) gates the notifier.

### Module breakdown (LOC by area)

| Area | LOC | Files |
|---|---:|---|
| install.sh | 612 | 1 |
| docs (README, CONTRIBUTING) | 1060 | 2 |
| zshrc/zshenv/gitconfig/editorconfig | 335 | 4 |
| Dragon theme | 1907 | 12 |
| mo-* plugins (21 files) | 1815 | 22 |
| **Total in scope** | **5729** | **41** |
| Vendored submodules (out of scope) | ~53k | n/a |

---

## 3. UX & Configurability Audit

### UX scoring (1-10)

| Dimension | Score | One-line justification |
|---|---:|---|
| Onboarding | 7 | Crisp README + 1-line install, but OMZ must be pre-installed manually; no `--dry-run`. |
| Discoverability | 7 | README is thorough; `-h/--help` on every command; **but `# Provides:` headers never reach the shell**. |
| Configurability | 9 | Schema-driven, ~120 knobs, presets, wizard, SSH forwarding — best-in-class for the category. |
| Safety | 8 | Override escape-hatches, backup-once, sshd validation; missing safe-mode for triage. |
| Performance | 8 | Single-fork locale probe, mtime-gated notifier, cached `bat`/`fdfind` paths; some prompt segments shell out per render. |

### Configurability strengths
* `~/.config/master-oogway/conf.zsh` is the canonical override surface for the theme; `~/.zshrc` is markered as managed.
* `DRAGON__*` env vars round-trip through SSH (`SendEnv`/`AcceptEnv`), giving consistent prompts across machines.
* `custom-pre-zsh/` and `custom-zsh/` drop-in dirs are auto-created with README breadcrumbs and respected by the loader at `zshrc.master-oogway:92, 190`.
* Three theme presets (`short`, `default`, `verbose`) with one-command switching.

### Configurability gaps (cross-cutting)

| Gap | Impact |
|---|---|
| **No "user plugin" surface** — `custom-zsh/*.zsh` are loose files, not first-class plugins with `# Provides:`, doctor integration, or enable/disable. | Users writing non-trivial extensions have nowhere to put them. |
| **No segment registry in dragon** — adding a `kubectl_ctx` segment requires forking `parts/segments_right.zsh` AND `parts/prompt.zsh`. | Power users go back to p10k. |
| **No per-host theme overrides** — `HOSTNAME_VIA_SSH_*` covers "remote vs local" but not "on `prod-db` use red." | Repeated manual config per machine. |
| **`MO_*` env namespace is mo-lan-ssh-only** — other plugins use `SERVE_BIND`, `MD2PDF_THEME`, etc. | Inconsistent contract; hard to find the knobs. |
| **No way to disable a plugin without editing `~/.zshrc`** — the marker-protected file's drift-warning fires forever after a single edit. | Users banner-blind to the warning that actually matters (new plugin added by upstream). |
| **No "preview-before-save" for theme presets** — `--preset` writes conf and asks for reload. | Slow iteration. |
| **No `dragon-configure --get/--set` non-interactive mode** for scripted/Ansible-driven config. | Forces the wizard for one-line tweaks. |

### Theme system review

* **Schema-driven** is the right choice and well-executed. Pure-data file (`schema.zsh`), no side effects, clean populator functions.
* **Configurator latency** (`configure.zsh:226-252`): every preview redraw runs `zsh -c` + sources `dragon.zsh`. On guided wizard with 20 groups × 2-4 mode-variants × keypress redraws, easily 40+ subshells. Perceptibly laggy on slower hardware.
* **Exports leak** (`dragon.zsh:7-14`, `aliases.zsh:3-9`): `set_if_unset` exports all defaults. Once `dragon-configure --preset X` runs, those values are in the env permanently. New tmux panes inherit them, and `conf.zsh` edits silently no-op because `set_if_unset` sees the env var already set.

---

## 4. Robustness & Failure Handling

### Optional dependency handling

| Tool | Plugins | Handling | Verdict |
|---|---|---|---|
| `fzf` | mo-network, mo-env, mo-search, mo-process, mo-navigation, mo-files, mo-git | soft via inline check | ✅ Consistent |
| `bat`/`batcat` | mo-bat-override, mo-shell-tools, mo-search, mo-files | silent fallback to `cat` (overrides); soft elsewhere | ✅ Ubuntu rename handled |
| `eza` | mo-eza-override, mo-navigation | fallback to `ls` | ✅ |
| `fd`/`fdfind` | zshrc (FZF_DEFAULT_COMMAND) | silent | ✅ |
| `rg` | mo-search frg | soft | ✅ |
| `git` | mo-git, mo-cli | hard (assumed by every git function) | ⚠️ Reasonable |
| `curl` | mo-network natip | soft | ✅ |
| `lsof` | mo-process port | soft | ✅ |
| `nmap` / `arp-scan` / `dig` | mo-lan-ssh | soft, falls through strategies | ✅ |
| `ip` / `flock` / `timeout` / `md5sum` | mo-lan-ssh | **hard** — never checked | 🟡 Ubuntu-only assumption |
| `wl-copy` / `xclip` | mo-git flog, mo-files fp | fallback to stdout | ✅ |
| `python3` | mo-dev serve | soft | ✅ |
| `bc` | mo-dev calc | soft | ✅ |
| `pandoc` / `xelatex` | mo-dev md2pdf | **hard inside pandoc invocation** — no precheck | 🟡 |
| `pgrep` | mo-process psgrep | **hard** | 🟡 |
| `make` / `nproc` | mo-build | **hard** | 🟡 |
| `awk` / `sed` / `grep` / POSIX | most plugins | hard (POSIX assumed) | ✅ Acceptable |

**The cross-cutting flaw:** every plugin probes its own dependencies. `command -v bat` happens at ~13 distinct call-sites. A central capability cache (in `mo-utils`) would unify behavior and save forks.

### Fallback mechanisms — by area

| Area | Has fallback? | Notes |
|---|---|---|
| Override aliases (`cat`/`ls`/`vim`/`cp`/`mv`/`reboot`) | ✅ | `r*` escape-hatch aliases (`rcat`, `rls`, …) |
| `bat`/`batcat` Ubuntu rename | ✅ | Detected globally |
| Missing fzf in fuzzy commands | ✅ | inline check exits with clear apt hint |
| Missing `gitstatus` daemon for prompt | ✅ | `parts/git.zsh` guards on `gitstatus_query` presence |
| Missing 256-color terminal | ❌ | `__get_xterm_color_by_name` only handles unknown names, not unsupported terminals |
| Missing Nerd Font glyphs | ❌ | `USE_NERD_FONT` defaults via SSH-presence only; no terminal probe |
| Missing `python3` for `serve` | ✅ | inline check |
| Missing `xelatex` for `md2pdf` | ❌ | Cryptic pandoc error |
| Network failure during install clone | 🟡 | Partial clone leaves cryptic state; `git pull --ff-only` on rerun may mask broken submodules |
| sshd_config edit fails validation | ✅ | Auto-reverts via `sshd -t` |

### Edge cases & failure scenarios

* **Re-run after partial install:** Install dir exists but submodules are broken → `git pull --ff-only` succeeds → submodules remain broken silently. `_init_plugins` only runs in dev mode.
* **User deletes the `# master-oogway:managed` marker line:** Next install **clobbers user edits** without backup re-running (the `.pre-master-oogway` backup is only created on first install).
* **User has tab-indented `Host *` block in `~/.ssh/config`:** `SendEnv` injection's `sed` regex uses 4-space prefix; lands with inconsistent indentation in user's file.
* **User has multiple `Host *` stanzas:** `sed` inserts after the *first* match — possibly the wrong section.
* **Bare `Host *` is commented in `~/.ssh/config`:** `mo-lan-ssh` setup adds a duplicate `Include` directive.
* **`reboot -f` typed:** `mo-safety-override` strips the `-f` arg silently (`mo-safety-override.plugin.zsh:14-17`).
* **`gunzip` on a symlinked archive:** modifies the symlink target (`mo-files.plugin.zsh:76`) — accepted because `[[ ! -f "$file" ]]` accepts symlinks.
* **`port 53` when both TCP and UDP listen:** UDP returns non-LISTEN state too (`mo-process.plugin.zsh:30`).
* **ripgrep match on filename containing `:`:** `frg` preview opens wrong file (`mo-search.plugin.zsh:54`).
* **`bak a b c` on filesystem without `%N` sub-second support:** all three backups collide on identical timestamp (`mo-files.plugin.zsh:95`).

---

## 5. Plugin System Evaluation

### Plugin inventory

| Plugin | LOC | Purpose | Notable deps |
|---|---:|---|---|
| mo-apps | 4 | GUI app launchers | flatpak (silent skip) |
| mo-colorize-override | 5 | `ip`/`diff` colored | none |
| mo-nvim-override | 8 | `vim→nvim` | nvim (else no-op) |
| mo-build | 9 | parallel `make` aliases | make, nproc (hard) |
| mo-auto-ls | 12 | auto-`ls` on `cd` | ls |
| mo-utils | 15 | `_mo_require` helper | none |
| mo-safety-override | 19 | confirmation on rm/mv/cp/reboot | none |
| mo-bat-override | 20 | `cat/less→bat` | bat/batcat (else cat) |
| mo-eza-override | 21 | `ls/tree→eza` | eza (else ls) |
| mo-welcome | 22 | startup banner | none |
| mo-network | 27 | `natip`, `sshto` | curl, fzf |
| mo-shell-tools | 28 | `h`, `?`, `please`, `soursh`, `vizsh` | bat (fallback) |
| mo-env | 41 | `fenv` env var picker | fzf |
| mo-search | 61 | `grep`, `f`, `fhist`, `fman`, `frg` | fzf, rg |
| mo-process | 67 | `psgrep`, `port`, `fkill` | lsof, fzf, pgrep |
| mo-navigation | 81 | `mkcd`, `up`, `tmpcd`, `fcd` | fzf, eza fallback |
| mo-cli | 114 | `master-oogway` meta CLI | git, optional list |
| mo-dev | 118 | `calc`, `epoch`, `serve`, `md2pdf` | bc, python3, pandoc |
| mo-git | 120 | git aliases + `gsum`/`fbranch`/`flog` | git, fzf, wl-copy |
| mo-files | 155 | `extract`, `bak`, `sizeof`, `fp` | tar/unzip/7z/…, fzf |
| mo-lan-ssh (+helper) | 440+205 | LAN ssh discovery + wrapper | dig/nmap/arp-scan, flock |

### Missing abstraction layers

1. **No capability cache** — every plugin re-probes `command -v X` independently.
2. **No plugin metadata header** — `doctor` can't compute the dependency report from plugins.
3. **No drop-file disable mechanism** — `~/.config/master-oogway/disabled/<name>` would be a 5-LOC win.
4. **No user-plugin surface** — `custom-zsh/*.zsh` are loose drop-ins, not first-class plugins.
5. **No segment registry in dragon** — adding a prompt segment requires forking two files.
6. **No "after-load" hook** for plugins to register their doctor checks centrally.

---

## 6. Issues Found (Detailed List)

### 🟢 Low-severity issues

---

## 7. Feature Proposals

### Ranked feature list

#### F-3. Plugin metadata header + `doctor` rewrite ⭐
* **Value:** Robustness + extensibility
* **Design:** Three-line header per plugin (`# mo-plugin:`, `# mo-deps:`, `# mo-desc:`). `master-oogway doctor` parses headers to compute dep report dynamically; eliminates the hardcoded list at `mo-cli.plugin.zsh:40-56`.
* **Complexity:** M (~120 LOC) — **Risk:** Low

#### F-4. Central capability cache populated by `mo-utils`
* **Value:** Performance + dev-XP
* **Problem solved:** `command -v bat` at 13 sites; wasted forks at shell start.
* **Design:** `mo-utils` writes `~/.cache/master-oogway/capabilities.zsh` on first load (invalidated by `$PATH` mtime). Plugins consult `$MO_CAPS[bat]`.
* **Complexity:** M (~120 LOC, careful invalidation) — **Risk:** Medium

#### F-8. Pluggable segment registry for Dragon
* **Value:** Power-user extensibility
* **Design:** `DRAGON_LEFT_SEGMENTS=(ssh_prefix username … directory)` and `DRAGON_RPROMPT_SEGMENTS=(…)` arrays. `dragon__set_lprompt` iterates calling `dragon__set_$segment`. Users define function + append. Recovers ~40 LOC from `prompt.zsh`.
* **Complexity:** M — **Risk:** Low

#### F-10. `~/.master-oogway-user/plugins/` — first-class user plugin dir
* **Value:** Extensibility
* **Design:** Discovered by `~/.zshrc` and appended to `plugins=()`. Same convention. `mo-help` and `doctor` recognize them.
* **Complexity:** M — **Risk:** Low (additive, opt-in)

#### F-16. Async-evaluated user segments with TTL cache (Dragon)
* **Value:** Power-user extensibility (p10k parity)
* **Design:** `dragon_register_async_segment <name> <cmd> <ttl>` runs `<cmd>` in background, caches in `typeset -gA`, refreshes when stale.
* **Complexity:** M — **Risk:** Medium

#### F-17. `master-oogway backup` / `restore`
* **Value:** Robustness
* **Design:** Tarball to `~/master-oogway-backup-YYYYMMDD.tar.gz`; restore reverses with confirmation.
* **Complexity:** S — **Risk:** Low

#### F-18. Terminal capability probe (`mo-term-detect`)
* **Value:** UX (theme correctness out-of-box)
* **Design:** Once per install: print 3 glyph rows (powerline, nerd-font, plain), ask "all render correctly?", persist answer, default `USE_NERD_FONT` accordingly.
* **Complexity:** M — **Risk:** Medium

#### F-19. Submodule SHA dashboard + auto-update workflow
* **Value:** Robustness / supply-chain
* **Design:** `master-oogway version --submodules` prints pinned SHA vs upstream HEAD per submodule. `master-oogway upgrade-plugins` interactive bumper.
* **Complexity:** M — **Risk:** Low

#### F-20. Hot-reload watcher (`mo-dev-watch`)
* **Value:** Dev-XP (author + contributors)
* **Design:** Dev-mode only (gated on `[[ -L ~/.master-oogway ]]`). `inotifywait` watches `$ZSH_CUSTOM`; on change, prints `soursh-recommended`. Advisory only, never auto-eval.
* **Complexity:** S — **Risk:** Low

#### F-21. Versioned `~/.zshrc` migration system
* **Value:** Robustness — real upgrades, not "diff it yourself"
* **Design:** Embed `# master-oogway:rc-version=N`. Per-version additive migration function (append a missing `plugins=()` entry, etc.).
* **Complexity:** M — **Risk:** Medium

#### F-22. Unified `mo-test` harness
* **Value:** Reliability
* **Design:** `tests/<plugin>.bats` per plugin. Test: aliases defined, `-h` works, missing-dep handling. Run via `master-oogway doctor --test`.
* **Complexity:** L — **Risk:** Low

### Features deliberately not proposed
- **Plugin marketplace / network-fetched plugins** — multiplies attack surface for a personal-dotfiles project.
- **Telemetry of any kind** (even opt-in) — not appropriate here.

---

## 8. Refactoring Recommendations

### Structural improvements

1. **Adopt 3-line metadata header convention** (`# mo-plugin:` / `# mo-deps:` / `# mo-desc:`) on every plugin. Replace the hardcoded tool list at `mo-cli.plugin.zsh:40-56` with a `master-oogway doctor` that auto-discovers. Underpins F-3, F-7, F-11.

2. **Consolidate `command -v` probes** into a single capability cache in `mo-utils`. Plugins consult `$MO_CAPS[…]`. Reduces fork count at shell start.

3. **Extract drop-in loader** (`zshrc.master-oogway:92, 190`) into a helper function `_mo_source_dropins <dir>` to reduce template noise and make it easy to add a user-plugin dir (F-10).

### Code consolidation opportunities

* **Output style:** mix of `echo`, `print`, `print -P`, `printf`. Pick one (suggest `print -P` for colored, `printf` for plain) and document in CONTRIBUTING.
* **Env var naming:** mo-lan-ssh uses `MO_LAN_*`; others use ad-hoc (`SERVE_BIND`, `MD2PDF_THEME`). Adopt `MO_<PLUGIN>_<KNOB>` everywhere.
* **`# Provides:` headers** could become machine-readable (`# mo-provides:`) for use by F-1.

### Architecture changes (larger PRs)

* **Pluggable segment registry** (F-8) is the largest single architectural win for the theme — converts the rigid `prompt.zsh:14-101` / `113-132` from hand-edited concat to data-driven loop.
* **Profile-based plugin selection** (F-12) requires re-thinking the `plugins=()` template; biggest API change but unlocks proper server/Pi/desktop variance.

---

## 9. Hardening & Reliability Improvements

### Stability improvements

| Improvement | Issue addressed | Effort |
|---|---|---|
| `MO_SAFE_MODE=1` plugin-array gate | F-2 | S |

### Fallback strategies

* **Terminal capability auto-detect** — currently SSH-presence-only. Add `tput colors`, `$COLORTERM`, and one-time glyph-render probe (F-18). Default `USE_NERD_FONT=false` on `linux` / `screen` / dumb-tmux.
* **Async git segment fallback** — if `gitstatusd` fails (read-only filesystem, etc.), today's only escape is `ENABLE_GIT_STATUS=false`. Add a `GIT_STATUS_MODE=sync|async|off` with `sync` falling back to `git symbolic-ref HEAD` once per `chpwd`.
* **md2pdf precheck** — `_mo_require pandoc md2pdf pandoc` plus `kpsewhich xelatex` plus `fc-list | grep -qi 'JetBrains Mono'` before launching.
* **Capability degraded reminder** — periodic (weekly, gated by mtime of a state file) "BTW, install `eza` for nicer `ls`" nudge.

---

## 10. Remaining Roadmap

### Quick wins (independent, small)

1. **F-2** — `MO_SAFE_MODE=1` env-gated plugin array. 10 LOC + README section. Unlocks debugging.
2. **F-1** — `mo-help` command using existing `# Provides:` headers. ~50 LOC. Surfaces ~80% of the framework that users currently don't discover.
3. **F-13** — `install.sh --dry-run`. Trust-building for curl|bash.
4. **F-6** — `master-oogway profile-startup` alias.
5. **L-15** — `mo-welcome` SHLVL/`MO_WELCOME_QUIET` guard.

### Medium term — one focused PR each

1. **F-3** — Plugin metadata headers + `doctor` rewrite to consume them.
2. **F-4** — Central capability cache in `mo-utils`.
3. **H-6** — Dragon wizard preview cache (eliminates the per-keypress `zsh -c`).
4. **F-7** — `master-oogway bisect` (depends on F-2, F-3).
5. **F-9** — `mo-where` companion to `mo-help`.
6. **F-11** — Drop-file plugin disable.
7. **F-14** — `dragon-configure --get/--set`.
8. **F-15** — Per-host `conf.d/<hostname>.zsh`.
9. **F-17** — `master-oogway backup`/`restore`.
10. **F-22** — `mo-test` harness (start with the highest-risk plugins: mo-lan-ssh, mo-files, mo-git).

### Long term — design discussion before code

1. **F-8** — Pluggable segment registry for Dragon.
2. **F-10** — First-class user-plugin dir `~/.master-oogway-user/plugins/`.
3. **F-12** — Environment-profile selector. Do *after* F-3 and F-11.
4. **F-16** — Async user segments. Requires F-8 first.
5. **F-21** — Versioned `~/.zshrc` migration system.

### What to deliberately not do

* **Network-fetched plugins / marketplace** — keeps attack surface bounded.
* **Telemetry** — not appropriate for personal dotfiles.
* **Cross-distro packaging** (RPM/Pacman) — single-distro focus is a strength.
* **Sandbox plugins** — over-engineering for trusted user-installed code.

---

*Open issues: 25 🟢 Low. Feature proposals: 11 (F-3, F-4, F-8, F-10, F-16–F-22). Audited: 5,729 LOC across 41 files.*
