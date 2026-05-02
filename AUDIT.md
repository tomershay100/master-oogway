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
  ├─ writes ~/.zshrc (first time only) from zshrc.template
  ├─ writes ~/.zshenv, ~/.gitconfig (preserves user.name/email)
  ├─ patches ~/.ssh/config + /etc/ssh/sshd_config (SendEnv/AcceptEnv)
  └─ checks theme-vars hash → suggests `dragon-configure`

zshrc.template                         ── user-owned, opt-in plugins listed
  ├─ sources ~/.config/appa-fino/conf.zsh   (user theme overrides)
  ├─ sources gitstatus.plugin.zsh           (must precede oh-my-zsh)
  ├─ runs oh-my-zsh.sh with ZSH_THEME=dragon
  └─ sources ~/.appa-fino/dragon-notifier.zsh   (new-vars notifier)

zsh-custom.d/                          ── ZSH_CUSTOM (sourced by oh-my-zsh)
  ├─ themes/dragon.zsh-theme → dragon.zsh   (symlink for OMZ loader)
  ├─ themes/dragon.zsh                 ~1 100 lines — the prompt theme
  ├─ themes/schema.zsh                   391 lines — defaults/types/groups
  ├─ dragon-configure.zsh                746 lines — interactive wizard
  ├─ dragon-aliases.zsh                    8 lines — `rezsh` reset
  └─ plugins/af-*/                      17 OMZ plugins (override + additive)
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

- **What:** `conf.zsh` short-circuits with
  `[[ -v DRAGON__ENABLE_USERNAME ]] && return`. If a partial-forward
  happens (e.g. you `SendEnv` only colour vars but not ENABLE_USERNAME),
  the remote `conf.zsh` still applies for everything else — colours collide,
  partial config wins.
- **Why:** SSH `SendEnv DRAGON__*` is all-or-nothing in the wildcard form,
  but if a user customises SendEnv to a subset (or runs `ssh -o
  SendEnv=DRAGON__USERNAME_*`), the canary lies.
- **Fix:** Set a dedicated marker `DRAGON__FORWARDED=1` in the user's
  shell init (not in conf.zsh — in the theme or `~/.zshenv`-equivalent for
  interactive shells), and gate on that. Or: gate per-variable in conf.zsh
  via `[[ ! -v DRAGON__X ]] && export DRAGON__X=...`.
- **Effort:** 🟡

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

- **What:** `sed -i "/^Host \*[[:space:]]*$/a\\${send_line}"` is GNU-sed
  specific.
- **Why:** Won't run on macOS or any BSD without `gsed`. Today the README
  mentions Ubuntu only, so this is documentation-grade, not a bug — but
  drops users on macOS who try `bash -c "$(curl …)"`.
- **Fix:** Either declare Linux-only in the README + add an OS check at the
  top of `install.sh`, or rewrite with a portable awk.
- **Effort:** 🟢

### 1.9 ✅ `sudo sh -c "echo … >> …"` fragile quoting

- **Done:** Replaced with `printf '%s\n' "$accept_line" | sudo tee -a "$sshd_config" >/dev/null`.

### 1.10 ✅ `~/.zshrc` PATH lines double-prepend on re-source

- **Done:** `typeset -U path` added to `zshrc.template`.

### 1.11 `gnucash` flatpak alias clobbers a real binary   🟢 (kept intentionally)

- **Decision:** Kept as-is — intentional for this setup.

### 1.12 ✅ `_echo_ret`, `_cwhich`, `_vwhich` pollute the global namespace

- **Done:** Replaced with direct function definitions `'?'()`, `cwhich()`, `vwhich()`.

### 1.13 ✅ `fpath` function shadows zsh's `$fpath` parameter

- **Done:** Renamed to `fp`.

### 1.14 ✅ Theme uses `kill -WINCH "$$"` to refresh on async git update

- **What:** `__refresh_prompt` posts a SIGWINCH to itself; a `trap WINCH`
  rebuilds the prompt.
- **Why:** Works, but breaks two things:
  (a) any user `trap` on WINCH is overwritten;
  (b) terminals with custom window-resize logic (some terminals send WINCH
  on tab switch) double-refresh.
- **Fix:** Use zsh's `zle reset-prompt` directly from the gitstatus callback
  (it's already inside zle context inside `__reset_prompt`). The signal
  detour is legacy.
- **Effort:** 🟡

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

- **What:** `dragon-configure.zsh:188–222` builds preview-scenario data
  by injecting heredoc-style shell into the `zsh -c` subshell — including
  redefining `dragon__set_job_count` inline.
- **Why:** When the theme refactors a function name or signature, the
  injection silently fails (no error, just a broken preview). Refactor #2.2
  above will absolutely break this.
- **Fix:** Expose **preview hooks** in the theme — empty functions named
  `__dragon_preview_hook_<group>` that the preview can override cleanly.
  Or: make every "fake data" injection set well-known overrideable env
  vars (e.g. `DRAGON__PREVIEW_FAKE_JOB_COUNT=2`) and have the segments
  honour them.
- **Effort:** 🟡

### 2.4 No tests, no CI   🟡

- **What:** Pure-bash codebase with zero coverage.
- **Why:** Every refactor proposed above is unsafe without tests.
- **Fix:** Lightweight test approach using [bats-core]:
  ```
  tests/
    test_install_modes.bats        # mock HOME; assert files copied / linked
    test_plugins_smoke.bats        # source each plugin in clean zsh; assert no error
    test_calc_validation.bats      # assert calc rejects shell metachars
    test_port_validation.bats      # 1..65535 happy + sad paths
    test_extract_dispatch.bats     # assert each archive type calls right cmd
    snapshot_prompt.bats           # render a known config + diff against fixture
  ```
  Wire into a tiny GH Actions workflow (`bats tests/`).
- **Effort:** 🟡 (initial), 🟢 (per-test ongoing)

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
  - Removes `~/.appa-fino`, `~/.config/appa-fino`
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

- **What:** `zshrc.template` does `[[ -f … ]] && source conf.zsh`. If the
  user hand-edits and breaks it (unmatched quote), the whole shell startup
  fails.
- **Fix:** `source ... 2>/dev/null || warn "conf.zsh has a syntax error"`
  and have `dragon-configure` validate (`zsh -n conf.zsh`) before writing.
- **Effort:** 🟢

### 2.9 Plugin loading is eager   🔴

- **What:** All 17 af-* plugins source on shell startup, even ones rarely
  invoked (`md2pdf`, `serve`, `frg`).
- **Fix:** zsh-defer + lazy alias trick. Only worth it if startup time is
  actually measured as a problem.
- **Effort:** 🔴

### 2.10 ✅ `_install_zshrc` detection is fragile

- **What:** Subsequent runs back off if `.appa-fino` appears anywhere in
  `~/.zshrc` — including in a comment.
- **Fix:** Use a structured marker `# appa-fino:managed v=<version>` so
  detection is exact.
- **Effort:** 🟢

### 2.11 ✅ No drop-in directory for user aliases / zsh extensions

- **Done:** `~/.config/appa-fino/custom-pre-zsh/` (before plugins) and
  `custom-zsh/` (after plugins) created by `install.sh`; sourced via
  `*.zsh(N)` glob loops in `zshrc.template`.

### 2.12 Bundle name = theme name → can't switch theme cleanly   🟡

- **What:** "master-oogway" is the bundle name, "dragon" is the theme. These are now separate — the bundle rename is deferred. the bundle and the OMZ theme. A user who
  wants the af-* plugins but a different prompt is stuck.
- **Fix:** Rename the theme file to `fino.zsh-theme` (suggested name: `fino`).
  Keep all bundle paths, env-var prefix, and plugin names as `master-oogway`.
  Add a compat symlink for one release cycle; `install.sh` migrates existing
  `~/.zshrc` entries.
- **Effort:** 🟡

---

## 3. 🟠 Performance

### 3.1 Prompt-time process spawning   🟡

Beyond items 1.5 and 1.6, the prompt also spawns:
- `kill -l "$exit_code"` per prompt when `exit_code > 128` (signal lookup —
  cheap)
- A subshell `print -P "$PROMPT" | sed` (item 1.6)
- The `who | grep …` pipeline (item 1.5)

After fixing 1.5 and 1.6, the rest is ~zero cost. Worth measuring before
optimising further; baseline currently isn't recorded.

**Fix:** Add `tests/perf/prompt_bench.zsh` that uses zsh's `EPOCHREALTIME`
to time `__update_prompt` 1 000 times in a clean repo and a dirty repo,
report avg/p99. Establish a budget (e.g. <5 ms p99) and CI-fail on
regression.
**Effort:** 🟡

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

### 5.1 Dev mode is the most powerful, least documented mode   🟢

- **Fix:** Add a "Development" section to README.md covering: dev mode,
  `make check`, schema drift check, the symlink invariant.
- **Effort:** 🟢

### 5.2 ✅ No `make` / no orchestration entry point

- **Done:** `Makefile` added with `lint`, `test`, `check` targets.

### 5.3 README's command tables drift from plugin reality   🟢

- **Fix:** A single tiny generator: each plugin starts with `# Provides:`
  comment (already does!). A script greps these and rebuilds the tables.
- **Effort:** 🟢

---

## 6. 🟢 New features (prioritised)

| # | Feature | Why | Effort |
|---|---|---|---|
| F1 | **`dragon-doctor`** subcommand — checks symlink, schema drift, missing fzf/eza/etc, conf.zsh syntax, sshd AcceptEnv, gitstatusd binary present | Single first-aid command for users; collapses 80% of bug reports | 🟢 |
| F2 | **Preset live-import** — `dragon-configure --import <url>` to fetch a `conf.zsh` snippet from a URL/gist | Lets people share configs; ties to the wizard's preset story | 🟡 |
| F3 | **Per-directory profile overrides** via direnv hook | Powerful safety signal; already have direnv loaded | 🟡 |
| F4 | **`dragon-bench`** — built-in prompt micro-benchmark | Performance budget enforcement | 🟢 |
| F5 | **atuin** integration | SQLite-backed history with timestamps/duration/exit code | 🟡 |
| F6 | **VCS abstraction** — generalise git segment to jj / hg / fossil | Nice to have for jj users | 🔴 |
| F7 | **Theme switcher** — multiple themes selectable via `ZSH_THEME=` | Natural after 2.12 lands | 🔴 |
| F8 | **Public IP cache for `natip`** (kept as-is — fine as a one-liner) | — | — |
| F9 | ✅ **`fbranch` show recent activity in preview** rather than `git log` | Helpful UX | 🟢 |
| F10 | **First-run "guided tour"** in `dragon-configure` | Walks through what segments mean | 🟡 |

---

## 7. Medium-effort track (next)

1. ~~**2.12** Theme rename~~ ✅ done: bundle=master-oogway, theme=dragon
2. ~~**2.1** Single source of truth for defaults~~ ✅ done
3. ~~**1.5 + 1.6** Prompt-time pipeline removal~~ ✅ done
4. ~~**1.1** Drop the .zsh-theme symlink~~ ✅ done
5. ~~**2.2** Split the theme into `parts/`~~ ✅ done
6. **2.3** Replace preview `group_inject` with hooks
7. **2.4** Bats test suite + GH Actions
8. **F1** `dragon-doctor`
9. **2.6** Uninstall script

## 8. Long-term track

1. **2.9** Lazy plugin loading
2. Drop OMZ dependency
3. **F3** direnv-driven per-directory profiles
4. **F7** Multiple theme variants (`fino-minimal`, `fino-pure`)

---
