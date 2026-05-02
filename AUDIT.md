# master-oogway / dragon — Deep Audit & Improvement Plan

> Scope: the `shared/shell/` submodule (= the standalone `master-oogway` repo).
> Vendored upstreams (gitstatus, zsh-autosuggestions, zsh-syntax-highlighting,
> you-should-use) are NOT in scope.
>
> Format per item: **What** · severity · **Why it matters** · **Fix** · effort.
> Effort tags: 🟢 quick win (≤30 min) · 🟡 medium (≤1 day) · 🔴 long-term.

---

## 0. Summary of architecture as I understand it

```
install.sh (3 modes)                   ── bootstrap / update / dev-symlink
  ├─ writes ~/.zshrc (first time only) from zshrc.master-oogway
  ├─ writes ~/.zshenv, ~/.gitconfig (preserves user.name/email)
  ├─ patches ~/.ssh/config + /etc/ssh/sshd_config (SendEnv/AcceptEnv)
  └─ checks theme-vars hash → suggests `dragon-configure`

zshrc.master-oogway                         ── user-owned, opt-in plugins listed
  ├─ sources ~/.config/master-oogway/conf.zsh   (user theme overrides)
  ├─ sources gitstatus.plugin.zsh               (must precede oh-my-zsh)
  ├─ runs oh-my-zsh.sh with ZSH_THEME=dragon
  └─ sources ~/.master-oogway/dragon-notifier.zsh   (new-vars notifier)

master-oogway-omz-custom/                          ── ZSH_CUSTOM (sourced by oh-my-zsh)
  ├─ themes/dragon.zsh-theme             shim — sources ../dragon/dragon.zsh
  ├─ dragon/dragon.zsh             ~80 lines — defaults loop, hook registration
  ├─ dragon/schema.zsh               391 lines — defaults/types/groups
  ├─ dragon/configure.zsh            746 lines — interactive wizard
  ├─ dragon/aliases.zsh                8 lines — `rezsh` reset
  ├─ dragon/parts/                   7 files  — prompt segments, git, transient
  └─ plugins/mo-*/                      17 OMZ plugins (override + additive)
```

Total in-scope code: ~3 700 lines. Non-vendored, mostly mature, generally
well-organised. The biggest structural risks are **schema-vs-theme drift**,
**prompt-time performance**, and **a few hidden coupling points** (the
single-var SSH canary, the hard-coded preview injection, the symlink).

---

## 1. 🔴 Bugs & correctness

### 1.1 ✅ OMZ theme loading depended on a symlink

- **Done:** Renamed `dragon.zsh` → `dragon.zsh-theme` (real file, not symlink).
  No more portability hazard for users on filesystems that don't preserve
  symlinks (Windows, some zip archives).

### 1.2 ✅ No automated guard against schema/theme drift

- **Done:** `tests/check_schema.sh` added; `make test` runs it.

### 1.3 `WEBKIT_DISABLE_COMPOSITING_MODE=1` leaks personal workaround   🟢 (kept intentionally)

- **Decision:** Kept as-is — the GnuCash flatpak alias and workaround are
  intentional for this setup.

### 1.4 ✅ SSH theme-forwarding canary is fragile (single var)

- **Done:** `conf.zsh` now gates on `DRAGON__FORWARDED=1` (a dedicated
  marker) instead of checking for a random theme var. `dragon-configure.zsh`
  exports `DRAGON__FORWARDED=1` so it travels with `SendEnv DRAGON__*`.

### 1.5 ✅ `__set_ssh_connection_count_content` ran a 5-stage pipeline per prompt

- **Done:** Rewrote in pure zsh — `${(f)$(who)}` into an array, filtered with
  `${(M)arr[@]:#*pts*}` and regex match, no grep/awk subprocesses.

### 1.6 ✅ `__calc_prompt_length` stripped ANSI per prompt via sed

- **Done:** Replaced `print -P "$PROMPT" | sed` with `${(%)PROMPT}` (in-process
  prompt expansion) + `${str//$'\e['[0-9;]#m/}` (pure zsh ANSI strip).
  Zero subprocesses.

### 1.7 ✅ `_install_sshd_acceptenv` silently `sudo`s

- **Done:** Gated behind `confirm` prompt — user must explicitly consent.

### 1.8 ✅ `install.sh` — GNU sed `a\` syntax is non-portable

- **Done:** `install.sh` already has `[[ "$(uname)" == "Linux" ]] || die "dragon requires Linux (Ubuntu 24.04). macOS/BSD are not supported."` — Linux-only OS guard in place. GNU sed usage is acceptable.

### 1.9 ✅ `sudo sh -c "echo … >> …"` fragile quoting

- **Done:** Replaced with `printf '%s\n' "$accept_line" | sudo tee -a "$sshd_config" >/dev/null`.

### 1.10 ✅ `~/.zshrc` PATH lines double-prepend on re-source

- **Done:** `typeset -U path` added to `zshrc.master-oogway`.

### 1.11 `gnucash` flatpak alias clobbers a real binary   🟢 (kept intentionally)

- **Decision:** Kept as-is — intentional for this setup.

### 1.12 ✅ `_echo_ret`, `_cwhich`, `_vwhich` pollute the global namespace

- **Done:** Replaced with direct function definitions `'?'()`, `cwhich()`, `vwhich()`.

### 1.13 ✅ `fpath` function shadows zsh's `$fpath` parameter

- **Done:** Renamed to `fp`.

### 1.14 ✅ Theme uses `kill -WINCH "$$"` to refresh on async git update

- **Done:** `__refresh_prompt` now calls `zle reset-prompt` directly.
  `kill -WINCH` and the WINCH trap are gone entirely. Transient prompt
  wired via `zle -N zle-line-finish __dragon_zle_line_finish` (was missing
  after the parts/ split — fixed).

### 1.15 ✅ Prefix/suffix strings aren't `%`-escaped before going to PROMPT

- **Done:** `__dragon__show` now escapes `%` → `%%` in prefix/suffix via `${${(P)var}//\%/%%}`.

---

## 2. 🟠 Architecture & maintainability

### 2.1 ✅ Theme defaults duplicated in two places

- **Done:** `schema.zsh` is now the single source of truth (`_DRAGON_DEFAULTS`).
  `dragon.zsh` sources `schema.zsh`, calls `_dragon_init_defaults`, then
  iterates `${(@kv)_DRAGON_DEFAULTS}` to call `set_if_unset` for each key.
  `USE_NERD_FONT` kept explicit (SSH-conditional default). ~133 hardcoded
  lines collapsed to a 5-line loop.

### 2.2 ✅ Theme split into `parts/`

- **Done:** `themes/dragon.zsh-theme` (~80 lines: defaults loop, hook
  registration) sources 7 part files in `themes/parts/`:
  - `helpers.zsh` (~70 lines) — `__get_xterm_*`, `__dragon__show`
  - `segments_left.zsh` (~155 lines) — username, hostname, directory, prompt_char, ssh_prefix
  - `separators.zsh` (~125 lines) — segment separators, multiline prompts
  - `git.zsh` (~80 lines) — gitstatus integration + git segment
  - `segments_right.zsh` (~200 lines) — date_time, exec_timer, ssh_conn, jobs, exit_status
  - `prompt.zsh` (~135 lines) — `__calc_prompt_length`, `dragon__set_lprompt`/`set_rprompt`
  - `transient.zsh` (~100 lines) — zle hooks, gitstatus glue, prompt refresh
  All 53 functions verified present after split. `make check` clean.

### 2.3 ✅ Preview "group_inject" code is brittle inline shell

- **Done:** Preview fake data now uses `DRAGON__PREVIEW_FAKE_*` env vars
  (`DRAGON__PREVIEW_FAKE_EXEC_TIME`, `DRAGON__PREVIEW_FAKE_JOB_COUNT`,
  `DRAGON__PREVIEW_FAKE_SSH_CONN_COUNT`). Segments read these vars; no
  inline function redefinition. Unset after preview via explicit `unset`.

### 2.4 ~~No tests, no CI~~ — declined

- **Decision:** `make check` (bash -n, zsh -n, shellcheck, schema drift) is
  sufficient. Full bats suite + GH Actions is overkill for a personal tool.

### 2.5 ✅ No version metadata / no `--version`

- **Done:** `install.sh --version` and `dragon-configure --version` both
  print `master-oogway YYYY-MM-DD_HHmmss-<hash>` from the installed git commit.

### 2.6 ✅ No uninstall path

- **What:** Once installed, undoing it requires manual file deletion +
  unwinding the SSH config edits.
- **Why:** Users who try it and bounce off carry residue; undermines the
  "safe to try" framing of `curl | bash`.
- **Fix:** `install.sh --uninstall` that:
  - Restores `~/.zshrc.pre-master-oogway` if present
  - Removes `~/.master-oogway`, `~/.config/master-oogway`
  - Removes `SendEnv DRAGON__*` line from `~/.ssh/config`
  - Removes `AcceptEnv DRAGON__*` from `/etc/ssh/sshd_config` (with
    `confirm`)
- **Effort:** 🟡

### 2.7 ✅ New-vars notifier nags forever

- **What:** The notifier runs on every shell start and nags until the user
  runs `dragon-configure --new-only`.
- **Why:** Cheap (a grep + md5sum), but annoying.
- **Fix:** Track a "dismissed_hash" in the state file — print once per new
  hash. User can run `dragon-configure --dismiss` if they don't care.
- **Effort:** 🟢

### 2.8 ✅ No defensive sourcing of `conf.zsh`

- **What:** `zshrc.master-oogway` does `[[ -f … ]] && source conf.zsh`. If the
  user hand-edits and breaks it (unmatched quote), the whole shell startup
  fails.
- **Fix:** `source ... 2>/dev/null || warn "conf.zsh has a syntax error"`
  and have `dragon-configure` validate (`zsh -n conf.zsh`) before writing.
- **Effort:** 🟢

### 2.9 ~~Plugin loading is eager~~ — declined

- **Decision:** Startup cost is negligible (small alias/function definitions,
  no subprocesses). zsh-defer adds complexity with no measurable benefit.
  Skipped.

### 2.10 ✅ `_install_zshrc` detection is fragile

- **What:** Subsequent runs back off if `.master-oogway` appears anywhere in
  `~/.zshrc` — including in a comment.
- **Fix:** Use a structured marker `# master-oogway:managed` so detection is exact.
- **Effort:** 🟢

### 2.11 ✅ No drop-in directory for user aliases / zsh extensions

- **Done:** `~/.config/master-oogway/custom-pre-zsh/` (before plugins) and
  `custom-zsh/` (after plugins) created by `install.sh`; sourced via
  `*.zsh(N)` glob loops in `zshrc.master-oogway`.

### 2.12 ✅ Bundle name = theme name → can't switch theme cleanly

- **Done:** Bundle identity is `master-oogway` (paths, install marker, plugin
  prefix `mo-*`). Theme identity is `dragon` (`DRAGON__*` vars, `ZSH_THEME`,
  `dragon-configure`, function prefixes). Fully separated — a user can set
  `ZSH_THEME` to any OMZ theme independently of the mo-* plugins.

---

## 3. 🟠 Performance

### 3.1 ✅ Prompt-time process spawning

- **Done:** 1.5 eliminated `who|grep|grep|awk` → pure zsh array filtering.
  1.6 eliminated `print -P|sed` → `${(%)var}` + pure zsh ANSI strip.
  Remaining cost is `kill -l` on exit codes >128 (one fork, infrequent,
  negligible). All other prompt work is pure zsh or async gitstatus.
- Benchmark / regression budget deferred to F4 (`dragon-bench`).

### 3.2 `gitstatusd` query timeout is hard-coded `0.03`   🟢 (kept as-is)

- **Decision:** Default 30 ms is fine for the target hardware; skipped.

---

## 4. 🟡 Security

### 4.1 `calc` whitelist is solid — no action needed

- Already correct; the whitelist blocks bc's `system()` and shell metacharacters.

### 4.2 `install.sh` git pull is unauthenticated over HTTPS   (kept intentionally)

- **Decision:** main branch is always production-ready; no SHA-pinning needed.

### 4.3 ✅ `~/.gitconfig` is fully replaced on update

- **Done:** Bundle settings live in `~/.gitconfig.master-oogway` (always
  updated). `~/.gitconfig` is created once with `[user]` + `[include]` and
  never overwritten. Migration backs up the old file to `.pre-master-oogway`.

---

## 5. 🟡 DX / docs

### 5.1 ✅ Dev mode is the most powerful, least documented mode

- **Done:** `CONTRIBUTING.md` added — repo layout, three install modes,
  edit→test loop per file category, how to add a plugin, schema system,
  theme architecture, and `make check` / `make readme` usage.

### 5.2 ✅ No `make` / no orchestration entry point

- **Done:** `Makefile` with `lint`, `test`, `check`, `readme` targets.

### 5.3 ✅ README's command tables drift from plugin reality

- **Done:** `scripts/gen_readme.sh` reads `# Provides:` from each
  `mo-*.plugin.zsh` (skipping `-override` plugins) and rewrites the
  additive plugins table in `README.md` between sentinel comments.
  Run via `make readme`.

---

## 6. 🟢 New features (prioritised)

| # | Feature | Why | Effort |
|---|---|---|---|
| F1 | ~~**`dragon-doctor`** subcommand~~ — declined | — | — |
| F2 | ~~**Preset live-import** — `dragon-configure --import <url>`~~ — declined | — | — |
| F3 | ~~**Per-directory profile overrides** via direnv hook~~ — declined | — | — |
| F4 | ~~**`dragon-bench`** — built-in prompt micro-benchmark~~ — declined | — | — |
| F5 | **atuin** integration | SQLite-backed history with timestamps/duration/exit code | 🟡 |
| F6 | **VCS abstraction** — generalise git segment to jj / hg / fossil | Nice to have for jj users | 🔴 |
| F7 | **Theme switcher** — multiple themes selectable via `ZSH_THEME=` | Natural after 2.12 lands | 🔴 |
| F8 | **Public IP cache for `natip`** (kept as-is — fine as a one-liner) | — | — |
| F9 | ✅ **`fbranch` show recent activity in preview** rather than `git log` | Helpful UX | 🟢 |
| F10 | ✅ **First-run "guided tour"** in `dragon-configure` | Walks through what segments mean | 🟡 |

---

## 7. Medium-effort track (next)

1. ~~**2.12** Theme rename~~ ✅ done: bundle=master-oogway, theme=dragon
2. ~~**2.1** Single source of truth for defaults~~ ✅ done
3. ~~**1.5 + 1.6** Prompt-time pipeline removal~~ ✅ done
4. ~~**1.1** Drop the .zsh-theme symlink~~ ✅ done
5. ~~**2.2** Split the theme into `parts/`~~ ✅ done
6. ~~**2.3** Replace preview `group_inject` with hooks~~ ✅ done
7. ~~**2.4** Bats test suite + GH Actions~~ — declined
8. ~~**F1** `dragon-doctor`~~ — declined
9. ~~**2.6** Uninstall script~~ ✅ done
10. ~~**5.1** CONTRIBUTING.md~~ ✅ done
11. ~~**5.3** README generator (`make readme`)~~ ✅ done
12. ~~**F10** First-run guided tour~~ ✅ done

## 8. Long-term track

1. ~~**2.9** Lazy plugin loading~~ — declined
2. Drop OMZ dependency
3. ~~**F3** direnv-driven per-directory profiles~~ — declined
4. **F7** Multiple theme variants
5. **F5** atuin integration

---
