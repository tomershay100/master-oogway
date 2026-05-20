# master-oogway — production-readiness audit

**Date:** 2026-05-19
**Auditor's pass:** every shell file in this repo, read in full — `install.sh`
(624 LOC), all four top-level templates (`zshrc`, `zshenv`, `gitconfig`,
`editorconfig`), the dragon theme (`schema.zsh` 391, `configure.zsh` 944,
`dragon.zsh` 76, `notifier.zsh` 52, `aliases.zsh` 8, 7 `parts/*.zsh` totalling
794 LOC), and every `mo-*` plugin including `mo-lan-ssh` (`plugin.zsh` 667,
`_mo_lan_discover.zsh` 208). Vendored submodules are out of scope.

**Code under review:** 3235 LOC across 28 hand-maintained files.

**Verdict in one sentence:** the code is *good* — better than most public
dotfiles repos — and the remaining work is mostly *not in the code*. The two
biggest gaps are **no automated tests** and **no LICENSE**. Everything else
is sub-50-line fixes or polish.

---

## How I verified

Each finding below was confirmed by reading the relevant code, and where
trivially testable, by running the verification command shown in the
finding. I have not booted a fresh Ubuntu container to run end-to-end; that's
listed under [M-1](#m-1) as the remaining unknown.

For each finding:
- **Severity** is one of P0 (blocker for "v1.0"), P1 (important), P2 (nice),
  P3 (cosmetic).
- **Confidence** is HIGH (I read the code and saw the bug), MEDIUM (I'm
  pretty sure but didn't run a repro), or LOW (smells off, worth checking).

---

## Verdict at a glance

| Area | Grade | Why |
|---|---|---|
| Code correctness | A− | Defensive everywhere; schema-validated wizard output. 4 real bugs (B-1…B-4) — all small. |
| Security | A− | Strong: fzf injections sealed, zip path-traversal blocked, sshd validated+reverted. One quiet behaviour change (S-1). |
| UX & error paths | A− | Friendly TODO box, marker-protected files, recovery hints. Three friction points (U-1…U-3). |
| Performance | B+ | gitstatus async, sentinel-based skip, NUL pipelines. Five small wastes (P-1…P-5). |
| **Testability** | **F** | Zero tests. Zero CI. Validation = humans running three commands by hand. |
| Documentation | A | All READMEs synced this week, CONTRIBUTING is current. Three stale zshrc comments (D-1). |
| Distribution | C | No `LICENSE`. No version tags. No `CHANGELOG`. Vendored submodules all have these — host repo doesn't. |
| Maintainability | A− | Schema-driven design; consistent conventions; thoughtful comments. mo-lan-ssh is getting big (A-1). |

---

## Section 1 — Bugs (real, reproducible)

## Section 2 — Security findings

### S-1 — `HashKnownHosts no` is silently set for *all* SSH hosts, not just LAN
**Severity:** P2  **Confidence:** HIGH
**File:** `install.sh:535`

```bash
printf '\n%s\nHost *\n    SendEnv DRAGON__*\n    HashKnownHosts no\n%s\n' \
    "$marker_begin" "$marker_end" >> "$ssh_config"
```

The installer adds `HashKnownHosts no` inside `Host *` — making it apply to
every SSH connection on the box, including non-LAN, non-master-oogway hosts.
This is presumably set so `mo-lan-ssh forget` can `ssh-keygen -R <hostname>`
work (hashed entries can only be matched by their hashed form).

**Why this matters:** OpenSSH defaults to `HashKnownHosts yes` on modern
Debian/Ubuntu specifically because a stolen `~/.ssh/known_hosts` shouldn't
leak an inventory of every server the user has touched. We're quietly
reversing that posture for a convenience feature.

**Fix options (in order of preference):**
1. Drop the `HashKnownHosts no` line entirely. `mo-lan-ssh forget` can use
   `ssh-keygen -F <host>` first to detect, then `-R` works against hashed
   entries too (it does the hash match internally).
2. Scope `HashKnownHosts no` to a `Host`-pattern matching only LAN hosts
   (would need to know LAN host list at install time — chicken/egg).
3. Document this as a deliberate trade-off in the README and gate it behind
   an opt-out env var.

**Recommendation:** option 1. Modern `ssh-keygen -R` works fine against
hashed `known_hosts`.

---

## Section 3 — UX friction

## Section 4 — Performance

### P-3 — `__set_ssh_connection_count_content` runs `who` on every prompt
**Severity:** P3  **Confidence:** HIGH
**File:** `omz-custom/themes/dragon/parts/segments_right.zsh:97`

`who` is fast on a desktop but can hang on systems with stale utmp records
(observed on long-running servers with crashed processes that didn't clean
utmp). For a per-prompt call, even 20ms is noticeable.

The result doesn't change between commands; only on actual SSH connect/
disconnect events. Could be cached for the lifetime of a `_DRAGON_SESSION_*`
state and only refreshed when `$EPOCHSECONDS - last_check > 10` or on
explicit `kill -SIGHUP` notification.

Low impact in normal use, but trivially deferrable if it ever bites.

---

### P-4 — `gitstatus_query -t 0.03` is hardcoded
**Severity:** P3  **Confidence:** MEDIUM (the precise semantics of `-t` with
`-c` callbacks vary across `gitstatus` versions)
**File:** `omz-custom/themes/dragon/parts/transient.zsh:84`

`-t 0.03` is the wait threshold before falling back to async. On a slow
disk or large mono-repo, 30ms isn't enough — gitstatus returns nothing
synchronously and the prompt is drawn without git info, then redrawn when
the callback fires. Cosmetically noticeable.

Add `DRAGON__GIT_STATUS_QUERY_TIMEOUT` to `schema.zsh`, default `0.03`.

---

### P-5 — `__calc_prompt_length` undercounts nerd-font / double-wide glyphs
**Severity:** P3  **Confidence:** MEDIUM
**File:** `omz-custom/themes/dragon/parts/prompt.zsh:4-5`

```zsh
local zsh_prompt_length=${(m)#${${(%)PROMPT}//$'\e['[0-9;]#[A-Za-z]/}}
```

`(m)#` counts grapheme clusters, treating each as width 1. But some
nerd-font glyphs (and most emoji) are double-wide in the terminal. The
auto-multiline-git-status calculation uses this length to decide whether
the right-side overflows; it will trigger multiline mode later than it
should on terminals that show those glyphs as 2 columns.

Hard to fix correctly (terminal width of arbitrary glyphs is genuinely
non-portable). Document it; add a `DRAGON__PROMPT_WIDTH_FUDGE` int the user
can bump if they see "almost-overflow but no break."

---

## Section 5 — Architecture / refactor observations

### A-1 — `mo-lan-ssh` is now 875 LOC across two files
The biggest plugin by far (next-largest is `mo-files` at 167). It does six
things: discovery (4 strategies), caching, atomic ssh-config rewriting, the
ssh wrapper, manual overlay, and the CLI. Each is solid; the bundle is
getting hard to skim.

Possible split:
- `mo-lan-ssh-core` — alias generation + completion + caches
- `mo-lan-ssh-trust` — ssh wrapper + key purge + ssh-copy-id

Users who don't want auto-trust could disable the trust plugin without
losing aliases. Don't split prematurely; revisit when the next feature
lands.

---

### A-2 — Presets are hardcoded in `_dragon_apply_preset`
**File:** `omz-custom/themes/dragon/configure.zsh:107-172`

Adding a fourth preset means editing three places (the case statement, the
`--preset` validation regex, and the help text). Data-driving this (presets
in `schema.zsh` as `_DRAGON_PRESETS[<name>]="VAR1=val1 VAR2=val2 …"`) makes
contribution easier. Low priority — three presets is probably enough
forever.

---

### A-3 — `# Requires:` convention is inconsistent across plugins
After this week's CONTRIBUTING update, the convention is documented:
external dependencies go at the top of the plugin in a `# Requires: …`
comment. 14 of 20 plugins have it. The 6 that don't (`mo-cli`,
`mo-shell-tools`, `mo-welcome`, `mo-colorize-override`, `mo-safety-override`,
`mo-auto-ls`) have no deps — arguably the convention should be "always
present, even if empty," so a grep audit returns 20/20.

Pick a position; apply uniformly.

---

### A-4 — SSH-forwarding guard is duplicated in every generated `conf.zsh`
**File:** `omz-custom/themes/dragon/configure.zsh:594-595`

Every new `conf.zsh` contains the two lines:

```zsh
[[ "${DRAGON__FORWARDED:-}" == "1" ]] && return
export DRAGON__FORWARDED=1
```

This means existing users' `conf.zsh` files have this guard hard-coded.
If the forwarding model ever needs to change, every user's `conf.zsh`
becomes a migration problem.

**Fix:** move the guard into `dragon.zsh` (the theme entry, which we
control). Generated `conf.zsh` files just set `DRAGON__FORWARDED=1`.
For existing users, a one-time migration block in `install.sh` strips the
duplicated guard from their `conf.zsh`. Higher risk than other fixes
because it touches user files.

---

## Section 6 — Infrastructure gaps (the real production-readiness story)

<a name="m-1"></a>

### M-1 — Zero tests
**Severity:** P0
**Evidence:** `find . -name '*test*' -o -name '*.bats' | grep -v
node_modules | grep -v submodule-paths` — empty.

For 3235 LOC of shell, no tests is the single biggest production-readiness
gap. Every refactor risks silent regression; `zsh -n` only catches parse
errors, not behaviour.

**Minimum viable test layer:** `bats-core` (the de-facto standard for shell).

```
tests/
  install/
    fresh.bats          # docker run ubuntu:24.04; install.sh; assert files
    update.bats         # second invocation is idempotent
    uninstall.bats      # cleans up; backup is restored
  theme/
    schema.bats         # hash is stable; init populates all groups
    configure.bats      # --preset writes valid conf.zsh; zsh -n on output
  plugins/
    smoke.bats          # each plugin sources cleanly with `zsh -n`
    mo-lan-ssh.bats     # `add`, `remove`, `forget` keep cache consistent
```

Even 20 bats tests would catch 80% of regressions.

---

### M-2 — No CI
**Severity:** P0

No GitHub Actions, no `.github/` directory at the host-repo level (only
inside vendored submodules). The CONTRIBUTING tells contributors to run
`bash -n` / `zsh -n` / `shellcheck` by hand; the only enforcement is human
discipline.

**Minimum viable CI** (`.github/workflows/lint.yml`):

```yaml
name: lint
on: [push, pull_request]
jobs:
  lint:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
        with: { submodules: recursive }
      - run: sudo apt-get install -y shellcheck zsh
      - run: bash -n install.sh
      - run: shellcheck install.sh
      - run: zsh -n omz-custom/themes/dragon/*.zsh \
                   omz-custom/themes/dragon/parts/*.zsh \
                   omz-custom/plugins/mo-*/mo-*.plugin.zsh
```

~30 lines. Once bats tests exist, append a `bats tests/`.

---

### M-3 — No `LICENSE`
**Severity:** P1

The install is publicly distributed via `curl | bash` from
`raw.githubusercontent.com/tomershay100/master-oogway/main/install.sh`.
Without a LICENSE:
- Nobody can legally fork, vendor, or redistribute.
- All four vendored submodules carry their own LICENSE files (BSD/MIT). The
  parent repo carrying their code is in legally murky territory.
- Anyone who reads dotfiles repos for ideas can't tell whether copying a
  pattern is permitted.

Add MIT or Apache-2.0. MIT is conventional for dotfiles. Single command:
`curl -O https://raw.githubusercontent.com/licenses/license-templates/master/templates/mit.txt`
and fill in the year/name.

---

### M-4 — No version tags, no `CHANGELOG`
**Severity:** P1

`master-oogway version` returns `dragon 2026-05-18_223456-f6ffdeb` — date +
short hash. Useful for "what am I running"; useless for:
- Detecting which fixes are in your install.
- Communicating breaking changes (the `# Provides:` removal, the
  `MO_LAN_PROBE_TIMEOUT` default change from 1 to 2, the upcoming
  `HashKnownHosts no` removal).
- Pinning installs (`MO_VERSION=v0.5 install.sh`).

Start tagging. `v0.1` would cover today; semver-ish from there
(`v0.2` = minor features, `v1.0` = post-tests + LICENSE). Maintain
`CHANGELOG.md` with one section per tag. `install.sh` can later support
`MO_VERSION=…` by `git checkout` on that tag inside `INSTALL_DIR`.

---

### M-5 — No pre-commit hook
**Severity:** P2

CONTRIBUTING says "run `bash -n` / `zsh -n` / `shellcheck` before
committing." A 10-line `tools/pre-commit` installed by `install.sh`
into `.git/hooks/pre-commit` would prevent every parse-error landing
locally. The `check-module-readme` skill (your Claude config) catches
stale READMEs at commit time — same idea.

---

### M-6 — No `dragon-configure --check`
**Severity:** P2

The notifier fires when `_DRAGON_DEFAULTS` keys are *added* to schema.
It does **not** detect:
- Variables *removed* from schema but still set in the user's `conf.zsh`
  (dead config).
- Variables *renamed* (old name lingers, new name uses default).
- A `conf.zsh` that contains a `DRAGON__*` name that was never in any
  schema version (typo, hand-edit gone wrong).

`dragon-configure --check`: scan `conf.zsh` for `export DRAGON__*=` lines,
intersect with current `_DRAGON_DEFAULTS` keys, list orphans, exit non-zero.
Useful from cron or from M-6's selfcheck.

---

## Section 7 — Drop / cleanup

### D-2 — `DRAGON__FORWARDED` model is documented in two places that can drift
Already covered as A-4. Same root cause; same fix.

---

### D-3 — Aliases reference `vizsh` but mo-shell-tools is the only definition
Not a bug. Just noting that grep for `vizsh` returns one definition + no
docs in CONTRIBUTING (the convention "every command shows up in plugin
README" is satisfied, but no top-level grep-friendly index).

If a `mo-where` / `master-oogway commands` listing existed (U-3 / wishlist),
this becomes a non-issue.

---

## Section 8 — Wishlist

| Item | Why | Effort |
|---|---|---|
| `master-oogway selfcheck` | Replaces removed `doctor`. Non-interactive health probe. CI-friendly. | S |
| `dragon-configure --check` | Detect stale/orphan `conf.zsh` entries. | S |
| `dragon-configure --diff` | Show what user changed vs chosen preset, without launching wizard. | S |
| `master-oogway diff-zshrc` | Show drift between user's `~/.zshrc` and template. | S |
| Per-segment timing in `zshtime` | Locate slow segment (gitstatus vs mo-lan-ssh vs vendored). | M |
| Container test rig | `docker run ubuntu:24.04 bash -c "install.sh && validate"` — catches breakage on fresh OS. | M |
| `mo-lan-ssh --json` for `list`/`status` | Lets users script against the discovery cache. | S |
| `dragon-configure --export <name>` | Save current config as a named preset under `~/.config/master-oogway/presets/`. | S |
| Optional `direnv` quiet integration | Wizard sets `DIRENV_LOG_FORMAT=""` if direnv installed (silences per-cd banner that clashes with the prompt). | XS |
| Strict-mode opt-in for plugins | A `MO_STRICT=1` env var makes plugins `set -u` etc., so contributors catch unset-var bugs faster. | S |

---

## Section 9 — Things that look like bugs but aren't

Called out explicitly so they don't get "cleaned up" by accident.

- **`__dragon_copy_defaults` writes to globals (`REAL_DRAGON__*`).** Looks
  like spaghetti. It's the deliberate consolidation that replaced ~80 lines
  of per-segment boilerplate. A function-return refactor would add forks
  per render. Don't.
- **`zshrc.master-oogway` sources `conf.zsh` *before* `oh-my-zsh.sh`.**
  Intentional — theme defaults use `set_if_unset`, so pre-set values from
  conf.zsh win.
- **The wizard's "Save configuration? [Y/n]" prompt** after stepping through
  every group. Looks redundant. It's the only abort path that doesn't
  require Ctrl+C from the final preview. Keep it.
- **`mo-lan-ssh` SSH wrapper auto-purges LAN host keys on change.** Looks
  insecure. It's deliberate (the README explains the trade-off). LAN trust
  scope. Keep unless threat model changes.
- **`install.sh` uses `exec bash` to re-enter from curl-pipe mode.**
  Intentional — `install.sh` is bash-specific (`set -Eeuo pipefail`
  semantics, `BASH_SOURCE`).
- **Plugin file size (mo-lan-ssh ≈ 8× the average).** Documented in A-1 as
  worth splitting *eventually*, not now.
- **`# Requires:` comment at top of plugin files instead of code.** Looked
  weird at first; it's a deliberate grep-friendly contract that contributors
  read before opening the file.

---

## Section 10 — Release-readiness checklist

Treat the following as gates for tagging `v1.0`. Items are roughly grouped
by category; check off in any order, but ship every category to green
before tagging.

### Code quality
- [ ] All four vendored submodules pinned to specific commits in
      `.gitmodules` (verify with `git submodule status` — no `+` prefix)

### Security
- [ ] S-1 (HashKnownHosts) resolved (drop or scope or opt-in)
- [ ] Confirm `install.sh` won't run on macOS / non-Linux (already does this
      — but add a test that simulates `uname` returning Darwin)

### UX
- [ ] Drift detection emits *something actionable*, not just "go diff it"

### Performance
- [ ] P-1 (single `ip route`) consolidated
- [ ] P-2 (chpwd hook redundancy) measured + dropped if confirmed
- [ ] `zshtime` numbers recorded in `BENCHMARKS.md` for two reference
      machines (desktop + Raspberry Pi)

### Infrastructure (the big ones)
- [ ] **`LICENSE` file added** (MIT recommended)
- [ ] **`.github/workflows/lint.yml` added** (M-2)
- [ ] **`tests/` directory with at least 5 bats tests** (M-1)
- [ ] **`CHANGELOG.md` started** (M-4)
- [ ] **First tag pushed** (`v0.1` covers current state; `v1.0` once the
      above are green)

### Documentation
- [ ] CHANGELOG documents the `# Provides:` → `# Requires:` convention change
- [ ] README links to CHANGELOG from a "What's new" line
- [ ] `master-oogway --version` mentions the tag if HEAD == tag

---

## Section 11 — Suggested implementation order

If I were doing the work, this is the order — each step builds on the
previous and each step is independently shippable.

| # | Item | LOC delta | Risk |
|---|---|---|---|
| 1 | M-3 LICENSE | +21 | none |
| 2 | M-2 CI lint workflow | +30 | none |
| 3 | S-1 drop HashKnownHosts no | -1 | low (one cosmetic regression — `ssh-keygen -R` on hashed entries) |
| 4 | M-1 first 5 bats tests | +200 | none |
| 5 | M-4 CHANGELOG + v0.1 tag | new file | none |
| … | wishlist items | as desired | low |

**After step 2** (LICENSE + CI) you can publicly say "this is being actively
maintained against a verified spec." That's the cheapest credibility step
on the list and it's the one most users will look for.

**After step 4** (first tests) you've crossed the line from "dotfiles
collection" to "actually-maintained tool."

**After step 5** (CHANGELOG + tags) future-you can answer "what did I
ship between Monday and now" without diff archaeology.

---

## Appendix A — Per-file sizes

```
   624  install.sh
   264  zshrc.master-oogway
    25  zshenv.master-oogway
    38  gitconfig.master-oogway
    19  editorconfig.master-oogway
   944  omz-custom/themes/dragon/configure.zsh
   391  omz-custom/themes/dragon/schema.zsh
    76  omz-custom/themes/dragon/dragon.zsh
    52  omz-custom/themes/dragon/notifier.zsh
     8  omz-custom/themes/dragon/aliases.zsh
   794  omz-custom/themes/dragon/parts/*.zsh   (7 files)
   875  omz-custom/plugins/mo-lan-ssh/*.zsh    (2 files)
   754  omz-custom/plugins/mo-*/*.plugin.zsh   (19 files, mo-lan-ssh excluded)
 ─────
  3235  total hand-maintained shell
```

## Appendix B — Function counts

| File | Functions |
|---|---|
| `install.sh` | 25 |
| `omz-custom/themes/dragon/configure.zsh` | 15 |
| `omz-custom/plugins/mo-lan-ssh/mo-lan-ssh.plugin.zsh` | 19 |
| (all `mo-*` plugins combined) | ~70 |
| (all theme `parts/*.zsh` combined) | ~30 |

## Appendix C — Verification commands

Quick sanity checks the next auditor (or you, in a year) can run:

```bash
# All shell parses cleanly
bash -n install.sh && \
zsh -n omz-custom/themes/dragon/*.zsh \
       omz-custom/themes/dragon/parts/*.zsh \
       omz-custom/plugins/mo-*/mo-*.plugin.zsh \
       omz-custom/plugins/mo-lan-ssh/_mo_lan_discover.zsh

# Shellcheck on the entrypoint
shellcheck install.sh

# Schema hash matches state (run inside a master-oogway shell)
zsh -c 'source omz-custom/themes/dragon/schema.zsh
        _dragon_init_defaults
        printf "%s\n" "${(@k)_DRAGON_DEFAULTS}" | sort | md5sum | cut -d" " -f1'
# Compare with grep '^vars_hash=' ~/.config/master-oogway/state

# Every plugin has a README + the plugin file
for d in omz-custom/plugins/mo-*; do
    name=$(basename "$d")
    [[ -f "$d/$name.plugin.zsh" ]] || echo "MISSING: $d/$name.plugin.zsh"
    [[ -f "$d/README.md" ]] || echo "MISSING: $d/README.md"
done

# All overrides define an `r<name>` escape hatch
for f in omz-custom/plugins/mo-*-override/mo-*-override.plugin.zsh; do
    grep -q "alias r" "$f" || echo "NO ESCAPE HATCH: $f"
done

# `# Requires:` convention coverage
grep -l '^# Requires:' omz-custom/plugins/mo-*/mo-*.plugin.zsh | wc -l
# vs total plugins
ls omz-custom/plugins/mo-*/mo-*.plugin.zsh | wc -l
```

---

*End of audit.*
