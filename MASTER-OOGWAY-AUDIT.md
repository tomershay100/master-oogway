# Master-Oogway: Full Audit & Enhancement Proposal

> Generated 2026-05-24. **Describe-only — nothing implemented yet.**
> Cherry-pick items, then drive the per-item describe → implement → commit
> cycle (per the project's audit-workflow rule).

---

## 1. System Overview Summary

**Shape.** Oh-my-zsh override at `~/.master-oogway/omz-custom/` (via
`ZSH_CUSTOM`). One installer (`install.sh`) symlinks `~/.zshrc`,
`~/.gitconfig`, `~/.editorconfig`, `~/.zshenv`, then bootstraps submodules.

**Three layers:**

1. **Theme layer** — `themes/dragon/` is split into `schema.zsh` (data:
   defaults, types, hints, groups, presets) → `dragon.zsh` (loader, hook
   wiring) → `parts/*.zsh` (renderers: helpers, left/right segments,
   separators, git, prompt assembly, transient). Configuration is
   interactive (`dragon-configure`) and persists to
   `~/.config/master-oogway/conf.zsh`. Presets live in
   `presets/<name>.conf.zsh` and contain only `export DRAGON__*='value'`
   lines.
2. **Plugin layer** — 26 `mo-*` plugins + 4 vendored submodules
   (gitstatus, you-should-use, zsh-autosuggestions,
   zsh-syntax-highlighting). Each has `*.plugin.zsh`, `README.md`,
   optional `requirements.zsh` (hard deps — warn on load) and
   `optional-deps.zsh` (soft deps — surfaced by installer).
3. **User-extension layer** — Three drop-in dirs that `zshrc.master-oogway`
   walks: `custom-pre-zsh/*.zsh` (before plugins),
   `custom-plugins/<name>/<name>.plugin.zsh` (plugin-shaped),
   `custom-zsh/*.zsh` (after plugins).

**Strengths.** Schema-driven theming, per-function self-guard discipline
(no global "I exist" checks), explicit override-vs-additive plugin
distinction in `zshrc`, mature ssh-config workflow (`mo-lan-ssh`),
`gitstatus` sub-shell already wired for fast git status.

**Weaknesses (high-level).**

- Theme presets only configure *colors and separators* — none exercise the
  rich SSH-override / transient / stash / remote-state variable space.
- Several plugins have only 1–2 commands and feel under-grown (`mo-apps`,
  `mo-build`, `mo-docs`, `mo-nvim-override`, `mo-auto-ls`).
- No central command palette / discovery — `mo-where` exists but is
  reverse-lookup only.
- No theme-preview gallery; you have to flip presets one at a time.

---

## 2. Plugin-by-Plugin Analysis (the 26 mo-* plugins)

Format: **plugin** — what it does → real issues found → small improvements
that fit today's design.

### Overrides

| Plugin | Notes |
|---|---|
| **mo-eza-override** | Solid. `--hyperlink` known-broken with pipes — comment is accurate. No issues. |
| **mo-bat-override** | Sets `MANPAGER`. **Conflict:** the `colored-man-pages` plugin (loaded earlier in `plugins=`) *also* sets `MANPAGER`. Whichever runs last wins; today that's mo-bat — fine, but undocumented and fragile. Add a one-line comment in `zshrc.master-oogway` explaining the override. |
| **mo-nvim-override** | Single alias. Doesn't redirect `vimdiff`, `view`, `ex`. Trivial expansion. |
| **mo-safety-override** | `_confirm_reboot` covers `reboot` only. `shutdown`, `poweroff`, `halt`, `systemctl reboot/poweroff` are all unguarded. |
| **mo-colorize-override** | Only `ip` and `diff`. Could add `dmesg --color=always`, `journalctl --no-pager`-friendly variants. Sparse. |
| **mo-trash** | `trash-restore` re-reads `trash-list` twice — minor cost. **Real issue:** `trash-prune` invokes `trash-empty --trash-dir=... <days>` but `trash-empty`'s positional `<days>` argument is undocumented in most distros and version-dependent (trash-cli ≥0.21). Pin a version check. |

### Git-and-VCS

| Plugin | Notes |
|---|---|
| **mo-git** | Largest additive plugin. (a) `groot` silently returns 0 when not in a repo — should say so. (b) `gtag` uses `--sort=-version:refname` which orders non-semver tags wrong (e.g., `release-2024-05`); fall back to `creatordate` for those. (c) `flog` only copies the hash — no checkout/show/cherry-pick action. (d) No worktree commands. (e) `gd="git difftool -y"` — silent `-y` auto-accepts; if the user configures a destructive difftool this is unsafe. |

### Navigation & Files

| Plugin | Notes |
|---|---|
| **mo-dirs** | `up <name>` is O(depth) — fine. `tmpcd` leaks `/tmp` entries; add an opt-in cleanup hook (e.g., remove dirs on shell exit if empty). `fcd` doesn't go above CWD — common request. `n="open ."` is Mac-leaning; on Linux it's `xdg-open` and you've got nothing handling that. |
| **mo-files** | Excellent zip-slip guard. `compress` lacks `-l/--level`; `bak` always copies — add `--move`. `fp` only copies path; add `--insert` (echoes to `print -z` for prompt insertion). |
| **mo-search** | `grep()` function shadows ALL grep calls in the shell — including those inside other functions. **Subtle gotcha:** the wrapper adds `--exclude-dir=...` which can *suppress matches inside `.git/`* and break tooling that intentionally greps `.git/`. Consider scoping the wrapper as `g`/`gri` instead. `f="find . | grepi"` traverses everything (no `-not -path '*/.git/*'`) — slow in big trees. |

### Processes & Network

| Plugin | Notes |
|---|---|
| **mo-process** | `psgrep` shows command but no user column; `fkill` has TOCTOU between fzf display and kill (rare). Missing: `kill-port <port>` (compose of `port` + `kill`). |
| **mo-network** | `natip` has *no* fallback — `ifconfig.me` outage = silent breakage. Try a list (`ifconfig.me`, `icanhazip.com`, `api.ipify.org`). `serve` binds to 127.0.0.1 — good — but Python's HTTP server is single-threaded and chokes on large files; document the limit. `sshto` `Include` resolution is actually correct per `ssh_config(5)` (relative to `~/.ssh/`). |
| **mo-ssh-tunnel** | No state. `tunnel -b` orphans the SSH process without any way to list/kill it. Add `tunnel --list` (parse `pgrep -af 'ssh.*-N.*-L\|-R'`) and `tunnel --kill <port>`. Consider named profiles (`~/.config/master-oogway/tunnels.yml`). |
| **mo-lan-ssh** | Most mature plugin. Minor: `_mo_lan_status` does N greps; cache once. Add `mo-lan-ssh ping <host>` (fast reachability check using cached port info). |
| **mo-projects** | Registers an alias *per directory* under `~/projects/` at shell-start — for users with 200+ project dirs this floods `aliases` (and breaks `you-should-use` which scans aliases). Add `MO_PROJECTS_MAX_ALIASES=50` cap. Should accept `MO_PROJECTS_DIRS=(~/projects ~/work)` (list). Missing: `pnew <name>` (`mkdir + cd + git init`). |

### Productivity & Meta

| Plugin | Notes |
|---|---|
| **mo-shell-tools** | Grab-bag of 11 commands. (a) `h` is silently capped to 50 — document `h 200`. (b) `calc` allows negatives but lacks an explicit error mode. (c) `please` doesn't preserve env; consider `sudo -E` opt-in. |
| **mo-env** | `fenv -e` reads new value but doesn't *unset* the var on empty input — that's likely the user's intent. |
| **mo-build** | Two commands. Worth renaming to `mo-make` with `mb <target>`, `mt` (test), and Cargo/npm dispatch. |
| **mo-docs** | Only `md2pdf`. Underspecced for the name — add `md2html`, `md2docx`, `pdf-merge`, `pdf-split`. |
| **mo-mkscript** | Bash-only template. Add `--lang python|node|go|rust` and auto-`shellcheck` for bash. |
| **mo-color** | Solid. Missing: contrast (WCAG ratio), hex → nearest-named, gradient generator. |
| **mo-welcome** | ✓ env-configurable via `MO_WELCOME_FIELDS`. |
| **mo-cli** | Add `master-oogway plugins` (list + on/off toggle), `master-oogway theme <preset>` (one-shot apply), `master-oogway doctor` (env health). |
| **mo-auto-ls** | Always runs `ls`. **Real issue:** in directories with > 5000 entries this is noticeably slow on first `cd`. Add `MO_AUTO_LS_MAX_ENTRIES=500`. |
| **mo-man** | ✓ no-arg fzf picker with live preview. |
| **mo-apps** | One alias. Delete or absorb into a `mo-launchers` plugin. |

---

## 3. Plugin Improvement Suggestions (concrete, by priority)

**P0 (correctness/safety):**

1. `mo-search` — rename grep wrapper to `g`/`gri` to stop shadowing system
   `grep`.
2. `mo-safety-override` — extend `_confirm_reboot` to `shutdown`,
   `poweroff`, `halt`, `systemctl reboot|poweroff`.
3. `mo-projects` — cap alias registrations with `MO_PROJECTS_MAX_ALIASES`.
4. `mo-network/natip` — multi-endpoint fallback.

**P1 (high UX value, small change):**

5. `mo-git` — add `gworktree` (add/list/remove via fzf), `gconflict`
   (open conflicts in `$EDITOR`).
6. `mo-ssh-tunnel` — `tunnel --list` / `--kill`.
7. `mo-dirs` — `back` (toggle to previous dir),
   `MO_TMPCD_AUTO_CLEAN=true` exit hook.


**P2 (capability expansion):**

11. `mo-docs` — `md2html`, `pdf-merge`, `pdf-split`.
12. `mo-mkscript` — multi-language templates.
13. `mo-build` → rename `mo-make`, add language-aware test/build dispatch.
14. `mo-color` — contrast checker, nearest-named lookup.

**P3 (sparse plugins — merge or expand):**

15. `mo-apps` + `mo-nvim-override` + `mo-colorize-override` → leave as-is
    OR consolidate the trivial ones into `mo-defaults`.

---

## 4. New Plugin Proposals

Each follows the existing `mo-*` contract: `*.plugin.zsh`, `README.md`,
optional `requirements.zsh` / `optional-deps.zsh`, per-function
self-guards, `-h/--help` on every command.

### A. `mo-bookmarks` — Named directory jumps

**Purpose:** `mark <name>`, `jump <name>`, `marks`, `unmark <name>`.
Backed by `~/.config/master-oogway/marks` (one `name=path` per line).
**Benefit:** Faster than `mo-projects` for cross-project paths
(`mark notes ~/sync/notes`, then `jump notes` from anywhere).

### B. `mo-clip` — Clipboard read/write/history

**Purpose:** `cb <text>` write, `cbp` paste, `cbh` history (last 50 lines
via tracked wrapper), `cbi <file>` copy file contents.
**Integration:** Absorbs `clip` from `mo-shell-tools`. Records to
`$XDG_DATA_HOME/master-oogway/clip-history`.

### C. `mo-todo` — Plain-text task list

**Purpose:** `todo add "fix X"`, `todo list`, `todo done <n>`,
`todo today`. Single file `~/TODO.md`.
**Integration:** Optional `mo-welcome` integration to show open count.

### D. `mo-watch` — File/command watcher

**Purpose:** `watchcmd 'cmd' [interval]` with diff highlight (like
`watch -d`). `watchfile <file> 'cmd'` (rerun when file changes — uses
`entr` if installed, polls otherwise).

### E. `mo-secrets` — Encrypted KV store

**Purpose:** `secret get/set/list/rm <name>` backed by `pass` if
installed, else age/gpg-encrypted file.
**Integration:** Hard dep on `gpg` or `age`.

### F. `mo-notes` — Per-directory notes

**Purpose:** `note` (open `.notes.md` in cwd), `note <text>` (append
timestamped line), `notes` (list .notes.md upwards), `noteg <pat>` (grep
across them).

### G. `mo-git-flow` — Heavier git helpers

**Purpose:** `wip` (`git add -A && git commit -m WIP --no-verify`),
`unwip` (soft reset if HEAD subject is WIP), `gtw <branch>` (create
worktree at `../<repo>-<branch>`), `gtwl`, `gtwx <branch>` (remove),
`gconflict` (open all conflicts in `$EDITOR`).

### H. `mo-systemd` — Service shortcut

**Purpose:** `svc status|start|stop|restart|log|enable|disable <unit>`.
`svc f` (fzf picker over all units).
**Integration:** `systemctl` hard dep. Skip-on-non-systemd guard.

### I. `mo-docker` (a.k.a. `mo-container`)

**Purpose:** `dps` (pretty docker ps), `dexec` (fzf into container),
`dlog` (fzf logs), `dprune` (safe prune), `dimg` (image picker).
**Integration:** Hard dep on `docker` or `podman` (auto-detect).

### J. `mo-cheat` — Quick reference

**Purpose:** `cheat <cmd>` queries `tldr` if installed, else `cheat.sh`
over curl with caching.

### K. `mo-test` — Test runner auto-detect

**Purpose:** `t` walks up to find `pyproject.toml`, `package.json`,
`Cargo.toml`, `Makefile`, `pytest.ini` and runs the right test command.

### L. `mo-toggle` — Plugin enable/disable without editing zshrc

**Purpose:** `mo-toggle list`, `mo-toggle off <name>`, `mo-toggle on
<name>`. Writes `~/.config/master-oogway/disabled-plugins`;
`zshrc.master-oogway` is patched to skip those entries.

### M. `mo-quick-edit` — `qed <pattern>`

**Purpose:** Run `rg --files | fzf` filtered by pattern, multi-select,
open all in `$EDITOR` as args.

### N. `mo-history` — `hgrep`, `hstat`

**Purpose:** `hgrep <pat>` (faster than Ctrl+R for the common case —
emits `print -z`). `hstat` shows top 20 most-used commands.

### O. `mo-cap` — Terminal recording

**Purpose:** `cap [duration]` wraps `asciinema rec`, auto-uploads or
saves locally. Hard dep on `asciinema`.

### P. `mo-update` — Repo update notifier (see F10 in §6)

---

## 6. New System-Level Features

| #  | Feature | Problem it solves | Complexity | Impact |
|----|---------|-------------------|------------|--------|
| F1 | **Dragon hot-reload daemon** — `dragon-watch` (inotifywait) re-sources `conf.zsh` on save | Editing a preset means `rezsh` per change — slow to iterate | Medium | High |
| F4 | **Command palette** — `mo-do` opens fzf with every command across every plugin (parsed at install time → cache) | Discovery is currently README-by-README | Medium | High |
| F5 | **Plugin enable/disable UI** — `master-oogway plugins` interactive list w/ space-to-toggle, persists to `disabled-plugins` | Today you must edit `~/.zshrc` | Medium | Medium |
| F6 | **Per-host config** — `~/.config/master-oogway/hosts/<hostname>.zsh` auto-sourced after `conf.zsh` | Same dotfile across many machines forces lowest common denominator | Low | High |
| F7 | **Per-project config** — `.mo.zsh` in project root auto-sourced when `cd`ing into it (chpwd hook) | direnv-lite for shell aliases | Medium | High |
| F8 | **Doctor** — `master-oogway doctor` runs a health checklist (fonts, plugins, ssh-include, missing deps, shell-startup time) | Diagnosing breakages is currently artisanal | Medium | High |
| F9 | **Onboarding wizard** — `master-oogway init` runs a 60-second interview: terminal? nerd font? primary use? → picks preset + suggests plugins | Today first-run is `dragon-configure` only, which is theme-only | Medium | High |
| F10 | **Update notifier** — non-blocking check if `~/.master-oogway` origin has newer commit; surfaced in `mo-welcome` banner | Manual `master-oogway update` only | Low | Medium |
| F11 | **Usage analytics (opt-in)** — local SQLite log of command usage; `mo-stats top`, `mo-stats trend` | Helps prune unused aliases, suggest new ones | Medium | Medium |
| F12 | **Plugin marketplace** — `master-oogway plugin install <user/repo>` clones into `custom-plugins/`; `plugin list/upgrade/remove` | Sharing community plugins requires manual clone | Medium | High (long-term) |
| F13 | **Theme export/import** — `dragon-configure --export name` exists; add `--import <file-or-url>` for sharing presets | One-way ramp today | Low | Medium |
| F14 | **Keybindings panel** — `master-oogway keys` lists every active key binding with its widget and origin plugin | Discovering what `^[[1;5C` does today means grepping the source | Low | Medium |
| F15 | **Audit log** — wrap every destructive override (`rm`→trash, `mv -i`, `_confirm_reboot`) to append a tamper-log line. `mo-log destructive` shows last N. | Forensics after "did I really delete that?" | Medium | Low |
| F16 | **First-run safety prompt** for `mo-projects` if aliases > N | See plugin issue above | Low | Medium |

---

## 7. Final Recommendations — Prioritized Roadmap

> Grouped by *return per hour* so you can sequence properly. Each item is
> a one-PR-sized chunk so the audit-workflow cycle
> (describe → wait → impl → wait → commit) applies cleanly.

### Tier 1 — Ship this week (low risk, high felt-value)

1. **F2 `dragon-gallery`** — preview every preset in one screen.
2. **Presets 1–19 above** — drop 19 new `.conf.zsh` files; no code
   changes needed.
3. **Plugin P0 fixes** — grep rename (`g`/`gri`), shutdown/poweroff
   coverage in `mo-safety-override`, `natip` fallback list,
   `MO_PROJECTS_MAX_ALIASES`.
4. **F14 `master-oogway keys`** — keybindings panel (parse `bindkey -L`).
5. **F8 `master-oogway doctor`** — checklist (fonts, gitstatus, missing
   deps, ssh include, startup time).

### Tier 2 — Next sprint (capability expansion)

6. **F4 `mo-do` command palette** — single discovery UI.
7. **F6 per-host config** + **F7 per-project config** — the dotfile
   multiplier.
8. **F10 update notifier** — small change, big polish.
9. **New plugin `mo-bookmarks`** — high felt-value-per-LoC.
10. **`mo-git` worktree + gconflict additions.**
11. **F1 `dragon-watch`** — hot reload for preset authors.
12. **`mo-welcome` field configurability** — every long-time user wants this.

### Tier 3 — Bigger investments

13. **F5 plugin toggle UI** + **F12 marketplace** — share-and-discover loop.
14. **F11 usage analytics** — only valuable if F4 is shipped.
15. **`mo-secrets`, `mo-watch`, `mo-systemd`, `mo-docker`, `mo-test`** —
    each is a 1-evening plugin.
16. **F9 onboarding wizard** — pays off when there are enough
    plugins/presets to warrant guidance.

### Tier 4 — Eventually

17. **`mo-cap`, `mo-cheat`, `mo-notes`** — nice-to-have, post-marketplace.
18. **F15 destructive-action audit log.**

---

## Headline

The biggest lever here is **F4 (command palette) + F2 (theme gallery) +
F9 (onboarding)** as a trio — they convert master-oogway from
"fully-featured dotfile" into "discoverable product." Each individually
is a 1-day item; together they unlock the rest of the roadmap by making
the existing surface area legible.

Recommend Tier 1 next session, then Tier 2 in the one after.
