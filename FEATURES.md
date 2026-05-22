# master-oogway — feature ideas

**Date:** 2026-05-20
**Companion to:** [MASTER-OOGWAY-AUDIT.md](MASTER-OOGWAY-AUDIT.md) (covers
bugs / hardening / release-readiness).
**Scope:** *additive* ideas — what the project could do that it does not
do today. Nothing here is a bug; nothing here is required for v1.0.

The audit doc asks: *is this production-ready?* This doc asks: *what would
make this delightful?*

---

## Vision

master-oogway is a shell environment with a strong personality: defensive
by default, schema-driven, snappy at startup, and overflowing with small
quality-of-life ergonomics. The plugins read like one person's accumulated
muscle-memory codified into reusable code — which is exactly what they are.

The features below extend that personality, not redirect it. The bar is:
*would this still feel like the same project a year from now?* If a feature
needs a network call, a sudo prompt, or a config file the user must hand-
edit before it works, it goes in the "wild ideas" bucket — not the
recommended set.

The aim: a user who installs master-oogway should feel like the shell is
*looking out for them* — anticipating common needs, catching footguns,
surfacing what's relevant, hiding what isn't.

---

## How to read this

Every item carries three tags:

- **Effort** — `XS` (~30 LOC, one sitting), `S` (~80 LOC), `M` (~200 LOC),
  `L` (~500+ LOC or multi-file).
- **Fit** — how cleanly it slots into the existing convention layer
  (`# Requires:` header, `-h/--help` flag, per-plugin README, override
  escape hatch where relevant).
  - `A` = drops in cleanly, no new patterns.
  - `B` = needs a small new convention (env var, schema entry, helper).
  - `C` = introduces a new dependency class (network call,
    sudo-by-default, desktop notification, daemon).
- **Priority** — `P1` (would notice the absence weekly),
  `P2` (occasional), `P3` (delight / nice).

The audit's confidence column is dropped — features have no "confidence,"
only fit and effort.

---

## Verdict at a glance

| Category | Count | Best entry point |
|---|---|---|
| New plugins | 28 | `mo-trash` — safer `rm` with restore (`P1·S·A`) |
| Dragon theme | 10 | Custom-segment API — `dragon_segment_<name>()` (`P2·M·B`) |
| Existing-plugin enhancements | 17 | `gpr` in `mo-git` — open current branch's PR (`P1·XS·A`) |
| `mo-cli` subcommands | 11 | `selfcheck` — non-interactive health probe (`P1·S·A`) |
| Infrastructure & distribution | 5 | Container test rig — fresh-Ubuntu install verification (`M`) |
| UX & workflow | 7 | Long-command notifier — `notify-send` on slow commands (`P2·S·C`) |
| Wild ideas | 8 | Per-host `conf.zsh` — different prompt per SSH target (`P3·S·B`) |
| Internal refactors (Appendix A) | 4 | `_mo_clip` helper — DRY the wl-copy/xclip fallback used in 3 places |
| **Total** | **90** | |

---

## Errata — what v1 of this doc got wrong

These corrections are applied throughout. Listed here so the diff between
v1 and v2 is auditable.

1. **v1 §2.7 "Idle-duration prompt"** — *already exists*. The dragon theme
   has `DRAGON__ENABLE_EXEC_TIMER` + `DRAGON__EXEC_TIMER_THRESHOLD` —
   commands above the threshold render duration in the right prompt. Item
   dropped from §2. Replacement in §2.7 below: *tune defaults / surface in
   transient*.
2. **v1 §2.8 "Curated preset gallery"** — preset names were wrong. The
   real presets are `default`, `short`, `verbose` (not "short/long/
   minimal"). The verbose preset already has multiline + drawing chars
   (`╭ `, `│`, `╰╴`). Item rewritten in §2.8.
3. **v1 §1.3 "`mo-clipboard`"** — reframed. The wl-copy/xclip/print
   fallback already lives inside `flog` and `fp`. The new framing is a
   `_mo_clip` helper (Appendix A) plus a *thin* `mo-clipboard` plugin
   that exposes it as `clip`/`paste`/`clipfile`. Roughly half the
   originally proposed effort.
4. **v1 §3.7 "`gconflicts`"** — partially redundant with `gs` (`git
   status` already surfaces conflicts). Kept but rescoped to "open all
   conflicted files in `$EDITOR`" — value is the second step.

---

## Recommended next set — read this first

If the next focused session is feature growth (not audit closure), here
are the top eight in dependency-honest order. The first four are the
foundation; the next four ride on top of them.

| # | Item | Why first | Effort | Section |
|---|---|---|---|---|
| 1 | `_mo_clip` internal helper | Unlocks every clipboard story without forking patterns in 3 places | XS | App. A |
| 2 | `master-oogway selfcheck` | Bridges audit (U-3) and features; CI will eventually run it; everything else benefits from being verifiable | S | §4.1 |
| 3 | `master-oogway commands` | Discovery — turns 20 plugins into a browsable surface; users find what they have, contributors find what's been used | S | §4.2 |
| 4 | `gpr` in `mo-git` | Biggest daily-driver win; one-line `gh pr view` or branch-URL constructor | XS | §3.1 |
| 5 | `mo-trash` (override-tier) | Pairs naturally with `mo-safety-override`; closes the "irreversible `rm`" gap | S | §1.1 |
| 6 | Dragon custom-segment API | Unlocks an entire family of user-side segments (§2.2 – §2.7) at ~20 LOC each | M | §2.1 |
| 7 | `master-oogway tour` | Brand-new users discover the project in 90 seconds, not by reading 21 READMEs | S | §4.7 |
| 8 | `mo-mkscript` | The scaffold-aligned-with-conventions move; every new shell script the user writes inherits the repo's `set -Eeuo pipefail` header | XS | §1.2 |

The eight together are roughly 400–550 LOC. A focused week.

---

## Table of contents

1. [New plugins](#1-new-plugins) — 28 ideas, grouped into six themes
2. [Dragon theme features](#2-dragon-theme-features) — 10 ideas
3. [Existing-plugin enhancements](#3-existing-plugin-enhancements) — 17
4. [`mo-cli` subcommands](#4-mo-cli-subcommands) — 11
5. [Infrastructure & distribution](#5-infrastructure--distribution) — 5
6. [UX & workflow](#6-ux--workflow) — 7
7. [Wild ideas](#7-wild-ideas) — 8 (the speculative bucket)
8. [Things explicitly NOT proposed](#8-things-explicitly-not-proposed)
9. [Appendix A — Internal helpers / refactor wins](#appendix-a--internal-helpers--refactor-wins)
10. [Appendix B — Delight ladder](#appendix-b--delight-ladder)

---

## 1. New plugins

Grouped by theme.

### Theme 1A — Safety & undo

### Theme 1C — Discovery & navigation

#### 1.12 `mo-projects` — project hub  ·  P2 · S · A

Per the user's design: every subdirectory of `MO_PROJECTS_PROJ_DIR`
(default `~/projects/`, also honours `~/Projects/`) gets its own alias
(`foo` → `cd ~/projects/foo`). `p` runs an fzf picker across all project
directories.

#### 1.15 `mo-color` — color preview & palette  ·  P3 · XS · A

See TODO.md for the full spec.

---

### Theme 1D — Network & SSH

#### 1.17 `mo-ssh-tunnel` — SSH port forwards  ·  P2 · M · B

See TODO.md for the full spec.

---

### Theme 1F — Quality of life

#### 1.26 `mo-archive` — `extract`'s missing sibling  ·  P3 · XS · A

`compress <archive-name> <files...>` — format chosen by extension.
Defaults to `.tar.zst` (best ratio/speed). Mirrors the dispatch table in
`mo-files` `_MO_EXTRACT_HINTS`. If no archive name given, uses the
directory name and creates it in the current directory. ~30 LOC.

---

## 2. Dragon theme features

The theme machinery is heavy already (schema-driven, async gitstatus,
transient prompts, SSH-aware, exec-timer, exit-status, jobs, ssh-conn-
count). What's missing is *content variety* — more useful segments — and
*convenience* around sharing presets and palettes.

### 2.1 Custom-segment API  ·  P2 · M · B  ★ foundation for §2.2 – §2.7

Today, adding a segment means editing `parts/segments_*.zsh` directly.
A small registration API would let users add segments from their
`conf.zsh`:

```zsh
# ~/.config/master-oogway/conf.zsh
dragon_segment_kubectx() {
    local ctx="$(kubectl config current-context 2>/dev/null)" || return 1
    print -- "⎈ ${ctx#*/}"
}
DRAGON__RIGHT_SEGMENTS+=( kubectx )
DRAGON__SEGMENT_KUBECTX_FOREGROUND_COLOR="navy"
DRAGON__SEGMENT_KUBECTX_PREFIX=" "
DRAGON__SEGMENT_KUBECTX_SUFFIX=" "
```

The repo already has the colour-and-separator plumbing in
`__dragon_copy_defaults` + `__dragon_finalize`. The work: schema entries
for `DRAGON__{LEFT,RIGHT}_SEGMENTS` arrays, plus a loop in the segment
renderers that calls each registered function and wraps the output with
existing styling.

Once this exists, items 2.2–2.7 are 10–20 LOC of user code each.

### 2.2 Kubernetes-context segment  ·  P2 · XS · B (atop §2.1)

`⎈ prod/default`. Single line of `kubectl config current-context`.
Schema-default OFF; user opts in.

### 2.3 Python venv / Conda segment  ·  P2 · XS · B (atop §2.1)

Detect `$VIRTUAL_ENV`, `$CONDA_DEFAULT_ENV`, `$POETRY_ACTIVE`. Short
name, not full path. (Note: the upstream `virtualenv` prompt prefix is
already suppressed by oh-my-zsh — this would *replace* that, not stack
on it.)

### 2.4 Language version segments  ·  P3 · XS · B (atop §2.1)

`node@20.10` / `ruby@3.2` / `go@1.21`. Only render if a marker file
exists in cwd (`.nvmrc`, `.ruby-version`, `go.mod`).

### 2.5 AWS / GCP profile segment  ·  P2 · XS · B (atop §2.1)

`$AWS_PROFILE` or `(default)`. Render only when a Terraform / Serverless
config is present in cwd (heuristic, configurable). Coloured red when
profile name matches `^prod` regex — "you're about to touch production"
signal.

### 2.6 Battery segment  ·  P3 · XS · B (atop §2.1)

Read `/sys/class/power_supply/BAT0/capacity`. *Only* render below a
threshold (default 30 %). The "this matters" segment — never noise
above 30 %.

### 2.7 Tune exec-timer defaults (correction from v1)  ·  P3 · XS · A

The exec-timer segment already exists (`DRAGON__ENABLE_EXEC_TIMER`,
`DRAGON__EXEC_TIMER_THRESHOLD`). v1 of this doc proposed it again — error.

What *is* missing:
- The transient prompt does not surface the duration. Adding it would
  make "wait, how long did that take?" answerable after the line has
  already shrunk to transient form.
- The `verbose` preset enables it with `THRESHOLD=2` — most users
  benefit from a similar lower default in the `default` preset (current:
  off). Worth at least documenting in the README that users can opt in.

### 2.8 Curated preset gallery  ·  P3 · S · A (rephrased from v1)

The actual presets are `default`, `short`, `verbose`. A gallery would be
a folder of `.conf.zsh` files in
`omz-custom/themes/dragon/presets/*.conf.zsh`. Examples:
- `tokyonight.conf.zsh` — palette swap, layout preserved.
- `dragon-classic.conf.zsh` — the original 2025 layout snapshotted.
- `corporate.conf.zsh` — no nerd glyphs, ASCII separators only.
- `cyberpunk.conf.zsh` — magenta/cyan palette + arrow separators.

`dragon-configure --preset <name>` already loads from the case
statement (configure.zsh:115). The change: data-drive the list so
adding a preset is just dropping a file. (This is also audit A-2.)

### 2.9 `dragon-configure --export <name>`  ·  P2 · S · A

Save current `conf.zsh` as
`~/.config/master-oogway/presets/<name>.conf.zsh`. Then `--preset
<name>` can load it. Personal presets — never committed to the repo —
sit alongside the bundled gallery from §2.8.

### 2.10 Palette files separated from layout  ·  P3 · M · B

Today, presets bundle *both* "what shows" (layout) and "what colour"
(palette). A clean split:

```text
omz-custom/themes/dragon/palettes/
  tokyo-night.zsh           # only `DRAGON__*_COLOR` keys
  dracula.zsh
  nord.zsh
  gruvbox.zsh
```

```bash
dragon-configure --palette tokyo-night --preset short
```

Two orthogonal axes: `--preset` is layout/segments, `--palette` is
colors. This is what Starship/Powerlevel10k users expect.

---

## 3. Existing-plugin enhancements

Ordered by host plugin. P1/P2 first within each.

### `mo-git`  (currently 119 LOC)

| # | Command | What | Effort | Priority |
|---|---|---|---|---|
| 3.1 | `gpr` | Open current branch's PR. Uses `gh pr view --web` if installed; otherwise constructs URL from `origin` remote + branch | XS | P1 |
| 3.2 | `groot` | `cd` to repo root (toplevel) | XS | P1 |
| 3.3 | `gwip` / `gunwip` | WIP commit / amend-and-uncommit cycle for fast stash-less context switches | XS | P2 |
| 3.4 | `gcofb` | Fuzzy-pick a file from another branch, check it out into cwd | S | P2 |
| 3.5 | `gprune` | Interactive delete of merged local branches with confirmation | S | P2 |
| 3.6 | `gconflicts` | Open all files in merge conflict in `$EDITOR` (with `+/<<<<<<<` jump) | XS | P2 |
| 3.7 | `gtag` | Fuzzy-pick a tag and check it out | XS | P3 |
| 3.8 | `gfix <hash>` | `git commit --fixup <hash>` then offer to `git rebase -i --autosquash` | XS | P3 |
| 3.9 | `gca` | `git commit --amend --no-edit` (very common, currently absent) | XS | P2 |

### `mo-files` (currently 167 LOC)

| # | Command | What | Effort | Priority |
|---|---|---|---|---|
| 3.10 | `bak --restore <bak>` | The missing inverse of `bak` — restore from a `.bak.<ts>` snapshot, with `--list` to see all snapshots for a file | XS | P2 |
| 3.11 | `dups` | Find duplicate files in current tree by SHA-256 (parallel hashing via `find -print0 | xargs -0 -P`) | S | P3 |
| 3.12 | `rename` | Bulk rename via sed pattern, `--dry-run` by default — refuses to overwrite | S | P2 |

### `mo-process` (currently 71 LOC)

| # | Command | What | Effort | Priority |
|---|---|---|---|---|
| 3.13 | `top-cpu` / `top-mem` | Top 10 processes by CPU / memory, refreshable | XS | P3 |
| 3.14 | `pidof` | Smart wrapper: name → PIDs, with `--newest` / `--oldest` filters | XS | P3 |

### `mo-network` (currently 43 LOC)

| # | Command | What | Effort | Priority |
|---|---|---|---|---|
| 3.15 | `myip` | Local IP per interface (counterpart to public `natip`) | XS | P1 |
| 3.16 | `whichnet` | "Are you home?" — uses the same network-id hash as `mo-lan-ssh`, shows a friendly label (`home`/`coffee-shop`/`unknown`) — labels stored in `~/.config/master-oogway/networks.conf` | S | P2 |
| 3.17 | `ports-listening` | Pretty `ss -tlpn` — sorted, column-aligned | XS | P3 |

### `mo-shell-tools` (currently 79 LOC)

| # | Command | What | Effort | Priority |
|---|---|---|---|---|
| 3.18 | `aliases` | List all aliases grouped by source plugin (mirror of `mo-where` in inverse) | S | P2 |
| 3.19 | `funcs` | Same, for functions | XS | P2 |
| 3.20 | `histtop [N]` | Top N most-used commands in history with counts | XS | P3 |

---

## 4. `mo-cli` subcommands

`master-oogway` already does `update`, `uninstall`, `version`, `configure`,
`edit`, `path`, `help`. The CLI is the natural surface for discovery and
introspection.

| # | Subcommand | What | Effort | Priority | Audit ref |
|---|---|---|---|---|---|
| 4.1 | `selfcheck` | Health probe — markers, submodules, locale, schema hash, SSH config sanity, conf.zsh `zsh -n`. Exit code 0/non-zero — CI-friendly | S | P1 | U-3 |
| 4.2 | `commands [--json]` | List every alias / function defined by any `mo-*` plugin, grouped, with source plugin + line number | S | P1 | — |
| 4.3 | `docs <name>` | Open the README of the plugin that defines `<name>` (uses the `mo-where` index from `mo-shell-tools`) | XS | P2 | — |
| 4.4 | `disable <plugin>` / `enable <plugin>` | Comment / uncomment the plugin line in `~/.zshrc` | S | P2 | — |
| 4.5 | `diff-zshrc` | Inline diff of user `~/.zshrc` vs template, capped to 40 lines with `+N more` tail | S | P1 | U-2 |
| 4.6 | `changelog` | Show `CHANGELOG.md` entries since the installed commit | XS | P2 | M-4 |
| 4.7 | `tour` | 90-second interactive walkthrough — opens a paged guide, highlights "the 10 commands you'll use most often" with examples. Re-shown on first install (one-time flag in `state` file) | S | P1 | — |
| 4.8 | `bench` | `zshtime` + per-plugin breakdown using `zprof` against a clean shell. Saves to `BENCHMARKS.md` if requested | L | P2 | — |
| 4.9 | `debug` | Bundle environment as a tarball for bug reports — see §1.23 for content | S | P2 | — |
| 4.10 | `report-issue` | Open the GitHub issues page in a browser with an env block pre-filled. Reads `repo` URL from install dir's git config | XS | P3 | — |
| 4.11 | `dev` | `cd "$_MO_INSTALL_DIR" && git status` — drop into the install dir for hacking | XS | P3 | — |

### Why `commands` (4.2) matters

After 20 plugins, users routinely forget what's defined. `mo-where`
(already in `mo-shell-tools`) finds a *known* name; `commands` provides
the inverse — *what names exist*. Output is a single fuzzy-friendly
table:

```text
mo-git         alias    gpr                Open the current branch's PR
mo-git         alias    gs                 git status
mo-git         function gsum               Repo summary
mo-process     function port               Show process listening on port
mo-process     function fkill              fzf-pick a process to kill
…
```

Source of truth: walk every `omz-custom/plugins/mo-*/*.plugin.zsh`, grep
`^alias`, `^function`, and `^[a-z_-]+\(\)`. Pipe through `fzf` by
default. `--json` enables scripting.

### Why `tour` (4.7) matters

First-time experience right now: install, see a banner, then... silence.
The user has 21 plugin READMEs to wade through to find that `please`
re-runs the last command as sudo, or that `Esc Esc` prepends `sudo`, or
that `fcd` exists, or that the `s-<host>` aliases for LAN boxes are
auto-generated.

`master-oogway tour` should walk the user through the top 10 commands
by *expected usage frequency*, with a live example for each. ~80 LOC,
all data-driven (no heavy logic).

---

## 5. Infrastructure & distribution

Overlaps with the audit's release-readiness checklist (M-1…M-5). These
are the items the audit doesn't already track.

| # | Item | What | Effort |
|---|---|---|---|
| 5.1 | `tools/bench.sh` | Standardised perf harness — N cold + N warm `zsh -i -c exit` runs, saves to `BENCHMARKS.md` keyed by hostname | S |
| 5.2 | `tools/screencast.sh` | asciinema recording of the install + first prompt, embeddable in README | XS |
| 5.3 | `tools/release.sh` | Tag + write `CHANGELOG.md` section + push | S |
| 5.4 | `docker/` | `docker compose up` spawning a fresh-Ubuntu container with the repo bind-mounted, ready for install/uninstall tests | S |
| 5.5 | `tests/fixtures/` | Sample `.zshrc`, `.gitconfig`, `.ssh/config` for the bats tests in audit M-1 to consume | XS (data only) |

---

## 6. UX & workflow

| # | Item | What | Effort | Priority |
|---|---|---|---|---|
| 6.1 | Long-command notifier | After commands taking longer than `MO_NOTIFY_THRESHOLD`s (default 30), fire `notify-send` when they finish. `preexec`/`precmd` hooks — naturally inhibited inside `tmux`/`screen`/non-TTY | S | P2 |
| 6.2 | Per-directory `.master-oogway.zsh` | Auto-sourced on `cd` into the dir; un-sourced on `cd` out (function-tracking). Like direnv but for aliases + functions, not just env vars | M | P3 |
| 6.3 | Welcome banner — changes since last shell | Append one line if `master-oogway` has new commits since this terminal last started: `"+3 new commits — run master-oogway update"` | XS | P2 |
| 6.4 | `NO_COLOR` / `FORCE_COLOR` everywhere | Audit every plugin's colour output; honour standard env vars. Also affects `dragon-configure` wizard | XS | P2 |
| 6.5 | OSC-8 hyperlinked file output | Wrap `ls`/`grep`/`find` outputs in OSC-8 escapes so paths are clickable in modern terminals. Opt-in via `MO_OSC8=true` (off by default — some terminals render them as garbage) | M | P3 |
| 6.6 | Welcome banner — pending master-oogway tasks | If `~/.config/master-oogway/todo` exists with `* line items`, surface a count in the banner | XS | P3 |
| 6.7 | `MO_QUIET=1` mute mode | One env var that silences welcome banner, ysu nags, and other startup chatter — for screencasts and presentations | XS | P2 |

---

## 7. Wild ideas

The speculative bucket. Listed so they aren't lost; not recommended for
the next several iterations.

| # | Item | Why it's "wild" |
|---|---|---|
| 7.1 | Per-host `conf.zsh` overrides | `~/.config/master-oogway/per-host/<hostname>.conf.zsh` auto-loaded, layered on top of base — red prompt on production servers, etc. Needs a layering story that's clean, not a `source` chain |
| 7.2 | Web-based prompt builder | Like p10k configure but in the browser — drag-and-drop segments, copy resulting conf.zsh. Genuinely cool, but adds web tooling to a shell repo |
| 7.3 | AI segment hook | One `dragon_segment_ai` whose content is set externally by an AI integration (Claude Code, gh copilot CLI). No AI code in master-oogway itself — just the hook |
| 7.4 | `MO_THEME=<name> zsh -i` per-shell theme override | Spawn a new shell with a different palette without changing config — great for demos / screenshots |
| 7.5 | Friendly `mo-fakedata` | Generate emails / names / addresses for testing. Wordlist-based, no LLM. Faker.py port to zsh |
| 7.6 | Per-command notifier with smart cancellation | The 6.1 notifier + "snooze 5m" widget so you can mute one specific command (like `terraform plan`) for the rest of the session |
| 7.7 | `mo-emoji` with skin-tone fuzz | The §1.13 picker but with skin-tone modifier toggling. Real UX gain or distraction — depends on user |
| 7.8 | Drop-in fish-style abbreviations | Type `gco<space>` and watch it expand to `git checkout ` in-place. Different ergonomic axis from oh-my-zsh aliases |

---

## 8. Things explicitly NOT proposed

So the next reader doesn't try to add them and then wonder why they got
pushed back.

- **Built-in AI / LLM integration as a first-class feature.** Out of
  scope for a shell environment; if you want Claude / Copilot at the
  prompt, install their CLIs. §7.3 carves out a *hook* — that's the
  most we should do.
- **Plugin manager rewrite.** Oh-my-zsh's loader is fine; we layer atop
  it cleanly via `$ZSH_CUSTOM`. zinit / antidote / znap are not on the
  table.
- **Theme abstraction layer (so dragon "could be swapped out").**
  YAGNI; the project is *about* the dragon theme. Configurability is
  via `dragon-configure`, not theme polymorphism.
- **Paste-to-internet helper (`0x0.st`, gist).** Network exfil from a
  shell function is a footgun even with good intentions; users can
  `curl` directly.
- **Auto-installation of system packages.** `install.sh` deliberately
  doesn't `apt install` anything beyond what's documented. Suggestions
  like "auto-install fzf if missing" would break that posture. Plugins
  must *skip cleanly* when deps are absent (existing pattern) — never
  `sudo apt install`.
- **Replacing built-in zsh features.** `setopt AUTO_PUSHD` already does
  directory stacking; we don't ship a `back`/`forward` plugin. Same for
  `Esc .` (last argument), `Ctrl-R` (history search via fzf), `Esc Esc`
  (sudo prefix via the `sudo` plugin).
- **Mandatory telemetry / "phone home" updates.** The version check is
  explicit (`master-oogway version`). The §6.3 banner is *passive* —
  reads local git, no network.
- **A built-in package manager for `mo-*` plugins.** The user-plugins
  directory (`~/.config/master-oogway/custom-plugins/`) already
  provides drop-in extensibility. A registry / package index would
  invert who-curates-what and is the wrong shape for personal dotfiles.
- **Forking history into a database** (zsh-histdb, atuin). Powerful, but
  introduces SQLite as a hard dep and dramatically changes the
  `Ctrl-R` story; an opt-in plugin recommendation in the README is
  more honest than vendoring it.

---

## Appendix A — Internal helpers / refactor wins

Not features per se. Code patterns that already repeat in 2+ places
and would benefit from a single canonical helper. The helper *enables*
several of the features above.

### A.1 `_mo_clip` — unified clipboard fallback

Currently inlined in `flog` (mo-git.plugin.zsh:110–118) and `fp`
(mo-files.plugin.zsh:158–166). Extract:

```zsh
# In a new file: omz-custom/lib/_mo_clip.zsh (sourced from zshrc.master-oogway)
_mo_clip() {
    # Usage: echo -n "$value" | _mo_clip
    #        _mo_clip < file
    if command -v wl-copy &>/dev/null;     then wl-copy
    elif command -v xclip &>/dev/null;     then xclip -selection clipboard
    elif command -v pbcopy &>/dev/null;    then pbcopy
    else                                        cat   # echo through, caller prints
    fi
}
```

Then `flog`/`fp`/§1.3/§1.14/§1.16 all share one tested implementation.

### A.2 `_mo_default_branch` — uniform main-vs-master resolution

`fbranch` (mo-git:59–61) computes `default_branch` ad-hoc. The future
`gpr`/`gprune`/`gcofb` all need the same. Extract.

### A.3 `_mo_with_sudo` — sudo grace-window cacher

The audit's S-3 calls this out for `mo-cli uninstall`. The same pattern
recurs in `port` (mo-process:35) and would in §1.18 `vpn`. One helper
that does `sudo -v` once, runs a callable, suppresses repeat prompts.

### A.4 `_mo_require` — dep-check shorthand

Every plugin reimplements `command -v X &>/dev/null || { echo "X
required" >&2; return 1; }`. The audit's M-15 (memory) records that
`_mo_require` was *removed* by inlining — and that was the right call
at the time (consolidation effort outweighed the gain).

**However:** with 15+ plugins now consistently inlining, the case for
re-introducing it has strengthened. A single helper with a curated
`apt install` hint table would shrink ~30 LOC across plugins and make
the "what does this plugin need" question greppable.

Soft suggestion. Don't reverse the M-15 decision unless it's a clear
win on a fresh measurement.

---

## Appendix B — Delight ladder

A rubric for *how* to build, not *what* to build. Every feature above
can be implemented at any of these levels — the higher rungs are what
separate functional tools from delightful ones.

1. **Works.** The happy path returns 0.
2. **Fails loudly.** Bad input or missing dependency emits a clear
   error to `stderr`, returns non-zero. Match `mo-files` `extract`'s
   hint table.
3. **`-h` / `--help` works.** Every existing plugin honours this. No
   exceptions for new ones.
4. **Skips cleanly when deps absent.** No crash, no scary error — a
   single line explaining what's missing and an `apt install …` hint.
5. **Has a tab-completion story.** zsh's `_arguments` for subcommands,
   `_files`/`_directories` for path args.
6. **Error messages include the fix.** Not "permission denied" but
   "permission denied — try: sudo lsof -iTCP:$port".
7. **The success message tells the user what changed.** `bak`
   announces "Copied to foo.bak.20260520_073000". `mo-lan-ssh add`
   announces "Added: $entry  (alias s-$h now available in this shell)".
8. **Idempotent.** Running twice does the right thing — no duplicate
   entries, no clobbered state.
9. **`--dry-run` for destructive operations.** Before you write `rm
   -rf`, you should be able to preview.
10. **Composable.** Output structured enough to pipe (`--json`,
    tab-separated, NUL-delimited for paths).

The existing codebase already hits rungs 1–8 consistently. Rungs 9–10
are where the next level of polish lives — and where most new features
in this doc would benefit from sitting before being declared "done."

---

*End of feature ideas.*
