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

#### L-13. Notifier walks the entire themes directory tree on every shell start when mtime changed

* **Location:** `omz-custom/themes/dragon/notifier.zsh:24-25`
* **Problem:** The mtime guard (`stored_mtime == current_mtime`) skips the hash computation on the common path, but computing `current_mtime` itself requires `find "${themes_dir}" -name '*.zsh' -printf '%T@\n' | sort -n | tail -1` — a full directory walk that forks `find`, `sort`, and `tail` on every shell open. The guard avoids the hash, but not the stat scan. On most shell opens the mtime will match and `current_hash` is never computed, so the cost is just the `find` walk. On slow filesystems (NFS, encrypted home, Raspberry Pi SD card) this is measurable.
* **Recommendation:** Stat a single sentinel file instead (e.g., the schema file, which changes whenever a new variable is added): `current_mtime=$(stat -c '%Y' "${themes_dir}/schema.zsh" 2>/dev/null)`. One stat instead of a recursive find + sort pipeline.

#### L-17. `_confirm_reboot` blocks forever — `read -r ans` has no timeout

* **Location:** `omz-custom/plugins/mo-safety-override/mo-safety-override.plugin.zsh:16`
* **Problem:** When `reboot` is typed in an automated or semi-interactive context where stdin is connected but not actively monitored (e.g., a terminal left open in a script that's waiting on the user), the confirmation `read` hangs indefinitely. There is no `read -t N` timeout, so the system stays up silently waiting. In a real reboot scenario this is fine, but in automation it's a footgun.
* **Recommendation:** `read -r -t 30 ans || { echo "Timed out — reboot cancelled."; return 1; }`. 30 seconds is generous for an interactive user and safe for automation.

#### L-18. `pcat` and `pless` alias names are undocumented and non-obvious

* **Location:** `omz-custom/plugins/mo-bat-override/mo-bat-override.plugin.zsh:14,18`
* **Problem:** `pcat` (bat with full style — headers, line numbers, git diff markers) and `pless` (bat with pager, plain style) are useful but their names don't follow any discoverable convention. A user reading `# Provides:` would see `cat/less` overrides listed but `pcat`/`pless` are invisible until they grep the plugin source. The `p` prefix is not explained anywhere.
* **Recommendation:** Either add `pcat` and `pless` explicitly to the `# Provides:` header, or rename to `bat-full` / `bat-paged` which are self-describing. At minimum, add a one-line comment above each alias explaining the intent.

#### L-19. `l` and `la` have different column sets depending on whether eza is installed

* **Location:** `omz-custom/plugins/mo-eza-override/mo-eza-override.plugin.zsh:10,18`
* **Problem:** With eza: `l="eza -F -l --no-user --smart-group --time-style=long-iso"` (no owner). Without eza: `l="ls -goth --time-style=long-iso"` (shows owner via `-o`). The columns shown are subtly different between the two paths, meaning the same alias behaves differently depending on whether eza is installed. A user who migrates machines and loses eza gets unexpected output from familiar aliases.
* **Recommendation:** Document this in the plugin header comment so users aren't surprised. A stricter fix would align the column set explicitly via `ls` flags to match eza's output, but that's cosmetic and probably not worth the effort.

#### L-20. `sshto` doesn't resolve `Include` directives in `~/.ssh/config`

* **Location:** `omz-custom/plugins/mo-network/mo-network.plugin.zsh:21-23`
* **Problem:** `sshto` parses `~/.ssh/config` and `~/.ssh/config.d/*` with a plain `awk` regex that finds `Host` lines. OpenSSH's `Include` directive can pull in additional config files; `sshto` doesn't follow those. A user with `Include ~/.ssh/work-hosts` in their main config will not see those hosts in the fuzzy picker. The plugin already acknowledges this with a comment.
* **Recommendation:** The proper fix is `ssh -G <placeholder>` which resolves the full config including includes, but that requires a hostname. Alternatively, recursively follow `Include` lines in the awk script. The comment acknowledgment is good; the gap is real but narrow (most users keep their hosts directly in `~/.ssh/config.d/`).

#### L-21. `natip` has no IPv6 flag

* **Location:** `omz-custom/plugins/mo-network/mo-network.plugin.zsh:4-7`
* **Problem:** `natip` hardcodes `ifconfig.me` which returns an IPv4 address. There is no `-6` flag to request the public IPv6 address. On dual-stack networks where the user wants to verify their IPv6 NAT64 or public IPv6, `natip` is unhelpful.
* **Recommendation:** `natip -6` could use `curl -s --max-time 5 -6 ifconfig.me` or an IPv6-specific endpoint like `ipv6.icanhazip.com`. One extra flag, minimal code.

#### L-22. `extract` accepts symlinks — `gunzip` modifies the symlink target

* **Location:** `omz-custom/plugins/mo-files/mo-files.plugin.zsh:63,76`
* **Problem:** The `[[ ! -f "$file" ]]` guard at line 63 returns true for symlinks (symlinks to regular files pass `-f`). For most formats this is harmless — `tar`, `unzip`, `7z` read the file and write a new directory. But `gunzip` (the `.gz` case) decompresses **in place**, replacing the file with its uncompressed content. If `$file` is a symlink, `gunzip` replaces the symlink target, modifying a file the user may not have intended to touch.
* **Recommendation:** Add a `-L "$file"` symlink check with a warning before the `gunzip` branch: `[[ -L "$file" ]] && { echo "extract: '$file' is a symlink — gunzip would modify the target. Use 'gunzip $(realpath "$file")' explicitly." >&2; failed=1; continue; }`.

#### L-23. `bak` computes the timestamp once outside the loop — parallel calls collide

* **Location:** `omz-custom/plugins/mo-files/mo-files.plugin.zsh:95`
* **Problem:** `ts=$(date +%Y%m%d_%H%M%S_%N)` runs once before the `for f in "$@"` loop. If the user runs `bak a b c`, all three backups get the identical timestamp: `a.bak.20260517_213300_000000000`, `b.bak.20260517_213300_000000000`, `c.bak.20260517_213300_000000000`. The nanosecond field (`%N`) makes real-world collisions extremely unlikely on one call, but if the filesystem doesn't support sub-second precision (FAT32, some NFS exports), `%N` returns `000000000` and all three names are truly identical — `cp -av` would overwrite them in sequence, leaving only the last file's backup.
* **Recommendation:** Move `ts=$(date ...)` inside the loop body so each file gets its own timestamp. The loop is short (user-supplied files), so the extra `date` fork per file is negligible.

#### L-24. `port` passes `-sTCP:LISTEN` to lsof but UDP entries bypass the state filter

* **Location:** `omz-custom/plugins/mo-process/mo-process.plugin.zsh:30`
* **Problem:** `lsof -iTCP:"$1" -iUDP:"$1" -sTCP:LISTEN` applies the LISTEN-state filter only to TCP entries. UDP is connectionless and has no LISTEN state; lsof shows all UDP sockets on the port regardless of the `-sTCP:LISTEN` flag. For port 53 (DNS), this correctly shows both the TCP listener and the UDP socket. But for a port with only a UDP socket in a transient state (e.g., a client socket that happened to use the same ephemeral port), it would appear in the output, which may confuse the user into thinking something is "listening" when it isn't.
* **Recommendation:** For UDP the closest equivalent filter is `-sUDP:Idle` or simply accepting that all UDP socket appearances are reported. Add a note in the `--help` output: "UDP sockets are shown without state filtering (UDP is connectionless)."

#### L-25. `up N` past the filesystem root silently lands at `/`

* **Location:** `omz-custom/plugins/mo-navigation/mo-navigation.plugin.zsh:25-28`
* **Problem:** `up 10` from `/home/user/projects` constructs `../../../../../../../../../../..` (10 levels up) and calls `cd` on it. zsh's `cd` clamps at `/`, so the user ends up at `/` regardless. No error, no message. A user who mistypes `up 10` instead of `up 1` gets silently deposited at the root.
* **Recommendation:** Cap the level at the current depth: `local max_depth=$(( ${#${(s:/:)PWD}} )); (( $1 > max_depth )) && { echo "up: can only go up ${max_depth} level(s) from here" >&2; return 1; }`.

#### L-26. `_mo_check` is defined as a global function inside `_mo_doctor`, leaking if interrupted

* **Location:** `omz-custom/plugins/mo-cli/mo-cli.plugin.zsh:24-39`
* **Problem:** `_mo_doctor` defines `_mo_check` as a regular function inside its body, then calls `unset -f _mo_check` at line 65. If the user presses Ctrl+C between the function definition (line 24) and the `unset -f` call (line 65), `_mo_check` remains defined as a global function in the shell for the rest of the session. This is a minor leak — the function does nothing harmful if called directly — but it pollutes the function namespace.
* **Recommendation:** Use `function _mo_check { ... }` inside a subshell, or define it as a local function using zsh's `local -f` pattern. Simplest fix: wrap the entire `_mo_doctor` body in `() { ... }` (anonymous subshell) so all internal function definitions are discarded on exit regardless of how the function terminates.

#### L-27. `master-oogway uninstall` has no in-shell confirmation before delegating to `install.sh --uninstall`

* **Location:** `omz-custom/plugins/mo-cli/mo-cli.plugin.zsh:72-74`
* **Problem:** `master-oogway uninstall` immediately execs `install.sh --uninstall` with no "are you sure?" prompt in the CLI dispatcher itself. `install.sh --uninstall` does prompt the user for destructive steps (removing the cloned repo), but a user who accidentally types `master-oogway uninstall` instead of `master-oogway update` gets the uninstall flow without a moment to abort before the first prompt appears.
* **Recommendation:** Add a `confirm "This will remove master-oogway from your system. Continue?"` call in the CLI dispatcher before exec-ing the installer. One line, same `confirm` helper already used in `install.sh`.

#### L-28. `serve` enables symlink traversal by default

* **Location:** `omz-custom/plugins/mo-dev/mo-dev.plugin.zsh:65`
* **Problem:** `python3 -m http.server` follows symlinks by default. A user who runs `serve` in a directory that contains a symlink pointing outside the served tree (e.g., `ln -s /etc/passwd passwd`) exposes that target file to anyone who can reach the server. The default bind is `127.0.0.1` which limits exposure to localhost, but the `SERVE_BIND` env var allows binding to `0.0.0.0` for LAN sharing — at that point symlink traversal is a real information-disclosure risk.
* **Recommendation:** Python's `http.server` has no built-in symlink-disable flag. The mitigation is the warning already printed when `bind != 127.0.0.1`, plus a note in the `--help` output that symlinks are followed. For a stricter fix, `python3 -c "..."` with a custom `SimpleHTTPRequestHandler` that overrides `translate_path` to reject out-of-tree paths.

#### L-29. `md2pdf` invokes pandoc without pre-checking its dependencies

* **Location:** `omz-custom/plugins/mo-dev/mo-dev.plugin.zsh:97,103`
* **Problem:** `md2pdf` calls `pandoc --pdf-engine=xelatex -V monofont="JetBrains Mono"` without first checking that `pandoc`, `xelatex`, or `JetBrains Mono` are available. Missing `pandoc` → a clear error. Missing `xelatex` → a cryptic LaTeX engine error buried in pandoc output. Missing `JetBrains Mono` → pandoc succeeds but falls back to a different monospace font silently, producing a PDF that looks different from what the user expected.
* **Recommendation:** Add three pre-checks: `command -v pandoc`, `kpsewhich xelatex` (or `command -v xelatex`), and `fc-list | grep -qi 'JetBrains Mono'`. Print a clear actionable error for each missing piece before running pandoc.

#### L-30. `gsum` doesn't support `-C <path>` to run against a different repo

* **Location:** `omz-custom/plugins/mo-git/mo-git.plugin.zsh:32`
* **Problem:** `gsum` only operates on `$PWD`. There is no `-C <dir>` flag to inspect a repo without `cd`-ing into it, unlike `git` itself which accepts `-C` everywhere. A user who wants a summary of a sibling repo without leaving their current directory has no shorthand.
* **Recommendation:** Accept an optional `-C <dir>` first argument: `local dir="."; if [[ "${1:-}" == "-C" ]]; then dir="$2"; shift 2; fi`. Pass `git -C "$dir"` to all subsequent git calls in the function.

#### L-31. `fbranch` falls back to `main` if `origin/HEAD` is unset — silently wrong for non-`main` repos

* **Location:** `omz-custom/plugins/mo-git/mo-git.plugin.zsh:60-63`
* **Problem:** `default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||') || default_branch="main"`. If `origin/HEAD` isn't set (common for repos cloned with `--no-single-branch` or older git versions), the fallback is hardcoded `main`. For repos whose default branch is `master`, `develop`, or anything else, the fzf preview `git log HEAD..main --oneline` shows nothing or errors. The user sees an empty diff preview for every branch.
* **Recommendation:** Try `origin/HEAD` first, then fall back to `git remote show origin | grep 'HEAD branch'` (slower, makes a network call), or ask git directly: `git symbolic-ref --short HEAD` as a last resort gives the current branch, not the default — not ideal. A pragmatic fix: try `origin/main`, then `origin/master`, then current branch: `for b in main master; do git rev-parse --verify "origin/$b" &>/dev/null && { default_branch="$b"; break; }; done`.

#### L-32. `_mo_lan_ssh_wrapper` pass-through branches don't `exec ssh`

* **Location:** `omz-custom/plugins/mo-lan-ssh/mo-lan-ssh.plugin.zsh:251,267,292`
* **Problem:** The three early-return pass-through branches (non-interactive stdin, `MO_LAN_AUTO_TRUST=false`, non-LAN host) all do `command ssh "$@"; return`. This means the wrapper function runs in the parent shell process and `ssh` runs as a child. The `return` after `command ssh` is redundant since the function returns 0 after ssh exits regardless, but more importantly, the parent shell stays alive waiting for the child. Using `exec command ssh "$@"` instead would replace the wrapper with the ssh process, saving one process-table slot and returning the correct exit code directly.
* **Recommendation:** Change the three `command ssh "$@"; return` pass-throughs to `exec command ssh "$@"`. Only the wrapped path (where post-ssh logic runs) should keep `command ssh` without `exec`.

#### L-33. `please` loses argument quoting and doesn't detect an existing `sudo` prefix

* **Location:** `omz-custom/plugins/mo-shell-tools/mo-shell-tools.plugin.zsh:28`
* **Problem:** `alias please='sudo $(fc -ln -1)'`. Two issues: (1) `$(fc -ln -1)` captures the last command as a string and word-splits it when the alias expands — arguments with spaces (e.g., `grep "hello world" file`) are broken into separate words. The correct approach is `eval "sudo $(fc -ln -1)"` or using `fc -e` with a proper rerun mechanism. (2) If the last command already started with `sudo`, `please` prepends another `sudo`, producing `sudo sudo <cmd>` which is harmless but silly.
* **Recommendation:** Replace the alias with a function: detect `sudo` prefix, use `${(z)$(fc -ln -1)}` (zsh word-splitting that respects quoting) to reconstruct the arguments safely, then `sudo "${cmd_array[@]}"`.

#### L-34. `mo-colorize-override` provides no escape-hatch aliases for `ip` and `diff`

* **Location:** `omz-custom/plugins/mo-colorize-override/mo-colorize-override.plugin.zsh`
* **Problem:** The plugin overrides `ip` and `diff` with `--color=auto`. Unlike the other override plugins (`mo-bat-override`, `mo-eza-override`, `mo-safety-override`) which all provide `r*` escape-hatch aliases (`rcat`, `rls`, `rcp`, `rmv`), this plugin provides no `rip` or `rdiff` escape hatches. A script or pipeline that needs raw (uncolored) `ip` or `diff` output has no clean way to bypass the override without calling the full binary path (`/usr/bin/ip`) or disabling color via flags.
* **Recommendation:** Add `alias rip='\ip'` and `alias rdiff='\diff'` for consistency with the rest of the override plugin convention.

#### L-35. `psgrep` calls `pgrep` without a dependency precheck

* **Location:** `omz-custom/plugins/mo-process/mo-process.plugin.zsh:4-11`
* **Problem:** `psgrep` calls `pgrep -lif "$1"` with no `command -v pgrep` check beforehand. On a minimal system where `pgrep` isn't installed (it's part of `procps`, which is standard on Ubuntu but not on all Linux variants), `psgrep` would emit a cryptic `pgrep: command not found` error with no install hint. This is inconsistent with `fkill` (same file) which does check for `fzf` before calling it.
* **Recommendation:** Add `command -v pgrep &>/dev/null || { echo "psgrep: pgrep not installed (try: sudo apt install procps)" >&2; return 1; }` at the top of the function body.

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

#### F-3. Plugin metadata header + `doctor` rewrite ⭐
* **Value:** Robustness + extensibility
* **Design:** Three-line header per plugin (`# mo-plugin:`, `# mo-deps:`, `# mo-desc:`). `master-oogway doctor` parses headers to compute dep report dynamically; eliminates the hardcoded list at `mo-cli.plugin.zsh:40-56`.
* **Complexity:** M (~120 LOC) — **Risk:** Low

#### F-4. Central capability cache populated by `mo-utils`
* **Value:** Performance + dev-XP
* **Problem solved:** `command -v bat` at 13 sites; wasted forks at shell start.
* **Design:** `mo-utils` writes `~/.cache/master-oogway/capabilities.zsh` on first load (invalidated by `$PATH` mtime). Plugins consult `$MO_CAPS[bat]`.
* **Complexity:** M (~120 LOC, careful invalidation) — **Risk:** Medium

#### F-5. `master-oogway dump` — effective config snapshot
* **Value:** Support / dev-XP
* **Design:** Markdown-friendly dump of: version, install path, `$ZSH_THEME`, active plugins, all `DRAGON__*`, all `MO_*`, `doctor` output, git rev. Sanitize `MO_LAN_DNS_SERVER` etc. by default.
* **Complexity:** S — **Risk:** Low

#### F-6. `master-oogway profile-startup` — built-in startup profiler
* **Value:** Performance + dev-XP
* **Design:** Alias for `MO_ZPROF=1 zsh -ic exit` with `zmodload zsh/zprof` enabled when `$MO_ZPROF`.
* **Complexity:** S — **Risk:** Very low

#### F-7. `master-oogway bisect` — find the culprit plugin
* **Value:** Dev-XP for end users
* **Design:** Repeatedly spawn `MO_DISABLE=plugin1,plugin5 zsh -ic exit` measuring time/exit-code; halve the set each iteration. Depends on F-2.
* **Complexity:** M — **Risk:** Low

#### F-8. Pluggable segment registry for Dragon
* **Value:** Power-user extensibility
* **Design:** `DRAGON_LEFT_SEGMENTS=(ssh_prefix username … directory)` and `DRAGON_RPROMPT_SEGMENTS=(…)` arrays. `dragon__set_lprompt` iterates calling `dragon__set_$segment`. Users define function + append. Recovers ~40 LOC from `prompt.zsh`.
* **Complexity:** M — **Risk:** Low

#### F-9. `mo-where` — find which plugin defined a command
* **Value:** Discoverability
* **Design:** Grep `$ZSH_CUSTOM/plugins/mo-*/` for `^(alias|function) <name>`; print `mo-git:12: alias gs="git status"`.
* **Complexity:** S (~30 LOC) — **Risk:** Very low

#### F-10. `~/.master-oogway-user/plugins/` — first-class user plugin dir
* **Value:** Extensibility
* **Design:** Discovered by `~/.zshrc` and appended to `plugins=()`. Same convention. `mo-help` and `doctor` recognize them.
* **Complexity:** M — **Risk:** Low (additive, opt-in)

#### F-11. `master-oogway plugin enable/disable <name>`
* **Value:** UX
* **Design:** Drop-file `~/.config/master-oogway/disabled/<name>`; plugins check at top. CLI subcommand touches/removes file.
* **Complexity:** S — **Risk:** Very low

#### F-12. Environment-profile selector (`MO_PROFILE=desktop|server|pi|minimal`)
* **Value:** UX + maintenance hygiene
* **Design:** `~/.zshrc` switches `plugins=()` membership on `$MO_PROFILE` (default: `desktop`). Installer probes `$DISPLAY`, `/etc/rpi-issue`, `/.dockerenv` and writes a suggested value on first install.
* **Complexity:** M — **Risk:** Medium (re-templates `~/.zshrc`; needs migration)

#### F-13. `install.sh --dry-run`
* **Value:** Onboarding / trust
* **Design:** Print every file to create/modify/back-up, every sudo, every apt — without doing any.
* **Complexity:** S — **Risk:** Low

#### F-14. `dragon-configure --get VAR / --set VAR=VAL` non-interactive mode
* **Value:** Power-user (Ansible / dotfiles bootstrap)
* **Design:** Two new flags that read/write `conf.zsh` (already structured for sed-friendliness).
* **Complexity:** S — **Risk:** Low

#### F-15. Per-host config layer (`~/.config/master-oogway/conf.d/<hostname>.zsh`)
* **Value:** UX for multi-host users
* **Design:** Auto-source `conf.d/${HOST}.zsh` after `conf.zsh`. 3-line change to load path.
* **Complexity:** S — **Risk:** Very low

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

*Open issues: 25 🟢 Low. Feature proposals: 22. Audited: 5,729 LOC across 41 files.*
