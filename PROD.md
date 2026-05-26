# PROD.md — master-oogway production-readiness audit

> Scope: the full `master-oogway` repository (`install.sh`, `zshrc.master-oogway`,
> `zshenv.master-oogway`, `omz-custom/{lib,plugins,themes/dragon}`, presets, docs,
> submodules). Audited as a **shell framework** intended to ship to third-party
> users — not as personal dotfiles.
>
> Severity levels: **CRITICAL** = release-blocking, **HIGH** = ship-blocking for
> v1.0, **MEDIUM** = ship-blocking for v2.0, **LOW** = polish/quality, **INFO** =
> contextual notes. Each finding cites concrete files and line numbers.
>
> Where this document overlaps with the recently-resolved `MASTER-OOGWAY-AUDIT.md`,
> it explicitly says so and moves to the *next* layer (CI, perf budget, plugin
> API, theme registry, threat model).

---

## Table of contents

1. [Executive summary](#1-executive-summary)
2. [Current state assessment](#2-current-state-assessment)
3. [Production readiness score](#3-production-readiness-score)
4. [Critical issues](#4-critical-issues)
5. [High priority improvements](#5-high-priority-improvements)
6. [Medium priority improvements](#6-medium-priority-improvements)
7. [Low priority improvements](#7-low-priority-improvements)
8. [Architecture analysis](#8-architecture-analysis)
9. [ZSH performance review](#9-zsh-performance-review)
10. [Plugin architecture review](#10-plugin-architecture-review)
11. [Theme system review](#11-theme-system-review)
12. [Security review](#12-security-review)
13. [Threat model](#13-threat-model)
14. [UX / DX review](#14-ux--dx-review)
15. [Reliability review](#15-reliability-review)
16. [Completions review](#16-completions-review)
17. [CI / CD review](#17-cicd-review)
18. [Testing review](#18-testing-review)
19. [Documentation review](#19-documentation-review)
20. [Roadmap](#20-roadmap)
21. [Quick wins](#21-quick-wins)
22. [Long-term vision](#22-long-term-vision)
23. [Release checklist](#23-release-checklist)
24. [Production checklist](#24-production-checklist)
25. [Contributor checklist](#25-contributor-checklist)
26. [Final recommendations](#26-final-recommendations)

---

## 1. Executive summary

`master-oogway` is a complete, opinionated Zsh environment that bundles:

- **1 framework theme** (`dragon`) split into 8 schema-driven parts, with 26
  presets and an interactive wizard (`dragon-configure`).
- **25 first-party plugins** (`omz-custom/plugins/mo-*`) — 6 override + 19
  additive — covering git, fzf, search, network, ssh-tunnel, lan-ssh
  auto-discovery, trash, build, etc.
- **4 vendored upstream plugins** as git submodules (`gitstatus`,
  `zsh-autosuggestions`, `zsh-syntax-highlighting`, `you-should-use`).
- A **three-mode installer** (`install.sh`, 831 LOC) — `curl|bash`, in-place
  update, dev-symlink — with timestamped backups, idempotent re-runs, marker-
  wrapped SSH config blocks, and a clean `--uninstall` path.
- A **single source of truth** (`omz-custom/themes/dragon/schema.zsh`) for every
  `DRAGON__*` variable: defaults, types (`bool|color|string|enum:a|b|c`),
  hints, and wizard groups.
- A **dependency declaration system** (`requirements.zsh` for hard,
  `optional-deps.zsh` for soft) read by the installer to print a missing-package
  report.

The codebase shows craft far above the dotfile median: atomic file writes,
namespaced globals (`DRAGON__*`, `_MO_*`), `set -Eeuo pipefail` with line-aware
ERR traps, defensive validators for every external input (hostnames, ports,
preset names, color names), single-quoted conf.zsh emission (immune to `$`,
backtick, `\` expansion), and a recently-resolved internal audit
(`MASTER-OOGWAY-AUDIT.md`) covering 37 items across CRITICAL/HIGH/MEDIUM/LOW.

It is **not yet** production-grade by the standards of a real OSS framework —
not because individual code is bad, but because the *ecosystem layer* is
missing:

- **No CI.** `CONTRIBUTING.md` documents `bash -n`, `zsh -n`, `shellcheck` —
  none of these run automatically. There is no GitHub Actions workflow, no
  matrix testing across Ubuntu versions, no shell-version matrix, no
  performance regression gate.
- **No test suite.** Zero unit tests, zero integration tests, zero prompt
  snapshot tests. The only thing exercised at runtime is `dragon-configure`'s
  live preview.
- **No formal plugin API or manifest.** Plugins use ad-hoc conventions
  (`requirements.zsh`, `optional-deps.zsh`, no version, no description) that
  work today only because there are 25 of them and one maintainer. They will
  not scale to outside contributions or third-party plugin authors.
- **No startup performance budget.** Several plugins fork subprocesses at load
  time (`grep -c '^processor' /proc/cpuinfo` in `mo-build` and `mo-welcome`,
  `command -v` checks for the same tool repeated across 5 plugins, full
  directory globs in `mo-projects`/`mo-lan-ssh` even when caches haven't
  changed). No `zcompile`/`.zwc` step. `compinit` is not gated by a cache check.
- **No release engineering.** Version is just `git log -1 --format=%cd-%h`. No
  tags. No CHANGELOG. No semver. No Homebrew/Nix/AUR packaging. No release
  signing.
- **No formal threat model.** The repo correctly identifies "LAN = trusted"
  inside `_mo_lan_trust.zsh` but never writes this down for users to audit.
  Several behaviours (auto-`ssh-keygen -R`, `please` re-`eval`, `serve`
  `SERVE_BIND=0.0.0.0`) live on a security boundary that deserves explicit
  documentation.

The bones are excellent. To ship this as a framework other people depend on,
the next 6 months of work is **ecosystem and tooling**, not core shell code.

### Headline numbers

| Metric | Value |
|---|---|
| First-party Zsh LOC | ~5,500 (theme + plugins, excluding submodules) |
| First-party Bash LOC | 831 (`install.sh`) |
| Plugins (first-party) | 25 (6 override + 19 additive) |
| Plugins (vendored) | 4 git submodules |
| Theme presets | 26 |
| Total `DRAGON__*` variables | ~110 (counted in `_DRAGON_DEFAULTS`) |
| Plugin READMEs | 25 / 25 (100%) |
| `optional-deps.zsh` manifests | 8 / 25 (32%) |
| `requirements.zsh` manifests | 8 / 25 (32%) |
| Lines of CI configuration | 0 |
| Automated tests | 0 |
| `zcompile`d files | 0 |
| Public release tags | 0 |

---

## 2. Current state assessment

### 2.1 Layout (verified)

```
master-oogway/
├── install.sh                       # 831 LOC bash, 3 modes, --uninstall
├── zshrc.master-oogway              # 230 LOC — installed once, never overwritten
├── zshenv.master-oogway             # 25  LOC — re-installed every run (EDITOR only)
├── editorconfig.master-oogway       # tab-indent, LF, no trailing ws (except md)
├── gitconfig.master-oogway          # curated defaults; user [user] untouched
├── README.md                        # 74  LOC user-facing
├── CONTRIBUTING.md                  # 353 LOC contributor-facing
├── LICENSE                          # 1.1k bytes (presumably MIT)
├── docs/
│   └── superpowers/plans/           # two historical implementation plans
└── omz-custom/                      # ZSH_CUSTOM dir (sourced by OMZ)
    ├── lib/
    │   └── colors.zsh               # _MO_COLORS map: 17 named → xterm-256 idx
    ├── themes/
    │   ├── dragon.zsh-theme         # 4 LOC shim → dragon/*.zsh
    │   └── dragon/
    │       ├── dragon.zsh           # entry: schema → defaults → parts → hooks
    │       ├── schema.zsh           # 490 LOC — single source of truth
    │       ├── configure.zsh        # 1097 LOC — interactive wizard
    │       ├── aliases.zsh          # rezsh + reset_theme_variables
    │       ├── notifier.zsh         # one-shot "new vars" notifier
    │       ├── parts/
    │       │   ├── helpers.zsh      # __get_xterm_*, __dragon__show
    │       │   ├── segments_left.zsh   # username/hostname/dir/prompt_char
    │       │   ├── segments_right.zsh  # date/timer/jobs/conn/exit
    │       │   ├── separators.zsh
    │       │   ├── git.zsh
    │       │   ├── gitstatus.zsh    # lifecycle for romkatv/gitstatus
    │       │   ├── prompt.zsh       # __calc_prompt_length, lprompt/rprompt
    │       │   ├── lifecycle.zsh    # __update_prompt, __refresh_prompt
    │       │   └── transient.zsh    # zle hook, transient prompt collapse
    │       └── presets/             # 26 *.conf.zsh files
    └── plugins/
        ├── mo-auto-ls/              # chpwd → ls
        ├── mo-bat-override/         # cat/less → bat
        ├── mo-build/                # m, mc (parallel make + colormake)
        ├── mo-cli/                  # master-oogway meta CLI
        ├── mo-color/                # color preview/palette/picker
        ├── mo-colorize-override/    # ip/diff → --color=auto
        ├── mo-dirs/                 # mkcd, up, tmpcd, fcd, n
        ├── mo-docs/                 # md2pdf via pandoc+xelatex
        ├── mo-env/                  # fenv (fuzzy env editor)
        ├── mo-eza-override/         # ls/ll/la/tree → eza
        ├── mo-files/                # extract, compress, bak, sizeof, fp
        ├── mo-git/                  # 25+ aliases + groot/gtag/fbranch/flog/gsum
        ├── mo-lan-ssh/              # LAN discovery + auto-trust ssh wrapper
        ├── mo-man/                  # mo-man <plugin> README viewer
        ├── mo-mkscript/             # mkscript — script scaffolder
        ├── mo-network/              # natip, serve, sshto
        ├── mo-nvim-override/        # vim → nvim
        ├── mo-process/              # psgrep, port, fkill
        ├── mo-projects/             # <name> alias per ~/projects/* + p picker
        ├── mo-safety-override/      # cp -i / mv -i / mkdir -pv / reboot confirm
        ├── mo-search/               # f, fhist, fman, frg, grep colors
        ├── mo-shell-tools/          # h ? cwhich vwhich clip mo-where calc epoch please
        ├── mo-ssh-tunnel/           # tunnel <left> to <right>
        ├── mo-trash/                # rm → trash-put + restore/empty/prune
        ├── mo-welcome/              # startup banner (host/os/sys/now/up/ip/...)
        ├── gitstatus/               # SUBMODULE (romkatv)
        ├── zsh-autosuggestions/     # SUBMODULE
        ├── zsh-syntax-highlighting/ # SUBMODULE
        └── you-should-use/          # SUBMODULE
```

### 2.2 What works well today

- **Schema-driven theme.** All theme behaviour is data in `schema.zsh`
  (`_DRAGON_DEFAULTS`, `_DRAGON_TYPE`, `_DRAGON_HINT`, `_DRAGON_GROUPS`,
  `_DRAGON_GROUP_VARS`, `_DRAGON_PRESET_*`). New variables require adding 3-5
  entries — *not* editing the wizard. This is a real plugin-framework
  pattern, not a dotfile.
- **Marker-wrapped config edits.** `~/.ssh/config` and `/etc/ssh/sshd_config`
  are written between `# BEGIN master-oogway:sendenv` / `# END
  master-oogway:sendenv` markers, with legacy bare-line migration. Uninstall
  removes only the bracketed block.
- **Three-mode auto-detecting installer.** `_running_via_pipe`,
  `_running_from_install_dir`, `_running_from_master_oogway_clone` discriminate
  curl-pipe vs. update vs. dev-symlink, with submodule self-healing for the
  case where a `.git` link was deleted.
- **Idempotency.** Every write is `tmp → cmp -s || mv` (`copy_file`).
  `_install_zshrc` keys on the literal string `# master-oogway:managed` and
  never overwrites a file that has it. `_check_zshrc_drift` compares against
  `.upstream-snapshot` to detect template churn without nagging users who
  have local edits.
- **Backups.** Every clobber writes a timestamped `.pre-master-oogway.<ts>`;
  `_find_backup` resolves either timestamped or legacy bare names so a
  rollback can find the right file.
- **Dep system.** `requirements.zsh` is sourced at plugin load (hard);
  `optional-deps.zsh` is parsed only by `install.sh` (soft). The
  installer's `_check_optional_deps` aggregates everything missing into a
  single `sudo apt install ...` one-liner.
- **Atomic LAN discovery.** `_mo_lan_discover.zsh` writes to `${CACHE}.tmp`
  then `mv`. Cache file embeds a network fingerprint (`md5sum` of
  gateway + subnet), so the plugin can detect "laptop moved between LANs"
  and trigger background re-discovery without blocking shell start.
- **Defensive validators.** `_mo_lan_valid_host`, `_mo_lan_valid_port`,
  preset-name regex `^[a-zA-Z0-9_-]+$` for `--preset`, `--export`,
  `--diff`. `fbranch` filters branches with shell-unsafe chars before
  feeding to fzf's `{}`-substitution preview.
- **SSH theme forwarding.** `SendEnv DRAGON__*` (client) + `AcceptEnv
  DRAGON__*` (server) + `DRAGON__FORWARDED=1` (one-time guard inside
  `conf.zsh`) gives transparent prompt parity on remote machines without
  re-sourcing or syncing conf files.
- **Single-quoted conf.zsh.** `_dragon_write_conf` emits `export
  DRAGON__X='value'` with `'\''` escaping for embedded quotes. Immune to
  shell expansion of `$`, backtick, `\` in user values.
- **`zsh -n` self-check.** `_dragon_write_conf` runs `zsh -n` on the
  generated tmp file before `mv` — broken configs are *never* persisted.

### 2.3 What is missing

| Area | Status |
|---|---|
| CI (lint, syntax, perf) | None |
| Test suite | None |
| `zcompile` / `.zwc` | None |
| Plugin manifest (machine-readable) | Partial — `requirements.zsh`/`optional-deps.zsh` only |
| Plugin version pins | None |
| Plugin dependency graph | None |
| Plugin lifecycle hooks | None |
| Theme registry beyond `dragon` | None — `dragon` is hardcoded |
| Theme inheritance for presets | None — every preset duplicates every var |
| Startup benchmark / regression gate | None |
| Release tags / CHANGELOG / semver | None |
| Distribution packaging (Homebrew/Nix/AUR) | None |
| GPG-signed releases | None |
| Threat model document | None |
| Completions (for first-party commands) | None |
| Async completion | None |
| `compinit` cache gate (`-C`) | None — relies on OMZ default |
| `master-oogway doctor` (health check) | None |
| `master-oogway benchmark` (perf snapshot) | None |
| Visual theme/preset picker (TUI) | Partial — `--gallery` is print-only |
| Per-profile config (laptop/server/etc.) | None |

---

## 3. Production readiness score

A staff-engineer-style scorecard with 1–5 ratings (5 = ship-ready, 1 = blocker).

| Dimension | Score | Rationale |
|---|---|---|
| **Code quality** | 4 / 5 | Set -Eeuo, namespaced globals, validators, atomic writes. Some long files (`configure.zsh` 1097 LOC) could be split. |
| **Correctness** | 4 / 5 | Recent audit landed; no known data-loss paths. Lacks tests to *prove* correctness on regression. |
| **Performance** | 2.5 / 5 | Async git ✓; but no zcompile, no compinit cache gate, redundant `command -v` calls, prompt re-built from scratch every keypress. |
| **Security** | 3 / 5 | Defensive validators in user-input paths. `eval`-on-pipeline (`please`), LAN auto-trust, and remote installer (`curl|bash`) lack documented threat model. |
| **Reliability** | 3 / 5 | Backups, idempotent installs, atomic writes — all solid. No tests = no proof of regression resistance. |
| **Plugin architecture** | 2.5 / 5 | Conventions work for 25 plugins / 1 maintainer. Will not scale: no manifest, no version, no dep graph, no isolation. |
| **Theme architecture** | 4 / 5 | Schema-driven, wizard, presets, SSH forwarding, transient — best-in-class. Lacks inheritance, async segment computation, theme registry. |
| **UX (end-user)** | 4 / 5 | `dragon-configure` wizard, `--gallery`, `--diff`, `--export`, `mo-man`, `master-oogway` meta-CLI — excellent. Missing: doctor, benchmark, completions. |
| **DX (contributor)** | 3.5 / 5 | `CONTRIBUTING.md` is clear, dev-mode symlink is great. Missing: CI, tests, snapshot diff, plugin scaffolder. |
| **Documentation** | 3.5 / 5 | Every plugin has a README. CONTRIBUTING covers add-plugin, add-theme-var. Missing: architecture diagrams, threat model, perf guide, migration guides. |
| **CI / release engineering** | 0.5 / 5 | None. No tags, no CI, no signing, no packaging. |
| **Testing** | 0 / 5 | None at all. |
| **Ecosystem / community readiness** | 1.5 / 5 | No issue templates, no PR template, no CODEOWNERS, no Code of Conduct, no Discussions enabled / known. |

**Composite: 2.9 / 5 ≈ "internal-grade, not OSS-grade yet."**

Personal dotfile and "happy-path dev environment for the maintainer's
machines" — yes, already there. Framework that 1000 strangers depend on for
their daily shell — not yet, and CI/testing/release are the bottleneck.

---

## 4. Critical issues

> Anything that, if a user hit it today, would lose data or compromise
> security with no clear recovery path. The recent in-tree audit
> (`MASTER-OOGWAY-AUDIT.md`) cleaned all of the CRITICAL items it knew about.
> Two items remain at this severity from a fresh read.

### CRIT-1 — `curl | bash` install with no integrity verification
**Severity: CRITICAL** (Trust). **Files:** `README.md:16`, `install.sh:293-308`.

The advertised install is:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/tomershay100/master-oogway/main/install.sh)"
```

The script clones `https://github.com/tomershay100/master-oogway.git` with
`git clone --recurse-submodules`. A user who has TLS but no other identity
guarantees gets whatever GitHub serves at the moment of clone — including
whatever the four submodules
(`gitstatus`/`zsh-autosuggestions`/`zsh-syntax-highlighting`/`you-should-use`)
serve. Each is fetched from its respective upstream over HTTPS.

There is no:

- GPG signature on the install script or on any release tag (no releases
  exist).
- Pin of `install.sh` to a specific commit hash (the curl URL points at
  `main`).
- Commit pin on the four submodule URLs (whatever HEAD they're at when
  recursing is what runs as part of the shell).
- Display of the planned changes before they happen ("about to write
  `~/.zshrc`, `~/.zshenv`, modify `/etc/ssh/sshd_config` — proceed?").

A future supply-chain compromise of any of the five repos (this one + 4
submodules) would silently land in every fresh install and every `master-oogway
update` run.

**Recommended fix (high-effort, real):**

1. Move release artifacts to **signed git tags + signed release assets**
   (e.g. `cosign sign-blob` or `gpg --detach-sign`).
2. Change the documented install to point at a release URL, not `main`:
   `https://github.com/tomershay100/master-oogway/releases/download/vX.Y.Z/install.sh`.
3. Pin each submodule to a commit SHA in `.gitmodules` (already pinned in
   the `.git/modules/...` index, but consumers cloning fresh see whatever
   the SHA-in-index resolved to — which is itself shifted by every
   `git submodule update --remote`). Document a `make verify-submodules`
   target that walks `git submodule status --recursive` and asserts the
   recorded SHAs match a checked-in `SUBMODULES.lock`.
4. Optional but valuable: a `--dry-run` flag for `install.sh` that prints
   every planned `cp`/`sed`/`mv`/`apt-get` action without executing.
5. Document this as part of the threat model (§13).

**Recommended fix (low-effort, partial):**

Add a "Verify the install script before piping" note in `README.md`:

```bash
# Audit first, then run:
curl -fsSL https://.../install.sh -o /tmp/install.sh
less /tmp/install.sh
bash /tmp/install.sh
```

This is what most security-conscious OSS frameworks do as a stopgap.

### CRIT-2 — `_install_sshd_acceptenv` modifies `/etc/ssh/sshd_config` without an obvious opt-in
**Severity: CRITICAL** (Privilege / surprise). **Files:** `install.sh:690-738`.

`install.sh` *does* prompt (`confirm "Modify /etc/ssh/sshd_config and reload
sshd? (sudo required)"`) before editing the system sshd. It correctly
validates with `sshd -t` and reverts on failure. So far so good.

The CRITICAL concern is the **default**: when run non-interactively (CI,
container build, piped install), `confirm` returns the default — which for
this prompt is `n`. That part is correct.

The remaining concern is: **the curl-pipe install runs with stdin attached
to a pipe**, so the user *does not* see the actual `read -r reply < /dev/tty`
prompt unless the script is invoked from a real TTY. The pattern
`read -r reply < /dev/tty` in `confirm` works for an interactive user, but
when stdin is a pipe and `/dev/tty` is available, it succeeds and waits for
keyboard input. A user who didn't expect a TTY interaction can lose track of
which prompt they're answering.

**Recommended fix:**

- Add a `--yes`/`-y` flag that auto-accepts; refuse to modify
  `/etc/ssh/sshd_config` unless the flag is present **and** `[[ -t 0 ]]`
  resolved true at script start (already captured implicitly by `_running_via_pipe`).
- Emit a clearly bracketed list of upcoming privileged operations *before*
  any of them, with a single yes/no decision: "About to: (1) edit
  /etc/ssh/sshd_config, (2) sudo reload sshd. Continue?"
- Echo `[sudo]` operations in colour as they happen so users can audit them
  retroactively in their terminal scrollback.

---

## 5. High priority improvements

### HIGH-1 — No CI, no automated lint, no syntax-check on PRs
**Files:** entire repo (no `.github/workflows/`).

`CONTRIBUTING.md:88-103` documents three checks (`bash -n install.sh`, `zsh
-n` on theme/plugin files, `shellcheck install.sh`). None of them run
automatically. Every commit since 2026-05-10 has been merged on trust.

**Fix:** A single `.github/workflows/ci.yml` covering the documented checks
is one afternoon's work and the highest-leverage thing in the entire backlog.
Concretely:

```yaml
# .github/workflows/ci.yml
name: ci
on: [push, pull_request]
jobs:
  lint:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
        with: { submodules: recursive }
      - name: Install zsh + shellcheck
        run: sudo apt-get install -y zsh shellcheck
      - name: bash -n
        run: bash -n install.sh
      - name: zsh -n (theme + plugins)
        run: |
          zsh -n omz-custom/themes/dragon.zsh-theme \
                 omz-custom/themes/dragon/*.zsh \
                 omz-custom/themes/dragon/parts/*.zsh \
                 omz-custom/plugins/mo-*/mo-*.plugin.zsh \
                 omz-custom/plugins/mo-*/requirements.zsh \
                 omz-custom/plugins/mo-*/optional-deps.zsh \
                 omz-custom/lib/colors.zsh
      - name: shellcheck install.sh
        run: shellcheck install.sh lib_install.sh 2>/dev/null || shellcheck install.sh
  smoke:
    runs-on: ubuntu-24.04
    needs: lint
    strategy:
      matrix: { ubuntu: ['22.04', '24.04'] }
    container: ubuntu:${{ matrix.ubuntu }}
    steps:
      - uses: actions/checkout@v4
        with: { submodules: recursive }
      - run: apt-get update && apt-get install -y zsh git curl sudo
      - run: sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
      - run: bash install.sh < /dev/null   # non-interactive
      - run: zsh -ic 'echo ok'
```

### HIGH-2 — No startup performance budget, several known regressors
**Files:** see §9.

Cold-shell startup time is not measured. With OMZ loaded, 25 plugins,
4 vendored plugins, gitstatus daemon spawn, syntax-highlighting wrap, and
two background-detached subshells (`_mo_lan_refresh_async`,
`mo-welcome` shells out 3× to `/proc/loadavg`/`/proc/meminfo`/`/proc/cpuinfo`),
realistic startup will sit around 250-400ms on a modern laptop and degrade
quickly on slow disks or Raspberry Pi.

Specific regressors:

1. **`_check_optional_deps` in `install.sh`** is fine — runs once per
   install. **But the same `command -v` walks are repeated at every shell
   startup** inside each plugin (`bat`, `batcat`, `fzf`, `rg`, `eza`,
   `colormake`, `banner`, `wl-copy`, `xclip`, `nvim`). Many of these are
   checked 2-5 times across plugins. See `mo-bat-override` (lines 7-11),
   `mo-search` (line 7-22), `mo-files` (lines 142-148).

   **Fix:** Pre-compute once at OMZ load, expose as
   `(( $+commands[bat] ))`-cached map in `omz-custom/lib/optdeps.zsh`,
   require plugins to read from it instead of forking another `command -v`.

2. **`mo-build` forks `grep -c '^processor' /proc/cpuinfo`** at plugin
   source time (line 4). At shell start. Every shell. Same for `mo-welcome`
   line 47 inside `_mo_welcome_field_load`.

   **Fix:** Use `nproc` (cached binary), or zsh's `${#${(@f)$(< /proc/cpuinfo)}:#processor*}` (zero forks).

3. **`mo-projects` globs `$projects_dir/*(N/)`** every shell start. For users
   with hundreds of project directories this is `O(n)` syscalls every prompt
   cold open. The aliases are usually identical from one shell to the next.

   **Fix:** Cache the alias-set under `~/.config/master-oogway/projects-aliases`
   keyed by `stat -c %Y` on `$projects_dir`; skip re-globbing if mtime hasn't
   changed.

4. **No `zcompile`.** `dragon-configure` is 1097 lines of zsh; `mo-color` is
   379 lines. Both are sourced at shell start. `zcompile`d `.zwc` files
   parse 30-50% faster.

   **Fix:** Add a `zcompile-all` step to `install.sh` that walks
   `omz-custom/{themes/dragon/**/*.zsh,plugins/mo-*/*.plugin.zsh,lib/*.zsh}`
   and emits `.zwc` siblings. OMZ already prefers `.zwc` over `.zsh`. Make
   it incremental (skip if `.zwc` is newer than source).

5. **`compinit` is called by OMZ without an explicit cache check.** A
   `compinit -C` (with daily reset) saves 50-100ms on every cold shell start.

   **Fix:** Document the OMZ-blessed way to opt in (e.g. set
   `ZSH_DISABLE_COMPFIX=true` and call `compinit -C` from `zshrc.master-oogway`
   before sourcing OMZ).

A documented **shell-startup budget** ("cold open < 200ms on a modern x86_64
laptop, < 500ms on a Raspberry Pi 4") plus a `master-oogway benchmark`
command and a CI gate (HIGH-1) would prevent regression.

### HIGH-3 — No plugin manifest beyond `requirements.zsh`/`optional-deps.zsh`
**Files:** every `omz-custom/plugins/mo-*/`.

Plugin metadata today is:

- Folder name (= plugin name).
- A one-line `# Provides:` comment, sometimes (e.g. `mo-lan-ssh.plugin.zsh:1-8`).
- A `requirements.zsh` (8 of 25 plugins) and/or `optional-deps.zsh` (8 of 25
  plugins).
- A `README.md` table.

There is no machine-readable description, version, capabilities list,
conflicts list, or owner. When `mo-projects` and `mo-lan-ssh` both register
host aliases, only convention (file ordering in `zshrc.master-oogway:163-196`)
keeps them from colliding.

**Recommended fix:** Add `plugin.meta.zsh` to every plugin, parsed by a
loader in `install.sh` (and a runtime `master-oogway plugins` subcommand):

```zsh
# omz-custom/plugins/mo-lan-ssh/plugin.meta.zsh
typeset -gA MO_PLUGIN_META=(
    [name]="mo-lan-ssh"
    [version]="1.4.0"
    [description]="Auto-discover LAN SSH hosts, register bare-name aliases, manage ssh_config"
    [category]="additive"
    [requires]="git ssh"
    [recommends]="nmap dig arp-scan"
    [conflicts]=""
    [provides_aliases]="dynamic:<hostname-or-s-prefix>"
    [provides_functions]="mo-lan-ssh _mo_lan_*"
    [writes]="~/.config/master-oogway/lan-hosts ~/.ssh/config.d/lan-hosts"
    [reads_env]="MO_LAN_TTL MO_LAN_SSH_PORTS MO_LAN_PROBE_TIMEOUT MO_LAN_PROBE_PARALLEL MO_LAN_EXCLUDE MO_LAN_VERBOSE MO_LAN_AUTO_TRUST MO_LAN_SUBNET MO_LAN_DNS_SERVER MO_LAN_DNS_ZONE"
    [maintainer]="tomershay100"
)
```

This pays off immediately as:

- `master-oogway plugins list` — show installed + version + status.
- `master-oogway plugins disable mo-lan-ssh` — comment it out in `~/.zshrc`
  reproducibly.
- `master-oogway plugins doctor mo-lan-ssh` — re-check `requires` and
  `recommends` for this one plugin.
- Conflict detection: `mo-projects` declares
  `[provides_aliases]="dynamic:<project-name>"` and the loader can warn at
  shell start when a dynamic alias from `mo-projects` would shadow one from
  `mo-lan-ssh` (and vice versa).
- Better doc generator: a CI step can read every `plugin.meta.zsh` and
  regenerate the README plugin tables — eliminating drift between
  `README.md` and the actual `plugins=()` array (a real risk today, see
  LOW-3 in §7).

### HIGH-4 — Prompt is rebuilt from scratch on every keypress
**Files:** `omz-custom/themes/dragon/parts/lifecycle.zsh:7-13`,
`omz-custom/themes/dragon/parts/prompt.zsh:9-130`,
`omz-custom/themes/dragon/parts/gitstatus.zsh:14-21`.

`__refresh_prompt` (called from the gitstatus callback) calls
`dragon__set_lprompt` and `dragon__set_rprompt` — both of which iterate
*every* segment unconditionally and re-render via `__dragon__show`:

```zsh
# parts/lifecycle.zsh
__refresh_prompt()
{
    dragon__set_lprompt   # rebuilds username, hostname, dir, prompt_char, ssh_prefix, ...
    dragon__set_rprompt   # rebuilds exit_status, ssh_conn, jobs, exec_timer, datetime
    zle reset-prompt 2>/dev/null
}
```

`%n` (username), `%m` (hostname), `$SSH_PREFIX`, `$DRAGON__USER_HOST_SEPARATOR`,
`$DRAGON__USERNAME_BACKGROUND_COLOR` — none of these change between two
keystrokes in the same directory in the same session. The work of
computing the `STYLE_FORMAT` string (3-5 forks worth of `tput`-equivalent
ANSI assembly per segment) is repeated every time gitstatus fires.

**Fix:** Memoize per-segment output keyed by `(PWD, SSH state, segment vars)`.
A simple `typeset -gA _DRAGON_SEG_CACHE` and an invalidation hook on `chpwd`
+ `__dragon_track_chpwd` would cut work to "rebuild only the rprompt clock"
between two prompts in the same directory. Estimated saving: 5-15ms per
keystroke on a slow shell; cumulatively this matters for users typing
quickly.

### HIGH-5 — No theme registry — `dragon` is hardcoded in two places
**Files:** `zshenv.master-oogway:55` (`ZSH_THEME="dragon"`),
`zshrc.master-oogway:131-135` (gitstatus pre-source comment hardcodes
"dragon").

The repo *says* it ships a "dragon theme" but the architecture binds the
framework to a single theme. There is no `omz-custom/themes/<other>/` that
also benefits from `dragon-configure`-style schema + presets + SSH
forwarding + transient prompt.

**Fix:** Split "framework" from "theme":

- Move shared infrastructure (schema, configure, notifier, presets loader,
  set-if-unset loop) to `omz-custom/lib/mo-theme/`.
- Make `dragon/` a *consumer* of that lib.
- Document how a contributor adds a parallel theme (`obsidian/`, `slate/`,
  `serif/`) that reuses the wizard + SSH forwarding + transient prompt
  machinery.

This unlocks the marketplace play in §22.

### HIGH-6 — `please()` evaluates a reconstructed pipeline
**File:** `omz-custom/plugins/mo-shell-tools/mo-shell-tools.plugin.zsh:125-202`.

`please()` reads the last command from `fc -ln -1`, tokenizes via `${(z)}`,
identifies the first binary-or-builtin segment, prepends `sudo` to it, and
re-assembles the pipeline with `${(j: | :)out_segments}`. Final line:

```zsh
eval "$pipeline"
```

The reconstruction is *largely* sanitised (it accepts only segments whose
leading word is a binary or builtin; rejects functions, aliases, unknowns)
but `eval` of a reconstructed string is a permanent footgun. A malicious
file/path/argument with shell-metachars that survives the round-trip can be
re-interpreted differently than the original. The current rejection of
`function`/`alias`/`none` reduces but does not eliminate the surface.

**Recommended fix:**

- Detect simple commands vs. pipelines (already done) — for simple commands
  exec `sudo "${cmd[@]}"` (also already done — good).
- For pipelines, prefer `sudo zsh -c "$pipeline"` with a single argv-passed
  string rather than `eval`. The semantics are similar (one shell parse
  cycle), but the surface is smaller and there's a clearer audit point.
- Even better: print the reconstructed pipeline first and ask the user to
  confirm (`Run as: sudo cmd | other | another  [y/N]`). For interactive
  use this is the right call; the cost is one extra keystroke for the
  power user, the win is "no surprise sudo on a misparsed pipeline."

### HIGH-7 — `MASTER-OOGWAY-AUDIT.md` is deleted but PROD-equivalent docs are not yet shipped
**Files:** git status shows `D MASTER-OOGWAY-AUDIT-2.md`.

The recent in-tree audit was resolved and (presumably) removed once items
were merged. That history now lives only in commit messages. Users browsing
the repo learn nothing about the security boundaries the audit exposed
(LAN-trust model, please-eval reasoning, etc.). This document (PROD.md) is
the replacement; it should be kept in-tree and updated each release.

---

## 6. Medium priority improvements

### MED-1 — `compinit` is not cache-gated
**Files:** OMZ default; not explicitly overridden in `zshrc.master-oogway`.

OMZ runs `compinit -d "$ZSH_COMPDUMP"` somewhere in its bootstrap. A common
fast pattern is:

```zsh
autoload -Uz compinit
if [[ -n "${ZSH_COMPDUMP}"(N.mh+24) ]]; then
    compinit -d "$ZSH_COMPDUMP"
else
    compinit -C -d "$ZSH_COMPDUMP"
fi
```

i.e. "fully rebuild the dump once per day, skip security check otherwise."
Saves 30-150ms on warm starts. Document the right place to inject this for
master-oogway users.

### MED-2 — No per-segment async rendering
**Files:** `omz-custom/themes/dragon/parts/segments_left.zsh:97-115`,
`omz-custom/themes/dragon/parts/gitstatus.zsh`.

Only the *git* segment is async (via gitstatus). All other segments are
synchronous on the precmd path. The SSH connection count
(`__set_ssh_connection_count_content`) runs `who` and parses its output
*every* prompt. This is cheap, but it's an obvious place to demonstrate
the async pattern for future heavy segments (k8s context, AWS profile,
docker context, etc.).

**Fix:** Generalize `gitstatus.zsh`'s pattern (background work → callback
→ `zle reset-prompt`) into a `parts/async.zsh` helper:

```zsh
__dragon_async_segment <name> <command>
# spawns command in background, writes result to _DRAGON_ASYNC[$name],
# triggers __refresh_prompt on completion.
```

### MED-3 — Subshell command-substitution in `_mo_xterm_to_rgb` is called dozens of times per prompt
**Files:** `omz-custom/plugins/mo-color/mo-color.plugin.zsh:7-26`,
`omz-custom/themes/dragon/parts/helpers.zsh:1-19`.

`_mo_xterm_to_rgb` is pure-zsh arithmetic — no forks. Good. But it's called
via `< <(_mo_xterm_to_rgb "$idx")` (process substitution!) from many call
sites in `mo-color.plugin.zsh:38, 50, 60, 99, 113, 188, 201, 215, 305`. Each
process substitution forks a subshell. The color palette / picker is
interactive, so it doesn't matter there. But the same pattern in the prompt
hot path would cost a fork per segment.

**Fix:** Convert `_mo_xterm_to_rgb` to write to global variables
(`_MO_COLOR_R`, `_MO_COLOR_G`, `_MO_COLOR_B`) and have callers read those
globals directly — the same idiom `__get_xterm_color_by_name` already uses
in `parts/helpers.zsh`. This eliminates all process substitutions in
`mo-color`.

### MED-4 — Theme presets duplicate every variable
**Files:** every `omz-custom/themes/dragon/presets/*.conf.zsh`.

There is no inheritance. `dracula.conf.zsh` and `catppuccin-mocha.conf.zsh`
both re-declare every variable, even when most are the schema defaults. Adding
a new theme variable means manually updating 26 preset files (or implicitly
relying on the schema default — fine for new vars, but means presets drift
silently from "what was intended in 2026-05" toward "whatever the default
became").

**Fix:** Allow a preset to declare `_DRAGON_PRESET_INHERITS_FROM=catppuccin-mocha`
at the top and source the parent before applying overrides. Reduces preset
size by ~70% and keeps the "what is this preset really overriding?" question
answerable.

### MED-5 — `serve` exposes 0.0.0.0 with a warning only
**File:** `omz-custom/plugins/mo-network/mo-network.plugin.zsh:7-23`.

`SERVE_BIND=0.0.0.0 serve` exposes the current dir over HTTP to the LAN.
The function prints a warning but proceeds. On a coffee-shop wifi this is a
significant footgun.

**Fix:** Require an explicit `--public` flag when `SERVE_BIND != 127.0.0.1`,
and refuse to bind to 0.0.0.0 unless the user opts in twice (env var **and**
flag). The protective ratchet matches the threat model.

### MED-6 — `mo-lan-ssh` auto-trust is on by default
**File:** `omz-custom/plugins/mo-lan-ssh/_mo_lan_trust.zsh:67-100`.

When a LAN host's host key changes (TOFU breakage — a real MITM signal on
untrusted networks), the wrapper unconditionally runs `ssh-keygen -R
"$target_host"` and re-probes. The reasoning is documented in the file:
"LAN host: trusted." This is a defensible default *for the maintainer's
home/office LANs*, but the default for *strangers downloading this
framework* should be the safe one.

**Fix:**

- Flip the default: `MO_LAN_AUTO_TRUST=false` ships off.
- Make the wizard (or `master-oogway doctor`) ask once: "Trust your LAN for
  SSH host-key changes? [y/N]" and persist the answer.
- Document `MO_LAN_AUTO_TRUST` and its consequences in the security section.

### MED-7 — `dragon-configure --gallery` writes to terminal but doesn't allow selection
**File:** `omz-custom/themes/dragon/configure.zsh:870-878`.

`--gallery` prints every preset stacked. To *apply* a preset, the user
re-runs with `--preset <name>`. A TUI selector (fzf-driven or
arrow-key-driven, similar to `mo-color pick`) would close the loop:

```
dragon-configure --pick    # opens TUI gallery, hits Enter on a preview
                           # to apply that preset
```

The infrastructure (`_dragon_render_preview`, `_DRAGON_PRESET_NAMES`,
keypress reader `_dragon_read_key`) is already in place.

### MED-8 — No `master-oogway doctor` / health-check subcommand
**File:** `omz-custom/plugins/mo-cli/mo-cli.plugin.zsh`.

Users who hit a broken state today have to reason from `dragon`'s yellow
warnings, the install.sh todo list, plus the optional-deps report. Consolidate
into `master-oogway doctor`:

```
$ master-oogway doctor
[✓] master-oogway 2026-05-25-29bac67 — installed
[✓] oh-my-zsh present (~/.oh-my-zsh)
[✓] dragon theme loaded (ZSH_THEME=dragon)
[✓] gitstatus daemon healthy (PID 12345)
[✗] zsh-syntax-highlighting submodule missing — run install.sh to fix
[!] optional: ripgrep not installed (mo-search/frg disabled)
[!] dragon: 3 new vars since last configure — run dragon-configure --new-only
[✓] ~/.ssh/config Include line present
[✓] /etc/ssh/sshd_config AcceptEnv DRAGON__* present
[!] LAN auto-trust enabled (MO_LAN_AUTO_TRUST=true) — see PROD.md §6
```

### MED-9 — No `master-oogway benchmark` / startup profiler
**File:** none.

There is no built-in way to answer "is my prompt slow because of master-oogway
or because of something I added in `custom-zsh/`?" A canonical pattern is:

```zsh
# master-oogway benchmark
zsh -ic 'zmodload zsh/zprof; source $ZSH/oh-my-zsh.sh; zprof' | head -30
zsh -i -c exit  # 5 runs, drop slowest, average the rest
```

Combined with HIGH-2's budget, this gives users an actionable answer.

### MED-10 — Override plugins are not symmetrically toggleable
**Files:** `omz-custom/plugins/mo-{eza,bat,nvim,colorize,safety}-override/`,
`mo-trash/`.

To disable an override the user must comment its line out in
`~/.zshrc:162-167`. There is no `master-oogway disable mo-bat-override`. With
the manifest from HIGH-3 in place this becomes trivial.

### MED-11 — `_dragon_THEME_DIR` is `readonly` after the first source
**File:** `omz-custom/themes/dragon/aliases.zsh:6`:
`typeset -gr _DRAGON_THEME_DIR="${0:a:h}"`.

This is the right call defensively, but it bites in dev mode: re-sourcing
`aliases.zsh` via `soursh` after editing it raises a "read-only variable"
error. The current code path masks it (the same line is run idempotently
inside `reset_theme_variables` only via `source` of `schema.zsh`, not
`aliases.zsh`), but a future contributor adding a re-source will hit it.

**Fix:** Either move the `readonly` declaration into a guarded block:

```zsh
[[ "${(t)_DRAGON_THEME_DIR}" == *readonly* ]] || typeset -gr _DRAGON_THEME_DIR="${0:a:h}"
```

or drop the `readonly` modifier and document why it's a normal global.

### MED-12 — `gitstatus_query` callback handles errors with `2>/dev/null`
**File:** `omz-custom/themes/dragon/parts/lifecycle.zsh:13`:
`zle reset-prompt 2>/dev/null`.

Hiding stderr here is intentional (zle isn't always available outside ZLE
context), but it suppresses *every* class of error including legitimate
ones. A better idiom:

```zsh
if zle -L 2>/dev/null; then zle reset-prompt; fi
```

This only invokes `reset-prompt` when zle is in an interactive widget
context. The `2>/dev/null` is removed, and any genuine error surfaces.

### MED-13 — `mo-projects` registers aliases for every directory in `$projects_dir`
**File:** `omz-custom/plugins/mo-projects/mo-projects.plugin.zsh:31`.

This registers a *namespace-eating* set of aliases at every shell start. A
project called `ls`, `cd`, `git`, or `find` *would* be skipped (the function
checks for prior bindings) — good. But a project called `private`,
`secret`, or `personal` becomes a top-level command. This is more "namespace
hygiene" than "security" but is non-obvious for users who later create such
a directory and wonder why typing `private` cds into a folder.

**Fix:** Either:

- Require an opt-in marker file (`.mo-project`) per directory before
  aliasing it.
- Show the list (`mo-projects list`) at first install via the todo system,
  so the user is aware of the surface.

### MED-14 — `_dragon_load_current_conf` accepts both single- and double-quoted formats
**File:** `omz-custom/themes/dragon/configure.zsh:78-115`.

The double-quoted reader path is kept for legacy conf files written before
2026-05-16. After 6 months the chance of an unmigrated user is small;
keeping both readers extends the security surface (the double-quoted
re-parse uses `\\\"` and `\\\\` unescaping that has subtly different
semantics than zsh's own parser).

**Fix:** Detect double-quoted lines, emit a *one-shot* migration: read,
re-emit, replace. After one wizard run the file is in the canonical
single-quoted form and the legacy reader can be removed.

### MED-15 — `dragon-configure --diff` doesn't show *added* / *removed* vars separately
**File:** `omz-custom/themes/dragon/configure.zsh:881-947`.

When a preset adds a variable that the user's current config never set (or
vice versa) the diff treats both sides as the schema default. Visually this
is correct, but it makes it impossible to distinguish:

1. "the preset overrides this var to its default" vs.
2. "neither side has this var, both use the schema default."

A `--verbose` mode that annotates `(both at default)` and `(preset adds:
X)` improves comprehension for power users.

---

## 7. Low priority improvements

### LOW-2 — `mo-search`'s `grep()` function shadows the system `grep` globally
**File:** `omz-custom/plugins/mo-search/mo-search.plugin.zsh:24-26`.

`unalias grep 2>/dev/null` followed by a function definition. Wrapping
`grep` to add `--color=auto` is fine for interactive use; the function is
careful (`command grep ...`) so it doesn't recurse. Power users wiring scripts
that source `~/.zshrc` may be surprised.

**Fix:** Restrict to an alias rather than a function:
`alias grep="command grep --color=auto --exclude-dir={.bzr,...} --exclude={...}"`.

### LOW-3 — Plugin README table in main README is hand-maintained, drift-prone
**File:** `README.md:33-62`.

25 rows, each a markdown link to a plugin README, alphabetised by hand. Drift
risk: a new plugin can be added to `zshrc.master-oogway` without a row here.
With manifest (HIGH-3) in place, generate the table.

### LOW-4 — `LICENSE` content is not in scope of this audit but should be MIT
**File:** `LICENSE` (1.1k bytes — content not read).

Verify it's MIT (or whatever the README implies) and that the year is
current.

### LOW-6 — `mo-cli`'s `diff-zshrc` doesn't auto-detect `delta`/`diff-so-fancy`
**File:** `omz-custom/plugins/mo-cli/mo-cli.plugin.zsh:46-53`.

Three-tier fallback (`tool` arg → git config → `diff -u`). Adding `delta`
or `diff-so-fancy` as a detected tier when the user has them installed would
be a small UX improvement.

### LOW-7 — `mo-welcome` `_mo_welcome_field_ip` always probes `1.1.1.1`
**File:** `omz-custom/plugins/mo-welcome/mo-welcome.plugin.zsh:34-38`.

`ip route get 1.1.1.1` is fine even on disconnected machines (it computes
the route without sending packets) but visually mentions a Cloudflare IP
in the source. A comment explaining why is worth adding; some users
auditing the code will pause on it.

### LOW-8 — `mo-color pick` requires 70×23 terminal, prints an error otherwise
**File:** `omz-custom/plugins/mo-color/mo-color.plugin.zsh:234-237`.

Document this in `mo-color/README.md` (currently it surfaces only as a
runtime error).

### LOW-9 — `_mo_lan_extract_target` parses only single-letter ssh flags
**File:** `omz-custom/plugins/mo-lan-ssh/_mo_lan_trust.zsh:23-25`.

The `-[BbcDEeFIiJLlmOoPpRSWwQ]` regex handles the standard set. Multi-arg
ssh options like `-o ConnectTimeout=30` work because `-o` is treated as
value-taking. But `--`, `-4`, `-6`, `-A`, `-a` etc. aren't matched (most
are flags without values, so falling through to `-*) ;;` is correct). The
implementation is essentially OK but deserves a comment explaining the
matrix.

### LOW-10 — `mo-shell-tools` `please` shows no preview before sudo
**See HIGH-6.**

### LOW-11 — `mo-trash` uses `command trash-empty` for prune (with --trash-dir)
**File:** `omz-custom/plugins/mo-trash/mo-trash.plugin.zsh:64`.

`trash-empty --trash-dir=$MO_TRASH_DIR $days` — the positional `$days`
argument's semantics are tool-specific. Document the dependency on
`trash-cli` version (works on 0.22.x; older versions parse arguments
differently).

### LOW-12 — `mo-files`'s `extract` refuses to merge into existing dir
**File:** `omz-custom/plugins/mo-files/mo-files.plugin.zsh:42-44`.

Safe default. Some users will want a `--force-merge` flag; deferrable.

### LOW-13 — `mo-network` `sshto` recursively follows Include directives but with no depth cap
**File:** `omz-custom/plugins/mo-network/mo-network.plugin.zsh:36-50`.

`_seen` prevents loops, so depth is bounded by config-file count. Fine in
practice; a hard depth cap of 16 would prevent pathological misuse.

### LOW-14 — Long files would benefit from splitting
**Files:** `configure.zsh` (1097 LOC), `mo-color.plugin.zsh` (379 LOC),
`mo-lan-ssh.plugin.zsh` (577 LOC).

Not bad code — but past 500 LOC a single file in a shell framework starts
to deter contributors. `configure.zsh` could split into
`configure.{state,preset,wizard,writer,export,gallery,diff}.zsh`. Same for
the others (`mo-lan-ssh.{loader,cli,validators}.zsh`).

### LOW-15 — `set -Eeuo pipefail` is in `install.sh` but not in all `.zsh` plugins
**Files:** every plugin.

`emulate -L zsh; setopt err_return no_unset pipe_fail` (the zsh equivalent)
appears only in `_mo_lan_discover.zsh:12-13`. Other plugins rely on the
ambient interactive-shell options. Document the convention: which plugins
need it (background scripts), which don't (interactive plugins), and why.

---

## 8. Architecture analysis

### 8.1 Load order (verified from `zshrc.master-oogway`)

```
~/.zshenv              # 25 LOC, EDITOR only
   ↓
~/.zshrc (master-oogway:managed)
   ↓
typeset -U path                                      # dedupe PATH
locale fallback                                      # UTF-8 with C.UTF-8 fallback
history settings                                     # 100k, share, ignore-space
shell behavior setopts                               # 13 setopts
oh-my-zsh env vars (ZSH, ZSH_THEME, ZSH_CUSTOM, ...) #
completion setopts + zstyle                          # 6 lines
[[ -f conf.zsh ]] && source conf.zsh                 # SSH-forwarded short-circuits here
custom-pre-zsh/*.zsh                                 # user pre-plugin extension dir
plugin tuning env vars                               # autosuggest/syntax/ysu/history-substring
source gitstatus.plugin.zsh                          # MUST be before OMZ
plugins=(...26 entries...)
source $ZSH/oh-my-zsh.sh                             # OMZ bootstrap (compinit, source plugins)
   ↓
custom-plugins/*/<name>.plugin.zsh                   # user plugin extension dir
custom-zsh/*.zsh                                     # user post-plugin extension dir
LESS env var
arrow-key bindings (history-substring-search)
ctrl+arrow word jumps
```

### 8.2 Why gitstatus is sourced *before* OMZ

Comment on `zshrc.master-oogway:130-131`: "must be sourced before oh-my-zsh
(it replaces the built-in vcs_info)." `gitstatus.prompt.zsh` is a no-op for
master-oogway *unless* the dragon theme calls `gitstatus_start` and
`gitstatus_query` — both of which it does via `parts/gitstatus.zsh`. The
pre-source ensures the `gitstatus_*` functions exist by the time
`dragon.zsh` evaluates `(( $+functions[gitstatus_query] ))` at source time.

This *would* be problematic if OMZ's vcs_info ran first; the pre-source
makes it a no-conflict.

### 8.3 Why zsh-syntax-highlighting is sourced *last*

Documented inline (`zshrc.master-oogway:139-145`): syntax-highlighting wraps
every ZLE widget, so widgets defined after it (`sudo`, `fzf`,
`history-substring-search`, anything in `custom-zsh/`) wouldn't be wrapped.
The `plugins=()` array enforces this — anything added in
`~/.config/master-oogway/custom-plugins/` is sourced *after* the array, so
its widgets are *also* not wrapped. A subtle gotcha: user plugins that
define ZLE widgets need to re-call
`_zsh_highlight_bind_widgets` or accept un-highlighted commands.

**Action:** Document this in `CONTRIBUTING.md` and offer a snippet in
`custom-zsh/`'s README for user plugins that define widgets.

### 8.4 Theme rendering data flow

```
keypress arrives in ZLE
     ↓
gitstatus daemon notices working tree change (or is queried by __update_prompt)
     ↓
gitstatus_query callback: __refresh_prompt
     ↓
dragon__set_lprompt:
     ssh_prefix  → username  → user_host_sep  → hostname  → host_dir_sep  → dir
     dragon__set_git_prompt (uses VCS_STATUS_* from gitstatus)
     multiline transitions (if enabled)
     prompt_char
     ↓
dragon__set_rprompt:
     exit_status → ssh_conn → jobs → exec_timer → date_time
     ↓
PROMPT, RPROMPT strings assigned
     ↓
zle reset-prompt
     ↓
ZLE redraws prompt
```

The pipeline is clean. The performance opportunity is per-segment memoization
(HIGH-4) and the architectural opportunity is async-segment generalization
(MED-2).

### 8.5 Why `set_if_unset` instead of plain assignment in `dragon.zsh`

`dragon.zsh:37-40`:

```zsh
for _dragon_k _dragon_v in "${(@kv)_DRAGON_DEFAULTS}"; do
    [[ "$_dragon_k" == "USE_NERD_FONT" ]] && continue
    set_if_unset "DRAGON__${_dragon_k}" "$_dragon_v"
done
```

This is the **SSH forwarding contract**: a forwarded `DRAGON__*` env var
from the client is *already exported* by the time `dragon.zsh` runs; the
defaults loop must not clobber it. `set_if_unset` (defined at the top of
`dragon.zsh`) checks `[[ ! -v "$var_name" ]]` and only sets if unset.

This is the single most important design call in the theme. It ensures the
dragon prompt **looks identical** on every machine in your fleet without
syncing conf files — only the host changes via `%m` and SSH-mode color
overrides.

`USE_NERD_FONT` is excluded from this loop because its default *depends
on context* (true locally, false over SSH) — see `dragon.zsh:31-35`.

### 8.6 Conf-file SSH forwarding guard

`configure.zsh:572-573` (inside the conf.zsh header):

```zsh
[[ "${DRAGON__FORWARDED:-}" == "1" ]] && return
export DRAGON__FORWARDED=1
```

On the sending machine, sourcing `conf.zsh` exports `DRAGON__FORWARDED=1`.
SSH carries it via `SendEnv DRAGON__*`. On the receiving machine, `conf.zsh`
sees `DRAGON__FORWARDED=1` and returns immediately — *the receiver's
conf.zsh does not run*. The receiver still goes through `dragon.zsh`'s
`set_if_unset` loop, but every `DRAGON__*` is already set, so every
`set_if_unset` is a no-op. Result: the receiver renders with the sender's
config.

Subtle. Worth a diagram in the architecture docs.

---

## 9. ZSH performance review

### 9.1 Cold-start cost (estimated)

No measurements exist in-tree. Eyeball estimate, based on plugin source
analysis:

| Component | Cost (eyeball, ms) | Notes |
|---|---|---|
| zsh + zshenv | 5 | locale fallback runs `LC_ALL=en_US.UTF-8 locale charmap` — 1 fork |
| zshrc up to OMZ source | 5 | typeset, setopts, zstyle, conf.zsh source |
| OMZ bootstrap | 50-80 | compinit + 8 OMZ plugins (sudo, ysu, colored-man-pages, colorize, command-not-found, fzf, history-substring-search, you-should-use) |
| dragon theme load | 30-60 | schema → defaults → 8 parts → hooks; SSH detection forks once |
| 25 mo-* plugins | 80-150 | dominated by command-v checks (10+ per plugin) and a few `grep -c /proc/cpuinfo` forks |
| zsh-autosuggestions | 5 | |
| zsh-syntax-highlighting | 20-40 | widget wrap |
| Total cold start | **~200-350ms** | very rough; needs real `master-oogway benchmark` |

A typical "feels instant" budget is 100ms. master-oogway is plausibly at
2-3× that, which is high for a framework. Real measurement is HIGH-2.

### 9.2 Per-keystroke cost (estimated)

Same caveat. With zsh-autosuggestions async (`ZSH_AUTOSUGGEST_USE_ASYNC=1`)
and gitstatus async, the per-keystroke critical path is:

- syntax-highlighting wrap walk over BUFFER — fast, microseconds.
- autosuggest fetch — async, returns to prompt fast.
- prompt re-render on every command completion — see HIGH-4.

The per-keystroke cost is dominated by autosuggest + syntax-highlighting,
both vendored — not the master-oogway code.

### 9.3 Concrete optimization patches

**Patch 1 — Eliminate `grep -c '^processor' /proc/cpuinfo`.**

```zsh
# mo-build/mo-build.plugin.zsh:4 — before
_mo_build_jobs=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null)

# after — zero forks
_mo_build_jobs=${$(< /proc/cpuinfo):#processor*}  # nope — wrong direction
# correct:
() {
    local -a cpus=( ${(@f)"$(< /proc/cpuinfo)"}:#processor*)
    _mo_build_jobs=${#cpus}
}
# even simpler:
_mo_build_jobs=$(nproc 2>/dev/null) || _mo_build_jobs=1
```

`nproc` is in coreutils; binary fork but no grep.

**Patch 2 — Cache `command -v` results at framework load.**

```zsh
# omz-custom/lib/optdeps.zsh (new file)
typeset -gA _MO_OPT_BIN=()
_mo_detect_optdeps() {
    local tool
    for tool in fzf bat batcat fd fdfind rg eza colormake banner \
                wl-copy xclip nvim trash-put pandoc xelatex \
                lsof pgrep arp-scan nmap dig 7z unrar zstd; do
        if (( $+commands[$tool] )); then
            _MO_OPT_BIN[$tool]=1
        fi
    done
}
_mo_detect_optdeps
```

Then plugins use `(( $_MO_OPT_BIN[bat] ))` instead of
`command -v bat &>/dev/null`. Saves an exec per check — across 25 plugins
this is plausibly 50-100ms cold start.

**Patch 3 — `zcompile` step at install time.**

```bash
# install.sh — after _init_plugins
_zcompile_all() {
    local f
    for f in "${INSTALL_DIR}"/omz-custom/themes/dragon/*.zsh \
             "${INSTALL_DIR}"/omz-custom/themes/dragon/parts/*.zsh \
             "${INSTALL_DIR}"/omz-custom/lib/*.zsh \
             "${INSTALL_DIR}"/omz-custom/plugins/mo-*/*.plugin.zsh; do
        [[ -f "$f" ]] || continue
        [[ -f "$f.zwc" && "$f.zwc" -nt "$f" ]] && continue
        zsh -c "zcompile '$f'" 2>/dev/null
    done
}
```

OMZ automatically prefers `.zwc` over `.zsh`. Incremental — re-runs of
`install.sh` skip already-compiled files.

**Patch 4 — Memoize static prompt segments.**

See HIGH-4 detail. Sample sketch:

```zsh
typeset -gA _DRAGON_SEG_CACHE=()

__dragon_seg_cached() {
    local name="$1" key="$2"
    if [[ -n "${_DRAGON_SEG_CACHE[$name:$key]:-}" ]]; then
        echo -E "${_DRAGON_SEG_CACHE[$name:$key]}"
        return
    fi
    local rendered
    rendered=$("__set_${name}" 2>/dev/null)   # or call directly
    _DRAGON_SEG_CACHE[$name:$key]="$rendered"
    echo -E "$rendered"
}

__dragon_track_chpwd() {
    _DRAGON_JUST_CHANGED_DIR=true
    # Invalidate segments that depend on PWD
    unset "_DRAGON_SEG_CACHE[directory:*]"
}
```

**Patch 5 — Skip `_check_zshrc_drift` when nothing changed.**

`install.sh:550-568` runs `diff -q template snapshot` every install. Cheap
but unnecessary when the user hasn't installed since the last `git pull`.
Stash a `template_sha` in the state file; skip the diff when it matches.

### 9.4 Profiling story for users

Document `master-oogway benchmark` (MED-9) and `master-oogway profile`:

```
$ master-oogway profile
# runs zprof inside a fresh interactive zsh; prints top 20 entries
# saves a /tmp report and opens it
```

### 9.5 Performance regression CI

Once HIGH-1 (CI) is in, add a perf job:

```yaml
perf:
  runs-on: ubuntu-24.04
  needs: lint
  steps:
    - checkout & install (as smoke)
    - run: |
        for i in $(seq 5); do
          { time zsh -ic exit; } 2>> /tmp/times.txt
        done
        avg=$(awk -F 'm|s' '/real/ {sum+=$2*60+$3} END {print sum/NR*1000}' /tmp/times.txt)
        echo "Average cold-start: ${avg}ms"
        # Fail if > budget (e.g. 400ms on CI, with margin)
        [ "$(echo "$avg < 400" | bc)" = "1" ]
```

---

## 10. Plugin architecture review

### 10.1 Today

- **Discovery:** plugins are listed in the `plugins=()` array in
  `zshrc.master-oogway`. Order matters (`zsh-syntax-highlighting` last,
  override-before-additive).
- **Dependencies:** two-tier (hard `requirements.zsh` vs soft
  `optional-deps.zsh`). The convention is documented in `CONTRIBUTING.md:226-230`.
- **Naming:** every first-party plugin is `mo-<name>`. Override plugins are
  `mo-<name>-override`. No formal registry.
- **Isolation:** plugins share the same shell. Globals are namespaced by
  convention (`_MO_*`, `MO_*`, `DRAGON__*`). No sandbox.
- **Lifecycle:** none. Plugins are sourced once at OMZ load; there's no
  `unload`, `reload`, `pre_load`, `post_load`.

### 10.2 Concrete plugin-architecture problems

1. **Dynamic-alias collisions are unobservable.** `mo-projects` and
   `mo-lan-ssh` both register dynamic host/project aliases at shell start.
   Each individually checks `_mo_name_conflicts` / equivalent; the cross-plugin
   case ("`mo-projects` defined `foo` then `mo-lan-ssh` would define `foo`
   too") is handled implicitly via array ordering in `zshrc.master-oogway`,
   not via a declared dependency.

2. **No "this plugin loaded successfully" signal.** When
   `requirements.zsh` returns 1 the plugin doesn't load — and the user gets
   a yellow warning. There is no programmatic way to query "are all
   first-party plugins loaded?" — useful for `master-oogway doctor`
   (MED-8).

3. **No version per plugin.** A plugin patch ("`mo-lan-ssh` v1.4 now writes
   `~/.ssh/config.d/lan-hosts` instead of `~/.ssh/config.master-oogway`")
   has no way to advertise itself. Users running an older copy via a stale
   submodule won't know.

4. **No conflict declaration between plugins.** If a future plugin
   `mo-fzf-tab` rebinds Tab, there's no place to declare `[conflicts]="some
   other plugin that also rebinds Tab"`.

### 10.3 Proposed plugin manifest format

(Mirrored from HIGH-3; fleshed out here.)

```zsh
# omz-custom/plugins/mo-<name>/plugin.meta.zsh
typeset -gA MO_PLUGIN_META=(
    [name]="mo-<name>"
    [version]="1.0.0"               # semver, bumped on every breaking change
    [description]="..."              # one sentence, shown in `master-oogway plugins`
    [category]="override|additive|integration"
    [requires]="..."                # space-list of binaries (hard deps)
    [recommends]="..."              # space-list of binaries (soft deps)
    [conflicts]="..."               # space-list of other plugin names
    [conflicts_zsh_var]="..."       # e.g. "PROMPT" if the plugin sets PROMPT
    [provides_aliases]="..."        # static list or "dynamic:<pattern>"
    [provides_functions]="..."      # space-list / pattern
    [provides_commands]="..."       # commands installed to PATH (none for most)
    [reads_env]="..."               # space-list of env vars the plugin honours
    [writes_files]="..."            # space-list of paths the plugin writes
    [writes_user_config]="..."      # paths in ~/.config/master-oogway only
    [writes_outside_config]="..."   # paths outside ~/.config/master-oogway (rare; mo-lan-ssh)
    [maintainer]="@github-handle"
)
```

Loader skeleton (in `omz-custom/lib/mo-loader.zsh`, new file):

```zsh
typeset -gA _MO_LOADED_PLUGINS=()  # plugin → version

_mo_load_plugin() {
    local plugin_name="$1"
    local plugin_dir="${ZSH_CUSTOM}/plugins/${plugin_name}"

    local meta_file="${plugin_dir}/plugin.meta.zsh"
    [[ -f "$meta_file" ]] && source "$meta_file"

    # Conflict check
    local conflict
    for conflict in ${(z)MO_PLUGIN_META[conflicts]:-}; do
        if [[ -n "${_MO_LOADED_PLUGINS[$conflict]:-}" ]]; then
            print -P "%F{yellow}[mo-loader]%f $plugin_name conflicts with already-loaded $conflict — skipping"
            return 1
        fi
    done

    # Hard-dep check (delegate to requirements.zsh if present, otherwise inspect [requires])
    if [[ -f "${plugin_dir}/requirements.zsh" ]]; then
        source "${plugin_dir}/requirements.zsh" || return 1
    elif [[ -n "${MO_PLUGIN_META[requires]:-}" ]]; then
        local tool
        for tool in ${(z)MO_PLUGIN_META[requires]}; do
            if ! (( $+commands[$tool] )); then
                print -P "%F{yellow}[mo-loader]%f $plugin_name requires $tool — plugin not loaded"
                return 1
            fi
        done
    fi

    # Source the actual plugin
    source "${plugin_dir}/${plugin_name}.plugin.zsh" || return 1

    _MO_LOADED_PLUGINS[$plugin_name]="${MO_PLUGIN_META[version]:-unknown}"
    unset MO_PLUGIN_META
}
```

User-facing CLI (extension to `mo-cli`):

```
$ master-oogway plugins list
NAME                  VERSION  CATEGORY     STATUS
mo-auto-ls            1.0.0    additive     loaded
mo-bat-override       1.1.0    override     loaded (bat 0.24.0)
mo-build              1.0.1    additive     loaded
...
mo-search             1.2.0    additive     loaded (fzf 0.46.1; bat, fd, rg present)
mo-ssh-tunnel         1.0.0    additive     loaded

$ master-oogway plugins info mo-lan-ssh
Name:        mo-lan-ssh
Version:     1.4.0
Description: Auto-discover LAN SSH hosts, register bare-name aliases, manage ssh_config
Category:    additive
Requires:    git ssh   — ✓ git 2.43.0 / ✓ ssh OpenSSH_9.6
Recommends:  nmap dig arp-scan   — ✓ dig / ✗ nmap missing / ✗ arp-scan missing
Conflicts:   (none)
Provides:    aliases: dynamic:<hostname-or-s-<hostname>>
             functions: mo-lan-ssh _mo_lan_*
Writes:      ~/.config/master-oogway/lan-hosts
             ~/.ssh/config.d/lan-hosts
Reads env:   MO_LAN_TTL MO_LAN_SSH_PORTS MO_LAN_PROBE_TIMEOUT MO_LAN_PROBE_PARALLEL
             MO_LAN_EXCLUDE MO_LAN_VERBOSE MO_LAN_AUTO_TRUST
Maintainer:  @tomershay100
```

### 10.4 Plugin testing strategy (see also §18)

Each plugin gets a `tests/` directory with `.bats` files:

```
omz-custom/plugins/mo-git/tests/
  groot.bats       # cd to git root; cd to outer root when in submodule
  gsum.bats        # output structure
  fbranch.bats     # branch-name sanitisation
```

CI runs `bats omz-custom/plugins/*/tests/*.bats` on every PR.

---

## 11. Theme system review

### 11.1 Strengths

- **Schema as data, code as consumer.** Adding a new variable is 5 declarations
  in `schema.zsh` + one segment-side read. Documented in
  `CONTRIBUTING.md:251-317`.
- **Wizard self-validates.** `_dragon_write_conf` runs `zsh -n` on the
  generated tmp before mv. Broken configs are never persisted.
- **SSH forwarding works.** `DRAGON__FORWARDED=1` guard pattern is elegant.
- **Truecolor detection at load.** `_MO_TRUECOLOR` is set once based on
  `$COLORTERM`. No per-prompt fork.
- **`--gallery`, `--diff`, `--export`, `--preset`, `--new-only`, `--dismiss`,
  `--version`, `--help`.** Real CLI surface for a theme. Most OSS themes ship
  one flag (or none).

### 11.2 Weaknesses

#### 11.2.1 No theme inheritance for presets

Documented as MED-4. Every preset re-declares variables; adding a global
schema default does not automatically propagate to preset files.

#### 11.2.2 No async-segment generalisation

MED-2. Only `gitstatus` is async. The pattern is hardcoded inside
`gitstatus.zsh`; a `parts/async.zsh` library would let users add a k8s-context
segment, AWS profile, etc., without inventing the plumbing.

#### 11.2.3 Color palette is xterm-256 only

`omz-custom/lib/colors.zsh` defines 17 named colors as xterm-256 indices.
The truecolor escape path is in `mo-color.plugin.zsh` (the *plugin*, not the
*theme library*) — so the theme can't actually produce truecolor without
going through `mo-color`. This is OK in practice (the segment renderer in
`helpers.zsh` outputs `%F{idx}` and lets zsh pick the right escape) but means
themes can't easily declare 24-bit colors.

**Fix:** Add an optional `[VAR_FOREGROUND_COLOR_RGB]="#abcdef"` schema field;
when set, use truecolor escape instead of `%F{idx}`. Falls back to xterm-256
when terminal lacks truecolor.

#### 11.2.4 No accessibility audit per preset

WCAG contrast: `_mo_color_palette` (in `mo-color`) computes luminance for the
color picker's text-on-swatch contrast. The theme's *presets* don't have any
contrast guarantee. `high-contrast.conf.zsh` is the only opt-in.

**Fix:** Add a `dragon-configure --check` flag that walks every active color
pair (e.g. `USERNAME_FOREGROUND_COLOR` on `USERNAME_BACKGROUND_COLOR`) and
warns when WCAG AA fails:

```
$ dragon-configure --check
[!] USERNAME (fg=navy on bg=) — contrast 4.1:1 vs terminal bg, fails WCAG AA (min 4.5)
[✓] HOSTNAME (fg=fuchsia on bg=)
...
3 contrast warnings; 0 errors.
```

#### 11.2.5 No theme catalog UI

`--gallery` is print-only. A TUI selector with live keyboard navigation
(arrow keys to switch preset, Enter to apply) using the same machinery as
`mo-color pick` would be a big DX win. MED-7.

#### 11.2.6 Theme is hardcoded as `dragon`

HIGH-5. Splitting framework from theme unlocks (a) shipping multiple
first-party themes, (b) a marketplace, (c) easier theme testing in CI.

### 11.3 Proposed theme registry layout

```
omz-custom/lib/mo-theme/
  schema.zsh             # schema framework (defaults/types/hints/groups)
  loader.zsh             # set_if_unset, ssh forwarding, etc.
  configure.zsh          # generic wizard (parameterised on schema source)
  notifier.zsh           # generic notifier
  presets.zsh            # preset loader/applier/exporter/differ
  parts/                 # shared rendering primitives (helpers, separators)
omz-custom/themes/
  dragon/
    schema.zsh           # dragon-specific schema (mostly today's contents)
    parts/
      segments_*.zsh
    presets/
      *.conf.zsh
    theme.meta.zsh       # name, version, description, owner
  slate/                 # hypothetical second theme
    schema.zsh
    ...
```

`ZSH_THEME=slate` would Just Work.

### 11.4 Per-terminal compatibility matrix (suggested)

Document, in `omz-custom/themes/dragon/README.md`:

| Terminal | Nerd Font glyphs | Truecolor | Powerline arrows | Notes |
|---|---|---|---|---|
| kitty | ✓ | ✓ | ✓ | recommended |
| alacritty | ✓ | ✓ | ✓ | |
| wezterm | ✓ | ✓ | ✓ | |
| gnome-terminal | ✓ (with NF) | ✓ | ✓ | |
| Terminator | ✓ | ✓ | ✓ | the maintainer's daily driver |
| iTerm2 (macOS) | ✓ | ✓ | ✓ | not officially supported (Linux only) |
| Linux console (tty1) | ✗ | ✗ | ✗ | use `--preset ascii` |
| screen | ✓ | depends | ✓ | with right TERM |
| tmux | ✓ | with `set -g default-terminal "tmux-256color"` | ✓ | |
| ssh into a screen/tmux | ✓ | depends on outer | ✓ | dragon's SSH forwarding still works |

---

## 12. Security review

> Read the entire repo paranoid; surface anything that smells.

### 12.1 Issues addressed already (verified against current code)

- **`eval` in `_dragon_load_current_conf`** — *not present*. The reader is
  regex-based and stores to `_DRAGON_CURRENT` only. Good.
- **`eval` in `extract`** — *not present*. `_mo_extract_zip` pre-scans entries
  with `unzip -Z1` and refuses paths starting with `/` or containing `..` as
  a component. Good.
- **`fzf` preview shell-substitution in `fbranch`** — actively mitigated:
  branches with `$`/`` ` ``/`(`/`)`/`;`/`|`/`&`/`<`/`>`/`"`/`'`/`\` are
  dropped before being fed to fzf. See `mo-git.plugin.zsh:104-115`.
- **`grep`-injection in `_mo_lan_load_caches`** — mitigated: hostnames are
  validated by `_mo_lan_valid_host` before any `grep -qE "^${h}(:.*)?$"`.
- **Marker-wrapped sshd_config edits** — protected against accidental
  partial removal; `sshd -t` runs before reload, with revert on failure.
  See `install.sh:729-735`.

### 12.2 Open issues

#### SEC-1 — `please` re-evaluates a reconstructed pipeline (HIGH-6)

Repeated here for the security index. Mitigations exist (whence-w-based
segment filter, refusing functions/aliases/unknowns), but `eval "$pipeline"`
is still in the code. Severity: HIGH.

#### SEC-2 — `frg` evaluates `EDITOR_LINENO_FMT` user variable
**File:** `omz-custom/plugins/mo-search/mo-search.plugin.zsh:94-97`.

```zsh
if [[ -n "${EDITOR_LINENO_FMT:-}" ]]; then
    local open_cmd="${EDITOR_LINENO_FMT//%f/$file}"
    open_cmd="${open_cmd//%l/$linenum}"
    eval "$open_cmd"
fi
```

`$file` and `$linenum` are user input from fzf — and `$file` is *known* to be
shell-safe (the awk filter at line 75 drops any `$\`(`)`|`&`<>"\\'\\\` chars).
That eliminates command injection. But `EDITOR_LINENO_FMT` itself is a user
env var — a malicious user wouldn't `eval` themselves, but a value of
`rm -rf /; vim +%l %f` would *do exactly that*. Trust boundary: this is
"user shoots own foot" territory, low severity, but the `eval` could be
avoided:

```zsh
local -a cmd=( ${(z)open_cmd} )
"${cmd[@]}"
```

Note that `${(z)}` does its own quote-aware splitting. This keeps the
"separate flag from file from linenumber" capability without `eval`.

Severity: LOW (user-set variable).

#### SEC-3 — `mo-lan-ssh` LAN auto-trust drops host keys on MITM signal (MED-6)

Already covered. Severity: MEDIUM (default-off in fix).

#### SEC-4 — `install.sh --uninstall` shell-quotes `sed` patterns carefully but exposes them to shell expansion
**File:** `install.sh:441, 444, 463, 471`.

`sed -i '/AcceptEnv DRAGON__\*/d' /etc/ssh/sshd_config` is single-quoted so
the `\*` is preserved literally. The remove path is fine. The migration
path (`install.sh:723`):

```zsh
sudo sed -i '/AcceptEnv DRAGON__\*/d' "$sshd_config"
```

Same single-quoted form, safe.

#### SEC-5 — `_mo_lan_extract_target` returns the *first* non-flag arg as target
**File:** `omz-custom/plugins/mo-lan-ssh/_mo_lan_trust.zsh:16-35`.

For `ssh -L 8080:localhost:8080 momo`, target is `momo` ✓. For `ssh -o
"User=admin" momo`, target is `momo` ✓ (handled by `-o` consuming value).
For `ssh -- momo`, target is `--`, then `momo` is the next arg — handled by
`-*) ;;` falling through to `*` on the next iteration. Edge cases:

- `ssh momo cmd here` — target = `momo` ✓ (cmd is consumed as a separate
  arg, but the wrapper has already returned the target on the first iteration
  so the loop is fine).
- `ssh -F /custom/config momo` — `-F` takes a value, listed in
  `-[BbcDEeFIiJLlmOoPpRSWwQ]`. Target = `momo` ✓.
- `ssh +X momo` — invalid argv; ssh emits its own error. Wrapper falls
  through to `command ssh` which does the same.

No security issue. Severity: INFO.

#### SEC-6 — `_dragon_render_preview` runs `zsh -c "..."` with interpolated content
**File:** `omz-custom/themes/dragon/configure.zsh:187-214`.

The argument is a *fixed* multi-line shell script with three interpolations:
`${ssh_mode}`, `${preview_exit_code}`, and `${transient_mode}`. All three
come from `for _dragon_flag in "$@"` parsing inside `_dragon_render_preview`
and are either `true`/`false` (set by literal string compare) or `0`/`1`
(integer assignment). Not user-controlled. No injection. Severity: INFO.

#### SEC-7 — `compinit`'s security check is at OMZ's default (delivered by OMZ, not master-oogway)

`compinit` warns about insecure directories on PATH. OMZ delegates to its
own checks. master-oogway doesn't modify them. INFO.

#### SEC-8 — `_install_gitconfig` accepts user-typed name/email
**File:** `install.sh:614-625`.

`read -r git_name < /dev/tty` then `git config --file ... user.name "$git_name"`.
`git config` quotes values internally; injection via newline is the only
risk, and `read` stops at newline. No shell expansion path. Severity: INFO.

### 12.3 Recommended security hardening

1. **Document the threat model.** Currently implicit; needs to be explicit (§13).
2. **Add a `--dry-run` to `install.sh`.** Lets paranoid users review the
   change set without running anything.
3. **Sign release artefacts.** GPG-signed git tags + signed install.sh hosted
   on GitHub Releases (pinned to the tag URL, not `main`).
4. **Pin submodule SHAs.** Commit a `SUBMODULES.lock` file; CI verifies it
   matches `.gitmodules` resolution.
5. **Replace `please`'s `eval` with `sudo zsh -c <argv>` (HIGH-6).**
6. **Replace `frg`'s `eval` with `${(z)}` array expansion (SEC-2).**
7. **Default-off LAN auto-trust (MED-6).**
8. **Require `--public` for `serve` 0.0.0.0 (MED-5).**

---

## 13. Threat model

> Currently this lives only in code comments. PROD.md proposes the
> following be added in-tree as `SECURITY.md` or `docs/threat-model.md`.

### 13.1 Assets

- The user's interactive shell (commands typed, env vars, secrets in
  history).
- The user's `~/.zshrc`, `~/.zshenv`, `~/.gitconfig`, `~/.ssh/config`.
- The user's clipboard (mo-shell-tools `clip`, mo-git `flog`).
- The user's process tree (sudo, ssh, ssh-copy-id).
- The user's SSH known_hosts (mo-lan-ssh `forget`, auto-trust).
- `/etc/ssh/sshd_config` (modified by install with consent).
- `~/.config/master-oogway/` state (preset, dismissed hash, lan-hosts,
  conf.zsh).

### 13.2 Adversaries (in scope)

| Adversary | Capability | In scope? |
|---|---|---|
| Network attacker on user's LAN | Sniff, MITM TLS, ARP-spoof | YES — for `mo-lan-ssh` auto-trust |
| Local user on shared machine | Read `$HOME` of other users | OUT — Linux multi-user perms apply |
| Compromised upstream submodule | Inject code into `gitstatus` etc. | YES — addressed by submodule pinning |
| Compromised GitHub Actions runner | Modify install.sh in flight | YES — addressed by signing |
| Phishing of `curl|bash` URL | Wrong domain | OUT — user choice |
| Malicious project directory | `mo-projects` registers alias for `private` | INFO — see MED-13 |
| Malicious zip/tar archive | Path traversal in `extract` | YES — mitigated, see `mo-files` |
| Maliciously-named git branch | fzf preview shell injection in `fbranch` | YES — mitigated |
| Local privesc via mo-* | Elevate without password | OUT — `please` requires existing sudo |

### 13.3 Adversaries (out of scope, declared)

- A user who can `sudo` themselves does not gain *new* privileges via
  master-oogway. `please` requires the user already has sudo rights.
- A user who already has shell access doesn't gain *new* host access via
  `mo-lan-ssh`. LAN aliasing is name-shorthand for hosts already in their
  `~/.ssh/known_hosts` or discoverable on their LAN.
- Software supply chain attacks against `oh-my-zsh` upstream are out of
  scope (master-oogway requires OMZ but doesn't ship it).

### 13.4 Security guarantees master-oogway claims

1. Re-running `install.sh` is idempotent — it never destroys files without
   making a timestamped backup first.
2. Uninstall restores the most recent backup or removes only marker-bounded
   blocks from system files.
3. `dragon-configure` never writes a syntactically-invalid `conf.zsh` —
   `zsh -n` validation gates the rename.
4. No first-party plugin reads or transmits credentials, history, or files
   outside the user's home directory.
5. `please` will not auto-sudo a command containing shell metacharacters that
   can't be safely re-tokenised. (HIGH-6 strengthens this further.)
6. Marker-wrapped SSH config edits are reversible.
7. All third-party tool invocations use `command <tool>` (not `<tool>`) when
   bypassing master-oogway's own override aliases (e.g. `command grep` inside
   `grep()`).

### 13.5 Open security debt

- (CRIT-1) Install URL points at `main`, not a signed tag.
- (CRIT-2) sshd_config modification under curl-pipe needs a clearer prompt.
- (HIGH-6) `please` ends in `eval`.
- (MED-5) `serve` exposes 0.0.0.0 with warning, not a second-flag opt-in.
- (MED-6) LAN auto-trust defaults on.
- (SEC-2) `frg` evaluates `EDITOR_LINENO_FMT`.

---

## 14. UX / DX review

### 14.1 First-run experience

```
$ bash -c "$(curl -fsSL .../install.sh)"
[INF] Cloning master-oogway into /home/.../  .master-oogway...
... (~10s)
[OK ] Plugin submodules already initialized
[OK ] Created /home/.../.zshrc with master-oogway template
[OK ] Backed up /home/.../.gitconfig → .pre-master-oogway.20260525_213000
[OK ] Created /home/.../.gitconfig with identity and bundle include
... (sshd prompt) ...
[OK ] dragon theme already configured
┌─────────────────────────────────────────────────────┐
│  Optional packages not installed                    │
└─────────────────────────────────────────────────────┘
  mo-search             rg            ripgrep — enables frg ...
  mo-files              7z            p7zip-full
  ...
  To install all:  sudo apt install ripgrep p7zip-full ...
┌─────────────────────────────────────────────────────┐
│  Manual steps required after install                │
└─────────────────────────────────────────────────────┘
  1. Configure your prompt: open a new terminal and run 'dragon-configure'
┌─────────────────────────────────────────────────────┐
│  Tip: version-control your customisations           │
└─────────────────────────────────────────────────────┘
  ~/.config/master-oogway holds your customisations:
    ...
[OK ] dragon installation complete. Open a new terminal to apply changes.
```

This is excellent. Most frameworks dump a wall of text.

### 14.2 Wizard

`dragon-configure` first run:

```
── Welcome to dragon ───────────────────────────────────
   Here is what your prompt will look like and what each part means.
   Left prompt:  user@hostname:~/projects on main ✔
                 ❯
   ...
   Font check: do the powerline arrow and folder icon render? [y/N]
── dragon Theme Configurator ───────────────────────────
  Welcome! Choose a starting point for your prompt:
  [1] short ... [2] default ... [3] verbose ... [4-26] preset names
  Choice [1-26, default=2]:
── Step 1/20: Nerd Font & Segment Separators ───────────
   Live preview:
   ┌────────────────────────────────────────
   │ user@hostname:~/projects on main ✔
   │ ❯
   └────────────────────────────────────────
  Variables:
    1. DRAGON__USE_NERD_FONT             true ★
    2. DRAGON__LEFT_SEGMENT_SEPARATOR    
    ...
  [number] edit var   [b] back   [Enter/n] next   [q] save & quit   [d] reset group to defaults
```

This is **best-in-class** for a shell wizard. The font-check question is a
small touch that single-handedly removes the most common dragon support
ticket ("why are there boxes everywhere").

### 14.3 Things that should be added

#### UX-1 — Progress indicator during long operations
Background `_mo_lan_refresh_async` shows no spinner, even when it's running
on the foreground via `mo-lan-ssh setup`. Add a 50ms-tick `\` `|` `/` `-`
spinner for foreground refreshes.

#### UX-2 — `master-oogway doctor` (MED-8)
Covered above.

#### UX-3 — `master-oogway benchmark` (MED-9)
Covered above.

#### UX-4 — Visual preset picker (MED-7)
Same machinery as `mo-color pick`.

#### UX-5 — Help discoverability
A user who types `master-oogway` gets the right help. A user who types
`dragon` doesn't (there's no command of that name) — they have to know to
type `dragon-configure`. Consider exposing `dragon` as an alias for
`dragon-configure` (after checking for namespace conflict).

#### UX-6 — Completion coverage
Zero completions for first-party commands. See §16.

### 14.4 Power-user features

- `dragon-configure --export <name>` — already exists.
- `dragon-configure --gallery` — already exists.
- `dragon-configure --diff <preset>` — already exists.
- `master-oogway diff-zshrc [tool]` — already exists.
- `master-oogway path` — already exists.

What's missing for the truly demanding user:

- `dragon-configure --import <file>` (reverse of `--export`).
- `dragon-configure --random` (pick a random preset for the day).
- `master-oogway snapshot save <name>` — versioned configurations.
- `master-oogway snapshot restore <name>`.
- `master-oogway plugins list / disable / enable` (HIGH-3).
- `master-oogway profile` (zprof; MED-9).

### 14.5 Contributor experience

- `CONTRIBUTING.md` is **clear and pragmatic**. Best-in-class for shell
  frameworks.
- Dev-mode symlink (`./install.sh` from a clone) is **excellent**.
- `soursh` (alias in `mo-shell-tools`) for fast re-source.
- `rezsh` (alias in `themes/dragon/aliases.zsh`) for theme-aware reload.

Missing:

- A `make`/`just` task runner. The validation commands in `CONTRIBUTING.md:88`
  are recipes; embed them in a `Justfile` or `Makefile`:

  ```makefile
  # Makefile
  .PHONY: lint test perf clean

  lint:
      bash -n install.sh
      zsh -n omz-custom/themes/dragon.zsh-theme \
             omz-custom/themes/dragon/*.zsh \
             omz-custom/themes/dragon/parts/*.zsh \
             omz-custom/plugins/mo-*/mo-*.plugin.zsh
      shellcheck install.sh

  test:
      bats omz-custom/plugins/mo-*/tests/*.bats

  perf:
      ./tools/bench.sh
  ```

- `pre-commit` hooks: `pre-commit` framework with shellcheck/`zsh -n`
  configured so contributors get fast local feedback.

- Issue templates: `bug_report.yml`, `feature_request.yml`,
  `plugin_proposal.yml` in `.github/ISSUE_TEMPLATE/`.

- PR template: `.github/PULL_REQUEST_TEMPLATE.md` with the validation
  checklist inline.

- CODEOWNERS: `* @tomershay100` plus per-area assignments as collaborators
  grow.

- A CHANGELOG (see §17.3).

---

## 15. Reliability review

### 15.1 Failure modes seen in code

#### REL-1 — gitstatus daemon fails to start
**Files:** `omz-custom/themes/dragon/parts/gitstatus.zsh:8-12`.

`gitstatus_start -s -1 -u -1 -c -1 -d -1 ...` is called with `-1` (unlimited)
on every limit. If gitstatusd is missing or the binary cgroup fails, the
function silently returns; `__update_gitstatusd` then no-ops on subsequent
calls because `_IS_GITSTATUS_RUNNING=true` was set before the start could
fail.

**Fix:** Set `_IS_GITSTATUS_RUNNING=true` only on success:

```zsh
__start_gitstatus_once() {
    $_IS_GITSTATUS_RUNNING && return
    if gitstatus_start -s -1 -u -1 -c -1 -d -1 "$_GITSTATUS_NAME" 2>/dev/null; then
        _IS_GITSTATUS_RUNNING=true
    fi
}
```

#### REL-2 — Stale gitstatus daemon after suspend/resume
On laptop suspend the daemon socket can be invalidated. Subsequent
`gitstatus_query` either hangs or returns stale data. No detection in code.

**Fix:** Track last successful query time. On `__update_prompt`, if more
than N seconds since last success, force `_IS_GITSTATUS_RUNNING=false`
and re-start.

#### REL-3 — `mo-lan-ssh` background refresh failure is silent
**File:** `omz-custom/plugins/mo-lan-ssh/mo-lan-ssh.plugin.zsh:69-72`.

```zsh
_mo_lan_refresh_async() {
    [[ -f "$_MO_LAN_SSH_DISCOVER" ]] || return
    (
        flock -n 9 || exit 0
        zsh "$_MO_LAN_SSH_DISCOVER" 2>/dev/null
    ) 9>"$_MO_LAN_SSH_LOCK" &!
}
```

When discovery fails (e.g. no `dig` and no `nmap`), the user sees nothing.
`mo-lan-ssh status` will eventually show `Refreshed: <old date>` but no
indication of *why* it's old.

**Fix:** Log to `~/.config/master-oogway/lan-hosts.log` (truncate to last
20 lines on each write). Surface in `mo-lan-ssh status` and `master-oogway
doctor`.

#### REL-4 — `_dragon_write_conf`'s validation can leave a stale `.wizard.tmp`
**File:** `omz-custom/themes/dragon/configure.zsh:632-638`.

```zsh
if ! zsh -n "$tmp_file" 2>/dev/null; then
    rm -f "$tmp_file"
    return 1
fi
command mv "$tmp_file" "${_DRAGON_CONF_FILE}"
```

If `mv` fails (e.g. read-only filesystem), `$tmp_file` is left in place. Add
a `trap` to cleanup tmp on error:

```zsh
local tmp_file=...
trap 'rm -f "$tmp_file"' EXIT
{
    ...
} > "$tmp_file"
zsh -n "$tmp_file" || return 1
command mv "$tmp_file" "${_DRAGON_CONF_FILE}"
trap - EXIT
```

#### REL-5 — `_check_theme_vars` runs `zsh -c` at install time
**File:** `install.sh:744-753`.

```zsh
current_hash=$(zsh -c '
    source "$1/schema.zsh"
    _dragon_init_defaults
    printf "%s\n" "${(@k)_DRAGON_DEFAULTS}" | sort | md5sum | cut -d" " -f1
' -- "${themes_dir}" 2>/dev/null)
```

If `themes_dir` is missing (corrupt install), `$current_hash` is empty,
mismatch is "stored != empty", and the todo prints
`run 'dragon-configure --new-only'`. Misleading. Should detect missing
schema.zsh and emit a clearer error.

#### REL-6 — `aliases.zsh` defines `_DRAGON_THEME_DIR` as `typeset -gr` (readonly)
See MED-11. Re-source path raises an error; current invocations are
guarded but a future user-extension that re-sources `aliases.zsh` would
hit it.

#### REL-7 — No retry on `git clone` failure
**File:** `install.sh:304-305`.

```zsh
_git_out=$(git clone --recurse-submodules ... 2>&1) \
    || die "Clone failed:\n${_git_out}\n\nTo recover: rm -rf ${INSTALL_DIR} and re-run."
```

The recovery instructions are clear but a transient network failure
shouldn't require manual rm. Three retries with backoff would catch the
common case.

#### REL-8 — `_mo_lan_apply` registers aliases unconditionally; no rollback
**File:** `omz-custom/plugins/mo-lan-ssh/mo-lan-ssh.plugin.zsh:195-232`.

`alias -- "${alias_name}=ssh ${h}"` — if `h` contains a quote (it can't —
`_mo_lan_valid_host` already rejected those) the alias would be malformed.
Defence in depth: store the result of the alias creation and validate.

### 15.2 General reliability patterns to standardize

- **Always trap cleanup.** `mo-color pick` does this correctly with `trap
  'tput cnorm; tput rmcup' EXIT INT TERM HUP`. Most other functions don't
  bother because they don't manipulate terminal state — fine. Adopt the
  pattern wherever there's terminal-modifying code.

- **Always `command mv`** for atomic rename (already universal in the repo
  — every state file uses `${file}.tmp` + `command mv`).

- **Always sanity-check before write.** The `cmp -s` skip-if-identical in
  `copy_file` and the `combined_sha` skip in `_mo_lan_maybe_write_sshconf`
  are both excellent — they keep shell-startup cost at zero on the steady
  state.

- **Never silently swallow non-trivial errors.** `2>/dev/null` is overused
  in places (REL-1, REL-4). A `[[ -z "$result" ]] && log_to_state` pattern
  is preferable.

---

## 16. Completions review

### 16.1 Today

- OMZ provides completions for the built-ins it ships (`git`, `docker`,
  etc.).
- `mo-lan-ssh` plugin sets `zstyle ':completion:*:(ssh|scp|sftp|rsync):*'
  hosts "${(@k)_MO_LAN_HOSTS}"`. *This globally overrides the user's
  `_hosts`.*
- No completions for any first-party command (`dragon-configure`,
  `master-oogway`, `mo-lan-ssh`, `tunnel`, `color`, `mo-man`, `please`,
  `epoch`, `calc`, `serve`, `bak`, `compress`, `extract`, `sizeof`, `mkcd`,
  `up`, `tmpcd`, `fcd`, `fp`, `fhist`, `fman`, `frg`, `psgrep`, `port`,
  `fkill`, `fenv`, `m`, `mc`, `md2pdf`, `mkscript`, `gtag`, `fbranch`,
  `flog`, `gsum`, `groot`, `cdb`, `cwhich`, `vwhich`, `clip`, `vizsh`,
  `mo-where`, `p`, `tunnel`).

### 16.2 Problems

- `mo-lan-ssh`'s `zstyle ... hosts` is *replace*, not *append*. If a user
  declares their own `zstyle` hosts in `custom-zsh/`, master-oogway clobbers
  it on every shell start. **Fix:** read the existing zstyle, merge, then
  write.

- No completion for `dragon-configure --preset <TAB>` despite there being a
  well-defined `_DRAGON_PRESET_NAMES` array. This is the *single highest
  ROI completion in the repo* — every user types `dragon-configure
  --preset <something>` and would benefit.

- No completion for `master-oogway <TAB>`. Should complete to the
  subcommand list (`update`, `uninstall`, `version`, `configure`, `edit`,
  `diff-zshrc`, `path`, `help`).

- No completion for `tunnel <TAB>` — should complete LAN hostnames and
  common port numbers.

- No completion for `mo-man <TAB>` — should complete to the list of
  installed plugin names.

### 16.3 Proposed structure

Add `omz-custom/completions/` directory. OMZ already adds
`$ZSH_CUSTOM/plugins/*/` to `fpath`; extend to also add
`$ZSH_CUSTOM/completions/`.

```
omz-custom/completions/
  _dragon-configure       # autoload completion for dragon-configure
  _master-oogway          # autoload completion for master-oogway
  _mo-man
  _tunnel
  _mo-lan-ssh
  ...
```

Sample `_dragon-configure`:

```zsh
#compdef dragon-configure
_dragon-configure() {
    local -a opts presets
    opts=(
        '--help[show help]'
        '-h[show help]'
        '--new-only[only configure new variables]'
        '--preset[apply a preset]:preset:->presets'
        '--export[save current config as preset]:name:'
        '--diff[diff against a preset]:preset:->presets'
        '--gallery[show all presets]'
        '--dismiss[dismiss new-vars notifier]'
        '--version[print version]'
        '-v[print version]'
    )

    _arguments -C "$opts[@]"
    if [[ "$state" == "presets" ]]; then
        # Built-in presets
        presets=( ${${${(f)"$(zsh -c 'source ~/.master-oogway/omz-custom/themes/dragon/schema.zsh; _dragon_init_presets; print "${_DRAGON_PRESET_NAMES[@]}"')":-}// /\n}// /} )
        # Personal presets
        presets+=( ${${${(M)~/.config/master-oogway/presets/*.conf.zsh(N):#*/*.conf.zsh}##*/}%.conf.zsh} )
        _values 'preset' $presets
    fi
}
_dragon-configure "$@"
```

Generate these as part of the plugin manifest (HIGH-3) — every plugin can
ship its own `_<cmd>` and the loader registers them.

### 16.4 `compinit` policy

Document the recommended `compinit -C` pattern in `zshenv.master-oogway` or
`zshrc.master-oogway`. Currently relies on OMZ default. See MED-1.

---

## 17. CI / CD review

### 17.1 Today

Nothing. No `.github/workflows/`, no `.gitlab-ci.yml`, no `Makefile`, no
pre-commit, no Husky, no CHANGELOG.

`CONTRIBUTING.md:88-103` documents the *recipes* (`bash -n`, `zsh -n`,
`shellcheck`) but they're "honour system" — no enforcement.

### 17.2 Minimum viable CI

(See HIGH-1 for the full yaml.)

- Tier 1 — fastest: `bash -n`, `zsh -n`, `shellcheck`. Run on every PR.
- Tier 2 — slower: a smoke test that runs `install.sh` in a fresh
  Ubuntu container, opens a zsh, and asserts dragon-configure exists and
  `master-oogway version` runs.
- Tier 3 — slower still: BATS tests against each plugin's `tests/` dir.
- Tier 4 — nightly: performance regression test.

### 17.3 Release engineering

Today there are zero tags. `master-oogway version` reports
`master-oogway 2026-05-25_232614-29bac67` which is a commit-date-and-SHA — fine
as a development indicator but not a release version.

Propose:

- **Semver tags.** `v1.0.0`, `v1.1.0`, etc.
- **CHANGELOG.md.** Auto-generated from commit prefix (`feat:`, `fix:`,
  `docs:`, ...) — adopt
  [Conventional Commits](https://www.conventionalcommits.org/) (you already
  half-do this: `feat(dragon)`, `fix(diff-zshrc)`, `docs(LOW-5)`).
- **Signed tags.** `git tag -s v1.0.0 -m "..."`.
- **GitHub Releases** with attached install.sh (signed) and SOURCES.lock
  (submodule SHAs).
- **Distribution packaging:**
  - Homebrew formula (`brew install master-oogway`).
  - AUR package (`yay -S master-oogway`).
  - Nix flake (`nix profile install github:tomershay100/master-oogway`).
  - Snap (debatable; lots of overhead for shell).
- **Renovate / Dependabot** for the four vendored submodules. Auto-PR when
  upstream releases.

### 17.4 Reproducibility

A given tag should always install the same files. Today the four submodules
are floating; `git submodule update --remote` would silently advance them.

Lock file:

```yaml
# SUBMODULES.lock
gitstatus: 9bdc20edff21f3f4ad7d0833b0c6a0eef1f3aa0d
you-should-use: 9c094fe05d1d5d1c0ca8e6c7d4720c1c14eb7e0a
zsh-autosuggestions: c3d4e576c9c86eac62884bd47c01f6faed043fc5
zsh-syntax-highlighting: e0165eaa730dd0fa321a6a6de74f092fe87630b0
```

CI step:

```yaml
- name: verify submodule pins
  run: |
    git submodule status --recursive | awk '{print $2 ": " $1}' | sort > /tmp/actual
    sort SUBMODULES.lock > /tmp/expected
    diff /tmp/actual /tmp/expected
```

---

## 18. Testing review

### 18.1 Today

Zero tests for master-oogway code. The four submodules have their own
tests (e.g. `zsh-syntax-highlighting/tests/test-highlighting.zsh`) but
those tests are upstream's responsibility and don't run as part of master-
oogway's CI (because there is no CI).

### 18.2 Proposed test taxonomy

Use [BATS](https://github.com/bats-core/bats-core).

#### 18.2.1 Unit — per plugin

```bats
# omz-custom/plugins/mo-git/tests/groot.bats
#!/usr/bin/env bats

setup() {
    export ZSH_CUSTOM="${BATS_TEST_DIRNAME}/../../.."
    cd "$(mktemp -d)"
    git init -q
    git commit --allow-empty -q -m "initial"
    mkdir sub && cd sub
}

@test "groot from subdir cds to repo root" {
    run zsh -c "source $ZSH_CUSTOM/plugins/mo-git/mo-git.plugin.zsh; groot; pwd"
    [ "$status" -eq 0 ]
    [[ "$output" != *"/sub" ]]
}
```

#### 18.2.2 Integration — installer

```bats
# tests/install.bats
@test "install.sh idempotency" {
    bash install.sh < /dev/null
    bash install.sh < /dev/null
    # second run must not create new backup
    [ "$(ls $HOME/.zshrc.pre-master-oogway.* 2>/dev/null | wc -l)" -eq 1 ]
}

@test "install --uninstall removes managed files" {
    bash install.sh < /dev/null
    bash install.sh --uninstall <<< "y"
    [ ! -d "$HOME/.master-oogway" ]
}
```

#### 18.2.3 Snapshot — prompts

Render the prompt under controlled inputs and compare against checked-in
snapshots. Example:

```bats
@test "dragon prompt default preset matches snapshot" {
    local actual
    actual=$(zsh -c "
        source $ZSH_CUSTOM/themes/dragon/dragon.zsh
        VCS_STATUS_RESULT=ok-sync
        VCS_STATUS_LOCAL_BRANCH=main
        PWD=/home/test/projects
        HOME=/home/test
        USER=test
        dragon__update_zsh_prompt
        printf '%s\n' \"\$PROMPT\"
        printf '%s\n' \"\$RPROMPT\"
    ")
    expected=$(< tests/snapshots/default.prompt)
    [ "$actual" = "$expected" ]
}
```

Strip ANSI on both sides before compare for stability.

#### 18.2.4 Visual — preset gallery diff

Once snapshots exist, `dragon-configure --gallery` becomes a visual
regression test: render every preset to a snapshot file. CI diffs against
checked-in snapshots; non-matching PRs require explicit "update snapshot"
commit.

#### 18.2.5 Performance regression

See §9.5.

#### 18.2.6 Plugin matrix

For every plugin, test in 4 configurations:

- All optional deps present.
- No optional deps (each `_MO_OPT_BIN` is 0).
- Hard dep missing (plugin must not load; warning is emitted).
- Plugin disabled in `plugins=()` (sanity — other plugins still work).

### 18.3 Test infrastructure

```
tests/
  install.bats
  uninstall.bats
  snapshots/
    default.prompt
    minimal.prompt
    ...
  fixtures/
    sample-conf.zsh
    sample-state
  helpers/
    setup.bash         # source from every .bats file
```

CI step:

```yaml
- name: test
  run: |
    apt-get install -y bats
    bats tests/*.bats omz-custom/plugins/*/tests/*.bats
```

---

## 19. Documentation review

### 19.1 Today

- `README.md` — 74 LOC, user-facing. Concise, accurate. Good.
- `CONTRIBUTING.md` — 353 LOC, contributor-facing. Thorough.
- 25 plugin READMEs (one per `mo-*/`).
- `omz-custom/README.md` (not read; assume minimal).
- `omz-custom/themes/dragon/README.md` (not read; assume minimal).
- `docs/superpowers/plans/*.md` — historical implementation notes; not
  user-facing.

### 19.2 Gaps

- **No `SECURITY.md`** — threat model belongs there (§13).
- **No `ARCHITECTURE.md`** — load order, prompt data flow, SSH forwarding
  contract belong there (currently scattered between code comments and
  CONTRIBUTING).
- **No `PERFORMANCE.md`** — budget, profiling guide, optimization recipes
  (currently nowhere).
- **No `MIGRATION.md`** — for users upgrading between major versions
  (currently nowhere because there are no versions).
- **No `TROUBLESHOOTING.md`** — common failure modes and recovery.
- **No `CHANGELOG.md`** — every release needs one.
- **No `CODE_OF_CONDUCT.md`** — table-stakes for a public OSS project.
- **No `.github/ISSUE_TEMPLATE/`** — drives signal/noise ratio in issues.
- **No `.github/PULL_REQUEST_TEMPLATE.md`** — reminds contributors of the
  validation checklist.
- **No architecture diagram (mermaid or otherwise).**

### 19.3 Doc layout proposal

```
README.md                  # quickstart, install, what gets installed
CONTRIBUTING.md            # already great
CHANGELOG.md               # generated from conventional commits
LICENSE                    # MIT (presumably)
SECURITY.md                # threat model + how to report
docs/
  ARCHITECTURE.md          # load order, prompt data flow, SSH forwarding
  PERFORMANCE.md           # budget, profiling, optimization recipes
  TROUBLESHOOTING.md       # common failure modes & recovery
  PLUGIN_AUTHORING.md      # how to write a third-party plugin
  THEME_AUTHORING.md       # how to write a sister theme to dragon
  PRESET_AUTHORING.md      # how to write a preset
  MIGRATION.md             # version-to-version upgrade notes
  diagrams/
    architecture.svg
    prompt-render-flow.svg
    install-modes.svg
.github/
  ISSUE_TEMPLATE/
    bug_report.yml
    feature_request.yml
    plugin_proposal.yml
  PULL_REQUEST_TEMPLATE.md
  CODEOWNERS
  workflows/
    ci.yml
```

### 19.4 Per-plugin README conformance

`CONTRIBUTING.md:168-247` defines a 5-section template (intro, command
table, [bypass line for overrides], [config], [examples], dependencies).
Spot check from the audit notes shows 25/25 READMEs exist. A linter
(`docs/lint-plugin-readme.zsh`) would enforce structure in CI.

---

## 20. Roadmap

Time-bucketed, with explicit dependencies.

### 20.1 v1.0 — "ready for strangers" (3 months)

**Required:**

- HIGH-1: CI (lint + smoke + matrix).
- HIGH-3: Plugin manifest.
- HIGH-6: Replace `please` `eval`.
- CRIT-1: Pin install URL to a signed tag (after first release).
- CRIT-2: Clearer sshd-config prompt under non-interactive install.
- MED-1: `compinit -C` policy.
- MED-5: `serve` requires `--public`.
- MED-6: LAN auto-trust default off.
- MED-8: `master-oogway doctor`.
- §13: `SECURITY.md` with explicit threat model.
- §16: Completions for `master-oogway`, `dragon-configure`, `mo-man`,
  `tunnel`.
- §17.3: First signed release `v1.0.0` with CHANGELOG.
- §18: Minimum viable BATS tests for installer + 5 highest-blast-radius
  plugins (`mo-trash`, `mo-lan-ssh`, `mo-projects`, `mo-shell-tools`,
  `mo-files`).
- §19: `SECURITY.md`, `ARCHITECTURE.md`, `CHANGELOG.md`,
  `CODE_OF_CONDUCT.md`, issue + PR templates.

### 20.2 v1.5 — "fast and observable" (6 months)

- HIGH-2: Performance budget + `master-oogway benchmark` + CI gate.
- HIGH-4: Per-segment memoization in dragon.
- MED-2: Async-segment generalisation.
- MED-3: Eliminate process substitution in mo-color.
- MED-4: Preset inheritance.
- §9.3 patches: `zcompile`, optdeps caching, nproc replacement.
- §16: Completions for all first-party commands.
- §18: Snapshot tests for prompt rendering. Visual gallery diff CI.

### 20.3 v2.0 — "framework, not theme" (12 months)

- HIGH-5: Split framework from `dragon` theme.
- Second first-party theme (`slate` or `obsidian`) demonstrating the
  registry.
- §22 LT-1: Plugin marketplace / discoverability.
- §22 LT-2: Theme marketplace.
- §22 LT-4: Workspace-aware prompts.
- §22 LT-6: AI-assisted shell helpers (optional, behind a flag).

### 20.4 v3.0 — "ecosystem" (18+ months)

- Plugin sandboxing.
- Remote config sync (`master-oogway sync push/pull <git-url>`).
- Telemetry dashboards (opt-in, anonymous).
- Cross-shell core (bash compat for shared bits).
- Distribution channels: Homebrew tap, AUR, Nix flake.

---

## 21. Quick wins

> Each item is < 1 hour of work and improves something concrete.

| ID | Item | Effort | Impact |
|---|---|---|---|
| QW-1 | Replace `grep -c '^processor' /proc/cpuinfo` with `nproc` in `mo-build` and `mo-welcome` | 5 min | saves 2 forks/shell |
| QW-2 | Add `.github/workflows/ci.yml` (lint only) | 30 min | catches `zsh -n` failures pre-merge |
| QW-3 | Add `Makefile` with `lint`/`test`/`perf` targets | 15 min | discoverable contributor entrypoint |
| QW-4 | Add `_dragon-configure` and `_master-oogway` completions | 45 min | top-typed commands; high ROI |
| QW-5 | Add `omz-custom/lib/optdeps.zsh` with cached `_MO_OPT_BIN` map | 30 min | saves 10+ `command -v` per shell |
| QW-6 | Add `master-oogway doctor` (MED-8) | 45 min | replaces 4 separate diagnostic checks |
| QW-7 | Add `master-oogway benchmark` (MED-9) | 30 min | empowers user to self-diagnose perf |
| QW-8 | Add `zcompile` step to `install.sh` (Patch 3) | 30 min | 30-50% parse speedup |
| QW-9 | Add `.github/ISSUE_TEMPLATE/` + `PULL_REQUEST_TEMPLATE.md` | 20 min | signal/noise improvement |
| QW-10 | Pin install URL to `v1.0.0` once tag exists | 5 min | CRIT-1 partial |
| QW-11 | Remove the legacy double-quoted reader from `_dragon_load_current_conf` (MED-14) after migration | 15 min | smaller attack surface |
| QW-12 | Add a `--dry-run` to `install.sh` | 45 min | CRIT-1 partial |
| QW-13 | Auto-detect `delta` / `diff-so-fancy` in `diff-zshrc` (LOW-6) | 10 min | better DX for git users |
| QW-14 | Spinner during `_mo_lan_setup`'s foreground discovery (UX-1) | 20 min | reassures user |
| QW-15 | Convert `_mo_xterm_to_rgb` callers to use global vars (MED-3) | 30 min | eliminates 9 process subs per palette render |
| QW-16 | Auto-load `nproc` value into `_MO_NPROC` once at framework boot | 5 min | reused by `mo-build`, `mo-welcome`, `mo-files`'s compress potentially |

Total quick-wins budget: ~6 hours, addressing 16 items.

---

## 22. Long-term vision

### LT-1 — Plugin marketplace

A `master-oogway-plugins` GitHub org (or registry repo) hosting
community-contributed plugins. A `master-oogway plugins search <term>` /
`install <plugin>` CLI that clones into `~/.config/master-oogway/custom-plugins/`.
Requires HIGH-3 (manifest) to be useful.

### LT-2 — Theme marketplace

Mirror of LT-1 for themes. Each theme is a directory matching the dragon
shape (`schema.zsh`, `parts/`, `presets/`, `theme.meta.zsh`).

### LT-3 — Visual TUI configurator

Replace `dragon-configure`'s step-through with a single-screen TUI (à la
`tmux-conf` or `Steam`). Left pane: variable list. Right pane: live
preview. Top: preset switcher. Use the existing `_dragon_render_preview`
machinery + `mo-color pick`-style key handling.

### LT-4 — Workspace-aware prompts

Detect project type (Node, Python, Rust, Go, Java, etc.) from `cwd` and
auto-add a project-type segment. Optional. Configurable.

### LT-5 — Session restore

Snapshot the user's shell state (cwd, env, history pointer) on logout;
restore on next login. Useful for laptops resumed across reboots.

### LT-6 — AI-assisted shell helpers

`?? rebase the last 3 commits` → suggests `git rebase -i HEAD~3`. Behind
an opt-in flag with a documented data-flow contract (what gets sent, to
where, retention). Compatible with the threat model.

### LT-7 — `master-oogway sync`

Push `~/.config/master-oogway/` (conf.zsh, personal presets, custom-zsh/,
custom-plugins/) to a user-owned git repo. Pull on another machine to
restore. Encryption at rest via age/sops.

### LT-8 — Cross-shell core

Extract the install logic and override-aliases into a shared bash/zsh
library so users on bash hosts get the same `gs`/`gp`/`gl`/etc.
Architecturally: `omz-custom/lib/cross-shell/` is sourced from both
`zshrc.master-oogway` and a sibling `bashrc.master-oogway`.

### LT-9 — Telemetry dashboard (opt-in)

Aggregate (anonymised) preset usage statistics: "70% of users pick
`default`, 12% pick `cyberpunk`, 0.5% pick `ascii`." Tells the maintainer
which presets are worth keeping, which to deprecate, where to focus.
Mandatorily opt-in; ship a `master-oogway telemetry status/enable/disable`
CLI.

### LT-10 — Plugin sandboxing

`unshare`/`bwrap`-based plugin sandboxing for untrusted third-party
plugins. Plugin manifest declares `[sandbox]="true"`; loader runs the
plugin in a network-/filesystem-restricted subshell. Aspirational.

---

## 23. Release checklist

For every release tag:

- [ ] Bump version in `omz-custom/themes/dragon/theme.meta.zsh` and
  every changed `mo-*/plugin.meta.zsh`.
- [ ] `make lint && make test && make perf` — all green.
- [ ] Update `CHANGELOG.md` from conventional commits.
- [ ] Verify `SUBMODULES.lock` matches the desired submodule SHAs.
- [ ] `git tag -s vX.Y.Z -m "..."`.
- [ ] Create GitHub Release; attach `install.sh` and detached signature.
- [ ] Update the documented install URL in `README.md` to the new tag.
- [ ] Sanity-check on a fresh Ubuntu 24.04 container.
- [ ] Sanity-check on Raspberry Pi (CI matrix step).
- [ ] Open Renovate PR if any submodule has a new release.

---

## 24. Production checklist

For an operator deploying master-oogway to fleet machines:

- [ ] Pin install URL to a specific signed tag — never `main`.
- [ ] Audit `install.sh` before allowing it to run (or use `--dry-run`).
- [ ] Decide whether to allow `/etc/ssh/sshd_config` modification; if not,
  set `MO_DISABLE_SSHD_EDIT=1` (proposed flag — currently each operator
  must `confirm` `n`).
- [ ] Decide whether to enable LAN auto-trust per-host
  (`MO_LAN_AUTO_TRUST=true|false` in `~/.zshrc` after install).
- [ ] Pin OMZ to a specific commit (out of scope of master-oogway but in
  scope of operator).
- [ ] Stage `dragon-configure --export <fleet-name>` on a golden host and
  distribute the resulting preset; have all fleet hosts run
  `dragon-configure --preset <fleet-name>` post-install.
- [ ] Document the rollback path: `master-oogway uninstall` + restore
  `.pre-master-oogway.<ts>` backups.

---

## 25. Contributor checklist

For every PR (post-CI):

- [ ] `bash -n install.sh` — passes.
- [ ] `zsh -n <changed files>` — passes.
- [ ] `shellcheck install.sh` — no new warnings.
- [ ] Plugin's `plugin.meta.zsh` (when HIGH-3 lands) updated for the
  change.
- [ ] Plugin's README (`omz-custom/plugins/mo-<name>/README.md`) updated.
- [ ] If a new `DRAGON__*` variable: schema entry + type + group + hint +
  consumed in `parts/*.zsh`.
- [ ] If new outside-`~/.config/` write: documented in plugin's
  `plugin.meta.zsh [writes_outside_config]` and gated behind a `setup`
  subcommand.
- [ ] `CHANGELOG.md` updated (or skipped with `[skip changelog]` for
  internal-only changes).
- [ ] If behaviour-changing: BATS test added.
- [ ] If performance-affecting: `master-oogway benchmark` numbers
  attached to PR description.
- [ ] If security-relevant: cross-reference `SECURITY.md` / threat model
  section.

---

## 26. Final recommendations

### 26.1 The one thing to do this month

Land **HIGH-1 (CI) + first signed release tag (v1.0.0)**. CI is the
keystone — every other item in this document is easier and safer to land
once a PR can fail loudly. The release tag is the trust anchor for CRIT-1.

### 26.2 The one thing to do this quarter

Land **HIGH-3 (plugin manifest)**. It unlocks:

- `master-oogway plugins list / info / disable / enable` (MED-10).
- `master-oogway doctor` (MED-8).
- Auto-generated README plugin table (LOW-3).
- Versioned plugins, which unlock CHANGELOG generation.
- Conflict detection (MED-13).
- Eventually, a plugin marketplace (LT-1).

### 26.3 The one thing to *think* about this year

Decide whether master-oogway is **a curated framework one maintainer
ships** or **an ecosystem of contributed plugins/themes**. They are
different products.

The current trajectory points at "framework" — and that's fine; the work
in this document supports that. If "ecosystem" is the goal, then more
work goes into plugin/theme APIs, marketplace tooling, sandboxing,
community governance (CODE_OF_CONDUCT, MAINTAINERS.md, RFC process). Both
are valid. Both are good. They have different next steps.

### 26.4 What master-oogway already does better than most shell frameworks

For balance, before the closing line: this repository is, on a per-LOC
basis, **already among the most carefully written shell-environment
projects on GitHub.** The schema-driven theme, the idempotent installer
with marker-wrapped system edits, the per-plugin hard/soft dep declaration
system, the SSH-forwarded theme contract, the conf.zsh `zsh -n`
self-validation, the atomic state-file writes — these are *staff-grade*
patterns rare even in well-funded open source. The gap to "production-ready
ecosystem" is not about *quality*; it's about *automation, surface area,
and trust anchors*.

The bones are good. Build the skeleton.

---

*End of PROD.md.  Generated 2026-05-25 against `master-oogway` `main` @ `29bac67`.*
