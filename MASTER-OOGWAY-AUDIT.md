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
3. **Override/additive plugin distinction** — documented in CONTRIBUTING, enforced by load order. Every additive plugin uses `_mo_require` consistently; every override plugin ships an `r*` escape-hatch alias.
4. **Defensive shell discipline** — zip-slip protection in `extract`, NUL-delimited pipelines in `fcd`/`fp`, branch-injection filtering in `fbranch`, locale probe in 1 fork instead of 44, `lsof`-port validated before use, marker-protected sshd_config edits with `sshd -t` pre-validate.
5. **Documentation tells the truth** — README accurately describes installed surface; CONTRIBUTING enumerates the five touch-points needed when adding a theme variable; `# Provides:` lines on every plugin.

### Main risks (the report develops each)
1. **`_mo_require` is a single point of failure** — every additive plugin depends on `mo-utils` being loaded first; nothing enforces this. Removing `mo-utils` cascades to ~11 plugins all crashing on call.
2. **No safe-mode / minimal-mode** — when a plugin or `custom-zsh/*.zsh` drop-in breaks the shell, the user has no `zsh -i --safe` equivalent that still loads dragon. Only escape is `zsh -f`.
3. **No in-shell discovery surface** — the `# Provides:` headers are a great convention but not surfaced at runtime. Users learn 20% of the framework's commands.
4. **`mo-lan-ssh` ssh wrapper probes synchronously on every call** — adds ~200ms per `ssh <lan-host>` with no cache of "already-set-up" hosts.
5. **`MO-LAN-PLAN.md` is stale** — committed but never deleted. Forward-looking plan for a feature that already shipped, with phase-3 subcommands (`trust`/`forget`/`exclude`) referenced in plan but **not implemented**. Active source-of-truth confusion.
6. **No central capability cache** — `command -v bat`/`fzf`/`fd` is probed at ~8-13 sites independently. Wasted forks at shell start; no place to ask "what does the framework think is installed?".
7. **Dragon wizard latency** — `_dragon_render_preview` spawns a fresh `zsh -c` per preview redraw. 40+ subshells per guided wizard.
8. **`DRAGON__*` exports leak across SSH/tmux** — `dragon-configure --preset` re-exports values, after which `conf.zsh` edits become silent no-ops in pre-existing tmux panes.

### Issue distribution

| Severity | Count |
|---|---|
| 🔴 Critical | 0 |
| 🟠 High | 8 |
| 🟡 Medium | 32 |
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
│           4 submodules; runs `_init_plugins` (dev mode only)  │
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
- Dependencies: declared by `_mo_require <tool> <caller> [apt-pkg]` calls in function bodies (not in headers).
- Ordering: overrides first, `mo-utils` second, others next, syntax-highlighting last. Enforced by humans editing `~/.zshrc`.

**Theme contract:**
- Variables declared in `schema.zsh` via `populate_defaults`/`populate_types`/`populate_hints`/`populate_groups`.
- Five touch-points required per new var (documented in CONTRIBUTING.md:148-219): defaults, type, hint, group, segment renderer.
- `_dragon_vars_hash` (md5 of all `DRAGON__*` identifiers found by grep) gates the notifier — but it's grep-based and over-matches comments/docs.

### Module breakdown (LOC by area)

| Area | LOC | Files |
|---|---:|---|
| install.sh | 612 | 1 |
| docs (README, CONTRIBUTING, MO-LAN-PLAN) | 1060 | 3 |
| zshrc/zshenv/gitconfig/editorconfig | 335 | 4 |
| Dragon theme | 1907 | 12 |
| mo-* plugins (21 files) | 1815 | 22 |
| **Total in scope** | **5729** | **42** |
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
| **Wizard can't reach `[10]` items** — `_dragon_edit_var` enum input is hard-coded `[1-9]` (`configure.zsh:326-329`), so `GIT_DIRTY_UNDERLINE` (var #10 in `git_clean_dirty` group) is unreachable. Must hand-edit `conf.zsh`. | Silent inability to wizard-customize. |
| **No "preview-before-save" for theme presets** — `--preset` writes conf and asks for reload. | Slow iteration. |
| **No `dragon-configure --get/--set` non-interactive mode** for scripted/Ansible-driven config. | Forces the wizard for one-line tweaks. |

### Theme system review

* **Schema-driven** is the right choice and well-executed. Pure-data file (`schema.zsh`), no side effects, clean populator functions.
* **Hash-based change detection** is clever but `grep -Eroh 'DRAGON__[A-Z_]+'` over-matches: comments, docs, the cleanup vars-listing block in `_dragon_cleanup` (`configure.zsh:933-936`), and preset definitions. Cosmetic edits trigger false-positive notifier.
* **Configurator latency** (`configure.zsh:226-252`): every preview redraw runs `zsh -c` + sources `dragon.zsh`. On guided wizard with 20 groups × 2-4 mode-variants × keypress redraws, easily 40+ subshells. Perceptibly laggy on slower hardware.
* **Exports leak** (`dragon.zsh:7-14`, `aliases.zsh:3-9`): `set_if_unset` exports all defaults. Once `dragon-configure --preset X` runs, those values are in the env permanently. New tmux panes inherit them, and `conf.zsh` edits silently no-op because `set_if_unset` sees the env var already set.

### Documentation drift

* `README.md` is largely accurate (recent commit `5b5896b` added the "When the override gets in the way" section — a real UX improvement).
* **`MO-LAN-PLAN.md` is stale and harmful**: written as a forward-looking plan, but the plugin is fully implemented and wired in. Phase-3 subcommands listed in the plan (`trust`/`forget`/`exclude`) are referenced in user-facing help nowhere but **are not implemented** — anyone reading the plan and trying `mo-lan-ssh forget gandalf` gets "unknown command." Three sources of truth (plan, README, code) for one feature.
* **`zshenv.master-oogway`** ships with EDITOR/VISUAL exports; uninstaller asymmetrically refuses to remove it (`install.sh:341-346`) even when the file is byte-identical to the template.

---

## 4. Robustness & Failure Handling

### Optional dependency handling (the most important section)

| Tool | Plugins | Handling | Verdict |
|---|---|---|---|
| `fzf` | mo-network, mo-env, mo-search, mo-process, mo-navigation, mo-files, mo-git | soft via `_mo_require` | ✅ Consistent |
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

**`_mo_require` cliff:** if a user removes `mo-utils` from the plugins array (entirely reasonable — they may think "it's just utils"), every additive plugin crashes with `_mo_require: command not found` on first use. Comments declare the dependency but nothing enforces it.

### Fallback mechanisms — by area

| Area | Has fallback? | Notes |
|---|---|---|
| Override aliases (`cat`/`ls`/`vim`/`cp`/`mv`/`reboot`) | ✅ | `r*` escape-hatch aliases (`rcat`, `rls`, …) |
| `bat`/`batcat` Ubuntu rename | ✅ | Detected globally |
| Missing fzf in fuzzy commands | ✅ | `_mo_require` exits with clear apt hint |
| Missing `gitstatus` daemon for prompt | ✅ | `parts/git.zsh` guards on `gitstatus_query` presence |
| Missing 256-color terminal | ❌ | `__get_xterm_color_by_name` only handles unknown names, not unsupported terminals |
| Missing Nerd Font glyphs | ❌ | `USE_NERD_FONT` defaults via SSH-presence only; no terminal probe |
| Missing `python3` for `serve` | ✅ | `_mo_require` |
| Missing `xelatex` for `md2pdf` | ❌ | Cryptic pandoc error |
| Network failure during install clone | 🟡 | Partial clone leaves cryptic state; `git pull --ff-only` on rerun may mask broken submodules |
| sshd_config edit fails validation | ✅ | Auto-reverts via `sshd -t`, recent fix |

### Error handling review

* **Installer:** `set -Eeuo pipefail`, `_on_error` trap with `BASH_COMMAND` reporting, `die` helper consistent throughout. **Issue:** `die` called from `$(…)` exits only the subshell — no current bug but a latent trap for future contributors.
* **Plugins:** `2>/dev/null` swallows errors broadly. `mo-lan-ssh/_mo_lan_refresh_async` silently discards all discovery errors — users with `dig` missing on a no-nmap system see "no cache yet" with no clue why.
* **Configurator:** `_dragon_read_key` traps `EXIT INT TERM` and clears them after each keypress, **clobbering any pre-existing user trap** for the rest of the session (`configure.zsh:181-189`).

### Edge cases & failure scenarios

* **Re-run after partial install:** Install dir exists but submodules are broken → `git pull --ff-only` succeeds → submodules remain broken silently. `_init_plugins` only runs in dev mode.
* **User deletes the `# master-oogway:managed` marker line:** Next install **clobbers user edits** without backup re-running (the `.pre-master-oogway` backup is only created on first install).
* **User has tab-indented `Host *` block in `~/.ssh/config`:** `SendEnv` injection's `sed` regex uses 4-space prefix; lands with inconsistent indentation in user's file.
* **User has multiple `Host *` stanzas:** `sed` inserts after the *first* match — possibly the wrong section.
* **Ctrl+C during `dragon-configure` preview:** `_DRAGON_*` exports leak to parent shell, silently overriding `conf.zsh` for the rest of the session.
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

### Extensibility design — current state

**The contract is implicit.** Any `omz-custom/plugins/<name>/<name>.plugin.zsh` is auto-loaded if listed in `~/.zshrc`'s `plugins=(...)` array. Conventions:
* `# Provides: <commands>` header (uniformly applied).
* `_mo_<plugin>_<helper>` for internal functions.
* `-h/--help` on every user-visible function.
* `r*` escape-hatch aliases for override plugins.

**No mechanical contract.** No machine-readable metadata header → `master-oogway doctor` has to hardcode the tool list (`mo-cli.plugin.zsh:40-56`) rather than computing it from plugin metadata. No version, no declared deps array, no `enable/disable` registration point.

### Plugin lifecycle

* **Load:** oh-my-zsh sources `<name>.plugin.zsh` once. No `init` hook beyond top-level code.
* **Run:** functions/aliases defined at load are dispatched on user invocation.
* **Unload:** No mechanism. To "disable" a plugin, the user edits `~/.zshrc`.
* **Reload:** `soursh` re-sources `~/.zshrc`; idempotency is each plugin's responsibility.

### Safety of plugins

Each plugin runs in the user's shell with full privilege. There is no sandboxing — appropriate, since users install this knowingly. But:
* **Aliases override scripting commands** (`cat`, `ls`, `cp`, `vim`). zsh doesn't expand aliases in non-interactive shells unless `expand_aliases` is set, but `mo-safety-override` uses functions (`cp`, `mv`, etc.) — and **functions are inherited by `eval`/`zsh -c`**. A user who runs `zsh -c "cp a b"` from a script gets the interactive confirmation prompt. Functions exported via `typeset -fx` would be even worse; the plugin uses bare functions, which is the right choice.
* **mo-lan-ssh is the only plugin that mutates `~/.ssh/config`** — well-isolated to `~/.ssh/config.d/lan-hosts` with an `Include` directive in the main config.

### Missing abstraction layers

1. **No capability cache** — every plugin re-probes `command -v X` independently.
2. **No plugin metadata header** — `doctor` can't compute the dependency report from plugins.
3. **No drop-file disable mechanism** — `~/.config/master-oogway/disabled/<name>` would be a 5-LOC win.
4. **No user-plugin surface** — `custom-zsh/*.zsh` are loose drop-ins, not first-class plugins.
5. **No segment registry in dragon** — adding a prompt segment requires forking two files.
6. **No "after-load" hook** for plugins to register their doctor checks centrally.

---

## 6. Issues Found (Detailed List)

### 🟠 High-severity issues

#### H-1. ✅ RESOLVED — `_mo_require` dependency eliminated

* **Resolved:** `mo-utils` plugin deleted. All 15 `_mo_require` call sites replaced with inline `command -v` checks. Each plugin is now fully self-contained with zero cross-plugin dependencies.

#### H-2. `apt_install zsh` does not switch the user's login shell

* **Severity:** 🟠 High (UX)
* **Location:** `install.sh:358`
* **Problem:** Installer ensures `zsh` is on PATH but never runs `chsh -s "$(command -v zsh)"`. README doesn't mention it either (`README.md:26-44`). OMZ's own installer prompts for it, but anything that goes wrong there leaves master-oogway looking broken.
* **Impact:** First-time user on fresh Ubuntu finishes install, opens a new terminal, sees no change, and concludes the install failed.
* **Recommendation:** After OMZ check, detect `$SHELL` (or `getent passwd "$USER" | cut -d: -f7`). If not zsh, prompt to `chsh -s "$(command -v zsh)"` with confirmation, or append it to the closing `todo_item` list.
* **Suggested fix:** ~15 LOC + one README line.

#### H-3. Plugin submodule self-healing only runs in dev mode

* **Severity:** 🟠 High
* **Location:** `install.sh:197-214` (`_init_plugins` lives inside the dev-mode branch)
* **Problem:** In curl-pipe / update mode, the only submodule init is `git -C … submodule update --init --recursive`. If a submodule path exists but is not a git checkout (e.g., user accidentally deleted its `.git`), production-mode install never recovers — only dev mode `rm -rf`s and re-clones.
* **Impact:** Update mode can leave broken plugin dirs without recovery, surfacing as runtime errors when zsh tries to source the plugin.
* **Recommendation:** Lift `_init_plugins` out of the dev-mode `if` and call unconditionally after both clone/pull branches.

#### H-4. `mo-search/frg` preview opens wrong file when ripgrep result path contains `:`

* **Severity:** 🟠 High
* **Location:** `omz-custom/plugins/mo-search/mo-search.plugin.zsh:54`
* **Problem:** fzf preview uses `--delimiter ':'` and `{1}`, so `weird:file.txt:42:matched line` parses as file=`weird`, line=`file.txt`.
* **Impact:** Wrong-file preview and wrong-file open on ripgrep results from filenames containing `:`. Real on Java/CI repos with `:`-named generated paths.
* **Recommendation:** Use ripgrep `--null` and a NUL field delimiter, or pre-filter `:` filenames.

#### H-5. `dragon-configure --preset` leaks `DRAGON__*` exports to parent shell

* **Severity:** 🟠 High
* **Location:** `omz-custom/themes/dragon/dragon.zsh:7-14`; `configure.zsh:920-922`
* **Problem:** `set_if_unset` exports every default. `dragon-configure` re-exports chosen values to override `set_if_unset`. After a `--preset` run, the env is permanently polluted; subsequent `soursh` in **the same** terminal — or any new tmux pane that inherited env from this one — silently uses the previous values, **silently ignoring** `conf.zsh` edits.
* **Impact:** Subtle "why isn't my conf change taking effect?" bug. Wasted hours.
* **Recommendation:** Use `typeset -g` not `export` for defaults. Forward via SSH explicitly through `conf.zsh`'s own `DRAGON__FORWARDED` mechanism (already designed for this).

#### H-6. `_dragon_render_preview` spawns fresh `zsh -c` per preview redraw

* **Severity:** 🟠 High (UX)
* **Location:** `omz-custom/themes/dragon/configure.zsh:226-252`
* **Problem:** Every preview redraw sources `dragon.zsh` in a new `zsh -c`. With `--ssh` / `--fail` / `--transient` mode variants × per-keypress redraw × 20 groups, easily 40+ subshells per wizard run.
* **Impact:** Wizard feels sluggish (perceptibly so on slow machines, containers, SSH). Bad first impression.
* **Recommendation:** Cache rendered previews keyed by `(group, mode, vars-hash)`; re-render only on actual value change.

#### H-7. `mo-lan-ssh` ssh wrapper probes synchronously on every LAN ssh call

* **Severity:** 🟠 High
* **Location:** `omz-custom/plugins/mo-lan-ssh/mo-lan-ssh.plugin.zsh:243-247`
* **Problem:** For every LAN ssh invocation (not just first), the wrapper does a BatchMode probe (default 2s timeout) before the actual ssh. Doubles connection setup time.
* **Impact:** Interactive: ~200ms extra per `ssh <lan-host>`. Scripts looping `ssh` over many hosts: noticeable. Compounds with H-8 below.
* **Recommendation:** Cache "host is set up OK" in `~/.config/master-oogway/lan-hosts.keys-ok` with timestamp. Skip probe if `now - last-ok < 30 min` and host-key hash unchanged.

#### H-8. `mo-lan-ssh` ssh wrapper unconditionally installed, hard to bypass

* **Severity:** 🟠 High (UX)
* **Location:** `omz-custom/plugins/mo-lan-ssh/mo-lan-ssh.plugin.zsh:169-173`
* **Problem:** `ssh()` function defined whenever `MO_LAN_AUTO_TRUST=true` (default) and any LAN host exists. `MO_LAN_AUTO_TRUST=false` only disables key-copy; the wrapper still wraps. Bypass requires `command ssh` (since `\ssh` only bypasses aliases, not functions) — not documented.
* **Impact:** Debugging ssh inadvertently exercises the wrapper. The `MO_LAN_PLAN.md` is even staler now that the plugin is in production with no kill-switch.
* **Recommendation:** Add `MO_LAN_SSH_DISABLED=1` short-circuit at top of plugin. Add `MO_LAN_SKIP_WRAPPER=1` one-shot bypass. Document `command ssh` in `mo-lan-ssh help`.

### 🟡 Medium-severity issues

#### M-1. Top-level `local_dir=` assignment outside any function
* **Location:** `install.sh:179`
* **Problem:** `local_dir="$(_script_dir)"` is parsed as a plain variable assignment (not `local`, which would error at file scope). Pollutes the global namespace and misleads readers.
* **Recommendation:** Rename `_local_dir` or wrap the dev-mode block in a function with real `local`.

#### M-2. README's "Installation" section omits the `chsh` step
* **Location:** `README.md:26-44`
* **Problem:** Same gap as H-2 on the docs side.
* **Recommendation:** Add one line: "If `zsh` isn't already your default shell, run `chsh -s $(command -v zsh)` and log out/in."

#### M-3. Partial-clone recovery is cryptic
* **Location:** `install.sh:154-163`
* **Problem:** Network failure mid-clone leaves `~/.master-oogway/` in partial state. Re-run takes update path (`git pull --ff-only`); if submodule update fails again, user is stuck with no error pointing them to `rm -rf ~/.master-oogway`.
* **Recommendation:** On `submodule update` failure, `die` with the explicit recovery command.

#### M-4. `~/.zshrc` clobber on missing marker
* **Location:** `install.sh:417`, `zshrc.master-oogway:1-5`
* **Problem:** If user deletes the marker line, next install overwrites the file without re-running the backup logic (`.pre-master-oogway` already exists from first install).
* **Recommendation:** If destination exists, lacks marker, AND contains `master-oogway`/`dragon` references, back up to timestamped `${ZSHRC}.replaced.$(date +%Y%m%d_%H%M%S)`.

#### M-5. `SendEnv DRAGON__*` injected into wrong/multiple `Host *` blocks
* **Location:** `install.sh:522`
* **Problem:** `sed` inserts after the *first* `^Host \*$` match; user with multiple stanzas (e.g. `Host *.work` then `Host *`) gets it in the wrong section. Tab-indented configs get inconsistent spacing.
* **Recommendation:** Append a dedicated stanza at end-of-file with a comment marker so uninstall can find/remove it.

#### M-6. `/etc/ssh/sshd_config` prompt fires on laptops without sshd
* **Location:** `install.sh:535-562`
* **Problem:** Every install asks every user; no "remember my no" mechanism.
* **Recommendation:** Skip prompt if `systemctl is-active --quiet ssh` returns false. Persist user's "no" in `STATE_FILE`.

#### M-7. Unverified clones; no GPG-signed tag verification
* **Location:** `install.sh:161`, `README.md:37`
* **Problem:** curl|bash one-liner trusts whatever GitHub serves. Repo or account compromise → every new install affected.
* **Recommendation:** Document `git show --show-signature HEAD` for paranoid users. Long-term: sign release tags, install.sh verifies against pinned fingerprint.

#### M-8. `bat`/`fdfind` etc. checked uniformly but no central capability cache
* **Location:** Multiple plugins + install.sh + mo-cli doctor
* **Problem:** `command -v bat` runs at ~13 sites independently. Fork overhead at shell start; no single source of truth.
* **Recommendation:** `mo-utils` writes `~/.cache/master-oogway/capabilities.zsh` on first load (invalidated when `$PATH` mtime changes). Plugins consult `$MO_CAPS[bat]`; `doctor` reads from the same cache.

#### M-9. `mo-utils` removal not enforced (see also H-1)
* **Location:** `omz-custom/plugins/mo-utils/mo-utils.plugin.zsh:2`
* **Problem:** Documentation says "must be loaded first" but no enforcement.
* **Recommendation:** Same fix as H-1 (fallback inline definition).

#### M-10. No granular plugin enable/disable beyond editing `~/.zshrc`
* **Location:** `zshrc.master-oogway:148-183`
* **Problem:** Editing the marker-protected file triggers drift warning forever after.
* **Recommendation:** Each plugin checks `[[ -e $HOME/.config/master-oogway/disabled/${0:t:r} ]] && return` as first line. 5 LOC × 21 plugins, no `~/.zshrc` edits needed for per-plugin disable.

#### M-11. Alias collisions with single-letter commands
* **Location:** mo-search (`f`), mo-eza-override (`l`), mo-shell-tools (`h`), mo-build (`m`), mo-git (`g*`)
* **Problem:** Short aliases are convenient but conflict with user muscle memory and other dotfile ecosystems. Not documented as a single inventory.
* **Recommendation:** Consolidate alias inventory in README. Add `MO_DISABLE_SHORT_ALIASES=true` honored by override plugins.

#### M-12. `mo-safety-override/reboot` drops arguments
* **Location:** `omz-custom/plugins/mo-safety-override/mo-safety-override.plugin.zsh:14-17`
* **Problem:** `_confirm_reboot` calls `command reboot` with no args. `reboot -f`, `reboot --halt` are silently dropped.
* **Recommendation:** Convert alias to a function that forwards `"$@"` after confirmation.

#### M-13. `mo-search/grep` clobbers user's pre-defined `grep` alias
* **Location:** `omz-custom/plugins/mo-search/mo-search.plugin.zsh:5-6`
* **Problem:** `unalias grep 2>/dev/null` runs before the function defines `grep`. A user's `custom-pre-zsh/*.zsh` alias (loaded before plugins) is silently destroyed.
* **Recommendation:** Detect existing `grep` alias and warn; or document that user aliases should go in `custom-zsh/` (post-plugins).

#### M-14. `mo-process/port` `awk` rewrite mangles lsof output
* **Location:** `omz-custom/plugins/mo-process/mo-process.plugin.zsh:41`
* **Problem:** lsof's `NAME` column is variable-width and can contain spaces; `printf "%s %s %s %s %s" $1 $2 $3 $5 $9` misaligns for entries like `IPv6` or `(LISTEN)`.
* **Recommendation:** Pipe lsof output through `column -t`; skip awk reformat.

#### M-15. `mo-lan-ssh probe_host` requires bash
* **Location:** `omz-custom/plugins/mo-lan-ssh/_mo_lan_discover.zsh:134`
* **Problem:** `bash -c "</dev/tcp/..."` hardcoded. Fine on Ubuntu/Pi; risky if scope expands.
* **Recommendation:** Document, or use a zsh-native TCP probe.

#### M-16. `mo-lan-ssh` discovery silently swallows all errors
* **Location:** `omz-custom/plugins/mo-lan-ssh/mo-lan-ssh.plugin.zsh:60-66`
* **Problem:** `2>/dev/null` everywhere; if `dig` is missing on a no-nmap system, the user sees "no cache yet" forever with no clue why.
* **Recommendation:** Redirect stderr to `~/.config/master-oogway/lan-hosts.lastrun.err`. `mo-lan-ssh status` displays it when cache is empty.

#### M-17. `mo-lan-ssh` deferred phase-3 commands referenced in `MO-LAN-PLAN.md` but unimplemented
* **Location:** `MO-LAN-PLAN.md:351`, `mo-lan-ssh.plugin.zsh:374-438`
* **Problem:** Plan lists `trust`, `forget`, `exclude`; dispatcher only handles `list/refresh/status/setup/help`. User trying `mo-lan-ssh forget gandalf` gets "unknown command."
* **Recommendation:** Implement at least `forget` (removes from cache + `ssh-keygen -R` + ssh-config rewrite). Common need after re-imaging a Pi.

#### M-18. `MO-LAN-PLAN.md` is stale and harmful
* **Location:** `MO-LAN-PLAN.md` (whole file)
* **Problem:** Reads as a forward plan but the plugin is fully implemented and wired in. Three sources of truth (plan, README, code). New contributor reading the plan would start implementing what's already shipped.
* **Recommendation:** Move to `docs/mo-lan-ssh-design.md` as a historical design doc, or delete outright. README is canonical.

#### M-19. `apt-get install … >/dev/null 2>&1` swallows real failures
* **Location:** `install.sh:66`
* **Problem:** All apt output muted; on failure the user sees only "Failed to install '${pkg}'" with no apt error.
* **Recommendation:** On failure, re-run `sudo apt-get install -y "$pkg"` without redirect, or capture stderr to a tempfile and `cat` on failure.

#### M-20. `__set_ssh_connection_count_content` shells out to `who(1)` every prompt
* **Location:** `omz-custom/themes/dragon/parts/segments_right.zsh:90-115`
* **Problem:** `${(f)$(who)}` runs per precmd, even when no one is connected. Default is `ENABLE_SSH_CONNECTION_COUNT=true`. 10-30ms per prompt on busy servers.
* **Recommendation:** TTL cache (5s); or read utmp once per minute via SECONDS-gated check.

#### M-21. `__calc_prompt_length` ANSI strip is fragile
* **Location:** `omz-custom/themes/dragon/parts/prompt.zsh:5,9,12`
* **Problem:** Glob `${...//$'\e['[0-9;]#m/}` strips CSI SGR only (no OSC/DCS); `*1.1` fudge for invisibles guesses wrong on Nerd Font / emoji widths.
* **Recommendation:** Use zsh's `%{...%}` non-printing-zone removal first; estimate width via prompt-expanded buffer.

#### M-22. `__add_separator_between_left_segments` type-fragile color compare
* **Location:** `omz-custom/themes/dragon/parts/separators.zsh:81-97`
* **Problem:** Compares user color strings raw — `"navy"` vs `"012"` for the same effective color get treated as different, producing a spurious powerline arrow.
* **Recommendation:** Normalize both sides through `__get_xterm_color_by_name` before equality check.

#### M-23. `_dragon_render_preview` env-leak on Ctrl+C
* **Location:** `omz-custom/themes/dragon/configure.zsh:201-260`
* **Problem:** Exports `_DRAGON_CURRENT` vars into parent shell; cleanup runs only on normal exit. Ctrl+C during the preview's `zsh -c` leaves exports in the parent.
* **Recommendation:** Spawn preview as a subshell `( ... )` so cleanup is automatic.

#### M-24. `__update_prompt` renders with stale `VCS_STATUS_*` after `cd`
* **Location:** `omz-custom/themes/dragon/parts/transient.zsh:87-91`
* **Problem:** Sync render uses previous dir's gitstatus; async callback re-renders. Brief flicker showing the wrong repo's branch after `cd` between repos.
* **Recommendation:** Clear `VCS_STATUS_*` on `chpwd` before sync render, or skip sync render on chpwd.

#### M-25. `_dragon_vars_hash` over-matches comments/docs
* **Location:** `omz-custom/themes/dragon/configure.zsh:22-29`, `notifier.zsh:34`
* **Problem:** `grep -Eroh 'DRAGON__[A-Z_]+'` matches identifiers in comments, in `_dragon_cleanup`'s var-listing, in preset blocks. Cosmetic edits trigger false "new options" notifier.
* **Recommendation:** Hash only `_DRAGON_DEFAULTS` keys (source `schema.zsh`, serialize `${(@k)_DRAGON_DEFAULTS}`).

#### M-26. `_dragon_read_key` clobbers user's `trap`s
* **Location:** `omz-custom/themes/dragon/configure.zsh:181-189`
* **Problem:** `trap '...' EXIT INT TERM` then `trap - EXIT INT TERM` overwrites and then removes user's session-cleanup traps for the rest of the session.
* **Recommendation:** Save existing trap with `trap -p EXIT` and restore. Better: use `always { ... }` blocks.

#### M-27. Wizard enum reader caps at `[1-9]`, unreachable item #10
* **Location:** `omz-custom/themes/dragon/configure.zsh:326-329`, `456-461`
* **Problem:** Hard-coded single-digit pattern. `git_clean_dirty` group has 10 vars; var #10 (`GIT_DIRTY_UNDERLINE`) is unreachable from the wizard.
* **Recommendation:** Multi-digit input with Enter to confirm, or two-char read with 50ms timeout for the second digit.

#### M-28. Asymmetric SSH-override defaults (username vs hostname)
* **Location:** `omz-custom/themes/dragon/schema.zsh:21-25, 34-38`
* **Problem:** `ENABLE_USERNAME_COLORING_VIA_SSH=false` with empty colors vs `ENABLE_HOSTNAME_COLORING_VIA_SSH=true` with `maroon`. User enabling the toggle gets unreadable empty-color segment.
* **Recommendation:** Symmetric defaults; seed colors in `_dragon_edit_var` when toggling on.

#### M-29. Code duplication in `separators.zsh`
* **Location:** `omz-custom/themes/dragon/parts/separators.zsh:11-69`
* **Problem:** Four near-identical 8-LOC functions differing only by source/dest vars. The `__dragon_copy_defaults` / `__dragon_finalize` consolidation was already done for segments — pattern not extended here.
* **Recommendation:** Add `__dragon_render_separator <src_var> <dst_var>` helper. -40 LOC.

#### M-30. `mo-welcome` `os_name` empty on unreadable `/etc/os-release`
* **Location:** `omz-custom/plugins/mo-welcome/mo-welcome.plugin.zsh:13`
* **Problem:** Silent empty value rather than `uname -s` fallback.
* **Recommendation:** `os_name="${PRETTY_NAME:-${NAME:-$(uname -s)}}"`.

#### M-31. No in-shell command discovery surface
* **Location:** No single source; `# Provides:` headers unused at runtime
* **Problem:** User who types `mo-<TAB>` gets nothing useful; must `cat` plugin files or re-read README to remember aliases.
* **Recommendation:** `mo-help` command (~50 LOC) that parses `# Provides:` lines and prints a colorized table.

#### M-32. No safe-mode / minimal-mode for triage
* **Location:** `zshrc.master-oogway` (plugin array assignment)
* **Problem:** When a `custom-zsh/*.zsh` drop-in breaks the shell, recovery requires editing `~/.zshrc`. Only fallback is `zsh -f`, which loses dragon too.
* **Recommendation:** `[[ -z "$MO_SAFE_MODE" ]] && plugins=(...) || plugins=(zsh-autosuggestions zsh-syntax-highlighting)`. ~10 LOC + doc.

### 🟢 Low-severity issues (condensed)

| # | Location | Issue |
|---|---|---|
| L-1 | `install.sh:163` | `exec bash` drops `"$@"` and hardcodes `bash` |
| L-2 | `install.sh:74-86` | `copy_file` doesn't preserve perms; asymmetric with `bak`'s `cp -a` |
| L-3 | `install.sh:404-413` | `_check_zshrc_drift` warning becomes noise after first user edit |
| L-4 | `install.sh:341-346` | Uninstall refuses to remove `~/.zshenv` even if byte-identical to template |
| L-5 | `install.sh:35,45` | `die` from inside `$(…)` exits only subshell — latent footgun |
| L-6 | `.gitmodules` / `install.sh:157` | No surfaced submodule SHA dashboard or upstream-drift report |
| L-7 | `CONTRIBUTING.md:96-99` | `zsh -n` validation listed for `configure.zsh` but the wizard's output isn't auto-validated (it is — `configure.zsh:650`; document this) |
| L-8 | `omz-custom/themes/dragon/parts/segments_right.zsh:140-161` | `__get_exit_status_content` uses double `$(...)` instead of the global-variable pattern used elsewhere |
| L-9 | `omz-custom/themes/dragon/parts/transient.zsh:65-70` | `zle reset-prompt 2>/dev/null` outside ZLE — swallows error; should be `zle && zle reset-prompt` |
| L-10 | `omz-custom/themes/dragon/configure.zsh:186` | `read -rk1` — `-r` is a no-op in zsh `read -k` |
| L-11 | `omz-custom/themes/dragon/configure.zsh:34-39` | `_dragon_read_state` won't survive values containing `=` (no current bug) |
| L-12 | `omz-custom/themes/dragon/configure.zsh:739` | `dragon-configure` doesn't warn when `$ZSH_THEME != dragon` |
| L-13 | `omz-custom/themes/dragon/notifier.zsh:13-52` | `find . -name '*.zsh' -printf` walks tree on every shell start; could stat one sentinel |
| L-14 | `omz-custom/themes/dragon/configure.zsh:662-675` | `_dragon_filter_changed_groups` confuses "differs from default" with "user-changed" — misleading after `--preset` switch |
| L-15 | `omz-custom/plugins/mo-welcome/mo-welcome.plugin.zsh` | No `MO_WELCOME_QUIET` opt-out; multiple-pane spam |
| L-16 | `omz-custom/plugins/mo-auto-ls` | Skips `/mnt/*` even for fast local mounts |
| L-17 | `omz-custom/plugins/mo-safety-override:16` | `read -r ans` has no timeout |
| L-18 | `omz-custom/plugins/mo-bat-override:14,18` | `pcat`/`pless` naming is non-obvious; document |
| L-19 | `omz-custom/plugins/mo-eza-override:10` | `l`/`la` column-set differs between eza and ls fallback — document |
| L-20 | `omz-custom/plugins/mo-network` | `Include` directives in `~/.ssh/config` not recursively resolved (comment acknowledges) |
| L-21 | `omz-custom/plugins/mo-network` | `natip` has no `-6` IPv6 flag |
| L-22 | `omz-custom/plugins/mo-files:63,76` | `extract` accepts symlinks; `gunzip` modifies the symlink target |
| L-23 | `omz-custom/plugins/mo-files:95` | `bak ts=$(date +%N)` computed once outside loop — collisions possible |
| L-24 | `omz-custom/plugins/mo-process:30` | `port N` for both-TCP-UDP shows UDP without state filter |
| L-25 | `omz-custom/plugins/mo-navigation:25-28` | `up N` past root silently lands at `/` |
| L-26 | `omz-custom/plugins/mo-cli:24-39` | `_mo_check` defined inside `_mo_doctor` as a global; leaks on Ctrl+C between def and `unset -f` |
| L-27 | `omz-custom/plugins/mo-cli:72-74` | `master-oogway uninstall` no extra confirm (relies on `install.sh --uninstall`) |
| L-28 | `omz-custom/plugins/mo-dev:65` | `serve` symlink traversal enabled by default |
| L-29 | `omz-custom/plugins/mo-dev:97,103` | `md2pdf` doesn't pre-check pandoc/xelatex/JetBrains Mono |
| L-30 | `omz-custom/plugins/mo-git:32` | `gsum` lacks `-C` support |
| L-31 | `omz-custom/plugins/mo-git:60-63` | `fbranch` preview assumes `main`/`master` exists |
| L-32 | `omz-custom/plugins/mo-lan-ssh:251,267,292` | `command ssh` wrapper doesn't `exec` on no-op pass-through |
| L-33 | `omz-custom/plugins/mo-shell-tools:28` | `please` loses quoting via `$(fc -ln -1)`; doesn't detect existing `sudo` prefix |
| L-34 | `omz-custom/plugins/mo-colorize-override` | No `rip`/`rdiff` escape-hatch aliases for scripts |
| L-35 | `omz-custom/plugins/mo-process` | `psgrep` calls `pgrep` without `_mo_require` precheck |

---

## 7. Feature Proposals

### Ranked feature list

#### F-1. `mo-help` / `master-oogway commands` — in-shell discovery surface ⭐
* **Value:** UX (highest leverage; surfaces what already exists)
* **Problem solved:** Users leave shell to remember what plugins/aliases exist; `# Provides:` headers never reach the user.
* **Design:** Parse `# Provides:` lines and `^alias `/`^function ` declarations across `$ZSH_CUSTOM/plugins/mo-*/` on first invocation; cache. Colored two-column table (command → description). Optional substring/plugin filter.
* **Complexity:** S (~50 LOC) — **Risk:** Very low

#### F-2. Safe-mode bootstrapping (`MO_SAFE_MODE=1`) ⭐
* **Value:** Robustness
* **Problem solved:** Broken plugin or drop-in → no recovery path beyond editing `~/.zshrc`.
* **Design:** Wrap plugin array + drop-in loops in `if [[ -z "$MO_SAFE_MODE" ]]`. Document `MO_SAFE_MODE=1 zsh` as the triage entry point.
* **Complexity:** S (~10 LOC + docs) — **Risk:** Very low

#### F-3. Inline fallback `_mo_require` + plugin metadata header ⭐
* **Value:** Robustness + extensibility
* **Problem solved:** H-1 (mo-utils-removal cliff) AND mechanical extensibility.
* **Design:** Three-line header per plugin (`# mo-plugin:`, `# mo-deps:`, `# mo-desc:`). Inline fallback `_mo_require` at top of each consumer plugin. `master-oogway doctor` parses headers to compute dep report dynamically; eliminates the hardcoded list at `mo-cli.plugin.zsh:40-56`.
* **Complexity:** M (~120 LOC) — **Risk:** Low

#### F-4. Central capability cache populated by `mo-utils`
* **Value:** Performance + dev-XP
* **Problem solved:** M-8 (`command -v bat` at 13 sites); enables F-7.
* **Design:** `mo-utils` writes `~/.cache/master-oogway/capabilities.zsh` on first load (invalidated by `$PATH` mtime). Plugins consult `$MO_CAPS[bat]`. `doctor` reads from same cache. `mo-recap` to force-refresh.
* **Complexity:** M (~120 LOC, careful invalidation) — **Risk:** Medium (stale cache mid-session — mitigate with explicit refresh alias)

#### F-5. `master-oogway dump` — effective config snapshot
* **Value:** Support / dev-XP
* **Problem solved:** No single command to capture "what does my install look like" for bug reports.
* **Design:** Markdown-friendly dump of: version, install path, `$ZSH_THEME`, active plugins, all `DRAGON__*`, all `MO_*`, `doctor` output, git rev. Tell users to attach this to issues. Sanitize `MO_LAN_DNS_SERVER` etc. by default.
* **Complexity:** S — **Risk:** Low

#### F-6. `master-oogway profile-startup` — built-in startup profiler
* **Value:** Performance + dev-XP
* **Problem solved:** No way to measure which plugin/section costs time.
* **Design:** Alias for `MO_ZPROF=1 zsh -ic exit` with `zmodload zsh/zprof` enabled when `$MO_ZPROF`.
* **Complexity:** S — **Risk:** Very low

#### F-7. `master-oogway bisect` — find the culprit plugin
* **Value:** Dev-XP for end users
* **Problem solved:** Shell suddenly slow/broken → which plugin?
* **Design:** Repeatedly spawn `MO_DISABLE=plugin1,plugin5 zsh -ic exit` measuring time/exit-code; halve the set each iteration. Depends on F-2.
* **Complexity:** M — **Risk:** Low

#### F-8. Pluggable segment registry for Dragon
* **Value:** Power-user extensibility
* **Problem solved:** Adding `kubectl_ctx` segment requires forking two files (segments_right.zsh + prompt.zsh).
* **Design:** `DRAGON_LEFT_SEGMENTS=(ssh_prefix username … directory)` and `DRAGON_RPROMPT_SEGMENTS=(…)` arrays. `dragon__set_lprompt` iterates calling `dragon__set_$segment`. Users define function + append. Recovers ~40 LOC from `prompt.zsh`.
* **Complexity:** M — **Risk:** Low

#### F-9. `mo-where` — find which plugin defined a command
* **Value:** Discoverability
* **Problem solved:** `whence -v gs` says "alias to git status" — not which plugin.
* **Design:** Grep `$ZSH_CUSTOM/plugins/mo-*/` for `^(alias|function) <name>`; print `mo-git:12: alias gs="git status"`.
* **Complexity:** S (~30 LOC) — **Risk:** Very low

#### F-10. `~/.master-oogway-user/plugins/` — first-class user plugin dir
* **Value:** Extensibility
* **Problem solved:** No place for non-trivial user extensions; `custom-zsh/*.zsh` are loose files without `# Provides:` integration.
* **Design:** Discovered by `~/.zshrc` and appended to `plugins=()`. Same convention. `mo-help` and `doctor` recognize them.
* **Complexity:** M — **Risk:** Low (additive, opt-in)

#### F-11. `master-oogway plugin enable/disable <name>`
* **Value:** UX
* **Problem solved:** M-10 (no per-plugin disable without `~/.zshrc` edit).
* **Design:** Drop-file `~/.config/master-oogway/disabled/<name>`; plugins check at top. CLI subcommand touches/removes file.
* **Complexity:** S — **Risk:** Very low

#### F-12. Environment-profile selector (`MO_PROFILE=desktop|server|pi|minimal`)
* **Value:** UX + maintenance hygiene
* **Problem solved:** Same plugin set on laptop and Pi server. `mo-apps` (flatpak) on Pi is noise; `mo-welcome` on server SSH is noise.
* **Design:** `~/.zshrc` switches `plugins=()` membership on `$MO_PROFILE` (default: `desktop`). Installer probes `$DISPLAY`, `/etc/rpi-issue`, `/.dockerenv` and writes a suggested value on first install.
* **Complexity:** M — **Risk:** Medium (re-templates `~/.zshrc`; needs migration)

#### F-13. `install.sh --dry-run`
* **Value:** Onboarding / trust
* **Problem solved:** curl|bash trust-building.
* **Design:** Print every file to create/modify/back-up, every sudo, every apt — without doing any. Trivial given existing helper-function shape.
* **Complexity:** S — **Risk:** Low

#### F-14. `dragon-configure --get VAR / --set VAR=VAL` non-interactive mode
* **Value:** Power-user (Ansible / dotfiles bootstrap)
* **Problem solved:** Scripting theme config currently requires sed against `conf.zsh`.
* **Design:** Two new flags that read/write `conf.zsh` (already structured for sed-friendliness).
* **Complexity:** S — **Risk:** Low

#### F-15. Per-host config layer (`~/.config/master-oogway/conf.d/<hostname>.zsh`)
* **Value:** UX for multi-host users
* **Problem solved:** No way to say "on `prod-db`, use red prompt."
* **Design:** Auto-source `conf.d/${HOST}.zsh` after `conf.zsh`. 3-line change to load path.
* **Complexity:** S — **Risk:** Very low

#### F-16. Async-evaluated user segments with TTL cache (Dragon)
* **Value:** Power-user extensibility (p10k parity)
* **Problem solved:** Users wanting kubectl context / AWS profile / nix shell either block the prompt or go back to p10k.
* **Design:** `dragon_register_async_segment <name> <cmd> <ttl>` runs `<cmd>` in background, caches in `typeset -gA`, refreshes when stale.
* **Complexity:** M — **Risk:** Medium

#### F-17. `master-oogway backup` / `restore`
* **Value:** Robustness
* **Problem solved:** No one-command save/restore of `~/.zshrc` + `conf.zsh` + drop-ins + gitconfig identity.
* **Design:** Tarball to `~/master-oogway-backup-YYYYMMDD.tar.gz`; restore reverses with confirmation.
* **Complexity:** S — **Risk:** Low (restore needs `confirm`)

#### F-18. Terminal capability probe (`mo-term-detect`)
* **Value:** UX (theme correctness out-of-box)
* **Problem solved:** `USE_NERD_FONT` defaults via SSH-presence only; wrong-font users see broken glyphs.
* **Design:** Once per install: print 3 glyph rows (powerline, nerd-font, plain), ask "all render correctly?", persist answer, default `USE_NERD_FONT` accordingly.
* **Complexity:** M — **Risk:** Medium (interactive prompt on shell open is intrusive; gate to first-shell-after-install only)

#### F-19. Submodule SHA dashboard + auto-update workflow
* **Value:** Robustness / supply-chain
* **Problem solved:** Four upstream plugins drift untracked; no surfaced view.
* **Design:** `master-oogway version --submodules` prints pinned SHA vs upstream HEAD per submodule. `master-oogway upgrade-plugins` interactive bumper.
* **Complexity:** M — **Risk:** Low

#### F-20. Hot-reload watcher (`mo-dev-watch`)
* **Value:** Dev-XP (author + contributors)
* **Problem solved:** Edit→test loop is "run `soursh` after every edit."
* **Design:** Dev-mode only (gated on `[[ -L ~/.master-oogway ]]`). `inotifywait` watches `$ZSH_CUSTOM`; on change, prints `soursh-recommended`. Advisory only, never auto-eval.
* **Complexity:** S — **Risk:** Low

#### F-21. Versioned `~/.zshrc` migration system
* **Value:** Robustness — real upgrades, not "diff it yourself"
* **Problem solved:** Drift warning ≠ migration. New template features never reach existing installs.
* **Design:** Embed `# master-oogway:rc-version=N`. Per-version additive migration function (append a missing `plugins=()` entry, etc.).
* **Complexity:** M — **Risk:** Medium

#### F-22. Unified `mo-test` harness
* **Value:** Reliability
* **Problem solved:** Recent regressions (fbranch injection, gitstatus guard, etc.) were caught post-hoc.
* **Design:** `tests/<plugin>.bats` per plugin. Test: aliases defined, `-h` works, missing-dep handling. Run via `master-oogway doctor --test`.
* **Complexity:** L — **Risk:** Low

### Features deliberately not proposed
- **Plugin marketplace / network-fetched plugins** — multiplies attack surface for a personal-dotfiles project. F-10 (user plugin dir) is the right ceiling: third-party plugins still live in the user's filesystem with no central index.
- **Telemetry of any kind** (even opt-in) — not appropriate here.

---

## 8. Refactoring Recommendations

### Structural improvements

1. **Hoist `_mo_require` out of `mo-utils`** into a tiny lib (`omz-custom/lib/mo-require.zsh`) auto-sourced by every plugin via a one-line `source ${0:A:h}/../../lib/mo-require.zsh`. Eliminates H-1 / M-9 without inline copy-paste. Alternative chosen because it changes plugin file structure: inline copy-paste is simpler.

2. **Adopt 3-line metadata header convention** (`# mo-plugin:` / `# mo-deps:` / `# mo-desc:`) on every plugin. Replace the hardcoded tool list at `mo-cli.plugin.zsh:40-56` with a `master-oogway doctor` that auto-discovers. Underpins F-3, F-7, F-11.

3. **Consolidate separator-render boilerplate** (M-29): four near-identical 8-LOC functions → one `__dragon_render_separator` helper. -40 LOC, +consistency.

4. **Consolidate `command -v` probes** (M-8) into a single capability cache in `mo-utils`. Plugins consult `$MO_CAPS[…]`. Reduces fork count at shell start.

5. **Lift `_init_plugins` out of dev-mode branch** (H-3) — call unconditionally so update-mode also self-heals broken submodules.

6. **Extract drop-in loader** (zshrc.master-oogway:92, 190) into a helper function `_mo_source_dropins <dir>` to reduce template noise and make it easy to add a user-plugin dir (F-10).

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
| Lift `_init_plugins` out of dev-mode branch | H-3 | S |
| Replace `_dragon_render_preview` fresh-zsh with cache | H-6 | M |
| `typeset -g` instead of `export` for DRAGON__* defaults | H-5 | S (audit needed) |
| Cache "host set up OK" in mo-lan-ssh wrapper | H-7 | S |
| `MO_LAN_SSH_DISABLED=1` short-circuit | H-8 | S |
| `MO_SAFE_MODE=1` plugin-array gate | M-32, F-2 | S |
| `ssh -G`-style NUL-delim in `frg` | H-4 | S |
| Backup re-trigger when marker missing on update | M-4 | S |

### Fallback strategies

* **Terminal capability auto-detect** — currently SSH-presence-only. Add `tput colors`, `$COLORTERM`, and one-time glyph-render probe (F-18). Default `USE_NERD_FONT=false` on `linux` / `screen` / dumb-tmux.
* **Async git segment fallback** — if `gitstatusd` fails (read-only filesystem, etc.), today's only escape is `ENABLE_GIT_STATUS=false`. Add a `GIT_STATUS_MODE=sync|async|off` with `sync` falling back to `git symbolic-ref HEAD` once per `chpwd`.
* **md2pdf precheck** — `_mo_require pandoc md2pdf pandoc` plus `kpsewhich xelatex` plus `fc-list | grep -qi 'JetBrains Mono'` before launching.
* **Capability degraded reminder** — periodic (weekly, gated by mtime of a state file) "BTW, install `eza` for nicer `ls`" nudge.

### Defensive design improvements

* **Marker line + content hash for `~/.zshrc`** — if hash changes between runs (template upgrade), trigger migration path (F-21); if hash matches but marker missing, treat as user-edited and back up.
* **State persistence for user choices** — sshd_config "no" answer, banner-acknowledgment, capability-probe result — all belong in `~/.config/master-oogway/state.zsh` (a structured state file beyond the current theme-vars hash).
* **`always { ... }` blocks** in `_dragon_read_key` to guarantee trap restoration (M-26).
* **Sanitization layer for `please`** — proper handling of quoting via `${(z)$(fc -ln -1)}` and `${@[@]}` (L-33).

---

## 10. Final Recommendations Roadmap

### Short term — quick wins (next 2-4 commits)

These are pure UX or robustness wins with minimal architectural impact. Recommend tackling **in this order** because each is independent and small:

1. **H-1 / M-9 fix** — inline `_mo_require` fallback in every consumer plugin (5 LOC × 11 plugins). Closes a real cliff.
2. **F-2 / M-32** — `MO_SAFE_MODE=1` env-gated plugin array. 10 LOC + README section. Unlocks debugging.
3. **F-1** — `mo-help` command using existing `# Provides:` headers. ~50 LOC. Surfaces ~80% of the framework that users currently don't discover.
4. **H-2 / M-2** — `chsh` step in installer + one README line.
5. **H-3** — lift `_init_plugins` out of dev-mode branch.
6. **H-4** — `frg` NUL-delim or filter `:` filenames.
7. **H-5** — `typeset -g` instead of `export` for `DRAGON__*` defaults (audit, then ship).
8. **H-7** — `lan-hosts.keys-ok` cache in mo-lan-ssh wrapper.
9. **H-8** — `MO_LAN_SSH_DISABLED=1` + `MO_LAN_SKIP_WRAPPER=1` + document `command ssh`.
10. **M-12** — `mo-safety-override/reboot` arg forwarding.
11. **M-18** — **delete or relocate `MO-LAN-PLAN.md`**. Pick README as canonical source.
12. **M-17** — implement `mo-lan-ssh forget <host>` (the most-needed phase-3 subcommand).
13. **F-13** — `install.sh --dry-run`. Trust-building for curl|bash.
14. **F-6** — `master-oogway profile-startup` alias.
15. **L-15** — `mo-welcome` SHLVL/`MO_WELCOME_QUIET` guard.

Estimated total: ~600 LOC + doc updates. Each ships independently.

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

1. **F-8** — Pluggable segment registry for Dragon. Largest architectural win for the theme; converts `prompt.zsh` from hand-edited concat to data-driven loop. Migration concern: existing user `conf.zsh` files keep working unchanged (defaults).
2. **F-10** — First-class user-plugin dir `~/.master-oogway-user/plugins/`. Touches `~/.zshrc` template; needs migration note.
3. **F-12** — Environment-profile selector. Biggest API change; do *after* F-3 (metadata headers) and F-11 (drop-file disable) so the mechanism reuses existing primitives.
4. **F-16** — Async user segments. Requires F-8 first.
5. **F-21** — Versioned `~/.zshrc` migration system. Pairs with F-19 (submodule version dashboard) for a "framework upgrade" story.

### What to deliberately not do

* **Network-fetched plugins / marketplace** — keeps attack surface bounded.
* **Telemetry** — not appropriate for personal dotfiles.
* **Cross-distro packaging** (RPM/Pacman) — single-distro focus is a strength.
* **Sandbox plugins** — over-engineering for trusted user-installed code.

### Closing remark

master-oogway is in unusually good shape for its category. The audit found **zero critical issues** and the eight high-severity items are mostly UX gaps rather than crashes. The single largest investment return is **F-3 (plugin metadata headers)** because it unlocks F-7, F-11, and the framework's discovery story (F-1, F-9). The single largest robustness improvement is **H-1 (inline `_mo_require` fallback)**, which closes a cliff that no documentation can paper over.

The author's recent fix cadence (36 commits across the May audit) demonstrates that the framework is actively maintained and quality-conscious. This audit is best treated as the next two-quarter backlog.

---

*Total issues: 75 (0 🔴 / 8 🟠 / 32 🟡 / 35 🟢). Total feature proposals: 22. File:line citations: 100+. Audited: 5,729 LOC across 42 files.*
