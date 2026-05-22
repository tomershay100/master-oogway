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
| **Testability** | **—** | No automated tests or CI (both skipped). |
| Documentation | A | All READMEs synced this week, CONTRIBUTING is current. Three stale zshrc comments (D-1). |
| Distribution | C+ | `LICENSE` added (MIT). No version tags. No `CHANGELOG`. Vendored submodules all have these — host repo doesn't. |
| Maintainability | A− | Schema-driven design; consistent conventions; thoughtful comments. mo-lan-ssh is getting big (A-1). |

---

## Section 1 — Bugs (real, reproducible)

## Section 2 — Security findings

## Section 3 — UX friction

## Section 4 — Performance

## Section 5 — Architecture / refactor observations

---

## Section 6 — Infrastructure gaps (the real production-readiness story)

## Section 7 — Drop / cleanup

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

---

## Section 10 — Release-readiness checklist

Treat the following as gates for tagging `v1.0`. Items are roughly grouped
by category; check off in any order, but ship every category to green
before tagging.

### Code quality
- [ ] All four vendored submodules pinned to specific commits in
      `.gitmodules` (verify with `git submodule status` — no `+` prefix)

### Security
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
- [x] **`LICENSE` file added** (MIT)

### Documentation
- [ ] README links to CHANGELOG from a "What's new" line
- [ ] `master-oogway --version` mentions the tag if HEAD == tag

---

## Section 11 — Suggested implementation order

If I were doing the work, this is the order — each step builds on the
previous and each step is independently shippable.

| # | Item | LOC delta | Risk |
|---|---|---|---|
| 1 | M-3 LICENSE | +21 | none |
| 2 | S-1 drop HashKnownHosts no | -1 | low (one cosmetic regression — `ssh-keygen -R` on hashed entries) |
| … | wishlist items | as desired | low |

**After step 2** (LICENSE + CI) you can publicly say "this is being actively
maintained against a verified spec." That's the cheapest credibility step
on the list and it's the one most users will look for.

**After step 4** (CHANGELOG + tags) future-you can answer "what did I
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
```

---

*End of audit.*
