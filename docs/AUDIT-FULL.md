# master-oogway — Full repo audit

Generated 2026-06-13 against `main` (HEAD `7f23ad1`). Covers every section of the repo: top-level installer + dotfiles, dragon theme, mo-* plugin set, shared libs, and docs. Findings carry an explicit severity (`CRIT`/`HIGH`/`MED`/`LOW`) and a file:line reference. Improvements and new-feature ideas are listed alongside.

This audit complements the existing per-commit history (37 post-AUDIT commits already shipped). Findings already resolved by recent commits (7f23ad1, 40a8f49, 64380bc, a6e2803, d37b673, 9523c6e, aac9d34, 410a4d6, 333b73f, 4a76afa, b74d817, 4edad2c, d04cba9, 19342f0) are not re-listed.

---

## Table of contents

1. [install.sh](#1-installsh)
2. [zshrc.master-oogway](#2-zshrcmaster-oogway)
3. [zshenv.master-oogway](#3-zshenvmaster-oogway)
4. [gitconfig.master-oogway](#4-gitconfigmaster-oogway)
5. [editorconfig.master-oogway](#5-editorconfigmaster-oogway)
6. [README.md & CONTRIBUTING.md](#6-readmemd--contributingmd)
7. [Dragon theme — entry, schema, hot path](#7-dragon-theme--entry-schema-hot-path)
8. [Dragon theme — wizard / configure](#8-dragon-theme--wizard--configure)
9. [Dragon theme — presets](#9-dragon-theme--presets)
10. [mo-* plugin set](#10-mo--plugin-set)
11. [Shared libs (omz-custom/lib)](#11-shared-libs)
12. [Cross-cutting themes](#12-cross-cutting-themes)
13. [Prioritized work queue](#13-prioritized-work-queue)

---

## 1. install.sh

984 lines. Handles three install modes (curl / update / dev), copies dotfiles, manages backups, apt-installs deps, runs zcompile.

### Bugs

| Sev | Where | Issue |
|---|---|---|
~~| HIGH | `install.sh:208` | `missing_for_plugin` built as a space-separated string, later iterated bare `for cmd in ${missing_cmds[$plugin]}`. If any `MO_OPTIONAL_DEPS` key ever contains a space or a glob (`*`), the loop word-splits **and** globs (no `set -f`). Use an array. |~~
~~| HIGH | `install.sh:373–378` | `_zc` swallows zcompile errors silently (`zsh -c "zcompile '$f'" 2>/dev/null`, always returns 0). Syntax errors in theme files report `compiled N` but bytecode is stale; the next shell start sees the error. The inline `'$f'` also breaks for paths containing a single quote. Log non-zero exits; use `zsh -fc 'zcompile -- "$1"' zsh "$f"`. |~~
~~| MED | `install.sh:482, 498` | `_find_backup` glob `~/.zshrc.pre-master-oogway.*` matches editor files like `.swp`. Restrict to timestamp pattern: `"${base}".[0-9]*`. |~~
| MED | `install.sh:539` | Legacy-marker cleanup runs `sudo sed -i /etc/ssh/sshd_config` after `sudo -v || true`. If `sudo -v` fails on a kiosk box, the next `sudo sed` either prompts unexpectedly or fails. Probe `sudo -n true` once and skip the whole path when there is no sudo. |
~~| MED | `install.sh:618` | `locale -a \| grep -qi 'en_US.utf8\|en_US.UTF-8'` — `.` is a regex metachar. Use `-F` or anchor with `-E '^en_US\.(utf-?8)$'`. |~~
~~| LOW | `install.sh:702–708` | MO_FORCE branch may append `source ~/.zshenv.master-oogway` twice if the grep test misses (e.g. trailing whitespace). Use `grep -qFx "$source_line"` or compare via `awk`. |~~
~~| LOW | `install.sh:740–741` | `readonly GITCONFIG/GITCONFIG_BUNDLE` declared mid-script; a second invocation (sourced for tests) aborts on the readonly redeclaration. Lift them to the top constants block. |~~
| LOW | `install.sh:413` | `readlink "${INSTALL_DIR}"` (not `-f`). If `~/.master-oogway` is a chain of symlinks, the dev-mode equality check breaks. Use `realpath` for both sides. |
| LOW | mixed | Indent style drift: `_install_zshenv`, `_install_editorconfig`, parts of `_install_gitconfig` use tabs; the rest uses 4-space. CLAUDE.md mandates tabs — run `unexpand` once. |

### Improvements

- **`install.sh:300–315, 401, 411`** — bootstrap, dev, and update detection blocks live at top level. `_git_out` and similar leak as globals. Wrap each block in a `_bootstrap_*` function.
- **`install.sh:475`** — `--force` only works as the *first* arg. `--uninstall --force` and `--force --uninstall` are accidentally asymmetric. Write a small `while` arg-parser.
- **`install.sh:167`** — `_check_optional_deps` spawns 2 `zsh -c` subshells per plugin (one for `MO_OPTIONAL_DEPS`, one for `MO_OPTIONAL_APT`). 25 plugins → 50 forks. Merge into one subshell emitting both tables on prefixes.
- **`install.sh:894–917`** — `_check_theme_vars` md5-hashes every install. Cache by `schema.zsh` mtime under `STATE_FILE` and skip when unchanged.

### New features

- **`install.sh --dry-run`** — walk every step, print `would write / would change / unchanged`, touch nothing. Pairs with `--force` to preview overwrites.
- **`install.sh --doctor`** — assert each contract: every required apt pkg present, oh-my-zsh installed, `~/.zshrc` carries the managed marker, submodules initialised, every `.zwc` newer than its source, SSH `SendEnv`/`AcceptEnv` configured, en_US.UTF-8 locale generated. One command to triage a broken shell.
- **`install.sh --restore-zshrc`** — pull the most recent `~/.zshrc.pre-master-oogway.<ts>` back without going through `--uninstall`.
- **`MO_REF=<tag|sha>` env var** in the bootstrap branch so curl-pipe installs can target a known-good commit (pinned upgrades).
- **GitHub Actions CI** — `bash -n`, `shellcheck`, and `zsh -n` against every plugin and theme file on every PR. The validation block in CLAUDE.md is currently honor-system.

---

## 2. zshrc.master-oogway

`install-once` by design (carries the `master-oogway:managed` marker).

### Bugs

| Sev | Where | Issue |
|---|---|---|
| MED | `zshrc:6` | PATH prepend would duplicate on every `source ~/.zshrc` if the user removed `typeset -U path`. Add a `# load-bearing` comment so it survives drive-by edits. |
| LOW | `zshrc:88–90` | The conf.zsh syntax-error fallback prints a warning, but it scrolls past instantly. Stash the message into the welcome banner. |
| LOW | `zshrc:95, 214, 224` | `for f in ...(N); do source "$f"; done` aborts the file but surfaces no diagnostic. Wrap with `source "$f" \|\| echo "warn: $f failed" >&2`. |
| LOW | `zshrc:214` | Plugin path construction reads as `${__mo_plugin%/}:t` then concatenates `${__mo_plugin}${__mo_name}.plugin.zsh` — slash logic survives by accident. Use `local name="${__mo_plugin:t:r}"` for clarity. |

### Improvements

- **`zshrc:103–107`** — `ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20` drops suggestions on long pipelines. Bump to 50 or comment the trade-off.
- **`zshrc:138`** — `MO_WELCOME_FIELDS=...` set unconditionally clobbers a user export. Use `: "${MO_WELCOME_FIELDS:=host os sys now up}"`.
- **`zshrc:79–83`** — optdeps source uses a hard-coded `$HOME/.master-oogway/...` path; subsequent blocks reference `$ZSH_CUSTOM` (same dir). Standardise on `$ZSH_CUSTOM/lib/optdeps.zsh`.

### New features

- **`MO_PLUGINS_DISABLE=(mo-foo mo-bar)`** env var read in zshrc to filter the plugins array. Lets users disable a plugin without editing the install-once file.
- **`MO_LAZY_PLUGINS`** — defer source until first trigger-command use. Cheap shell-start optimisation for users with all 25 plugins enabled.

---

## 3. zshenv.master-oogway

### Bugs / nits

- **LOW `zshenv:1`** — `#!/usr/bin/env zsh` shebang on a file that is always `source`d, never executed. Decorative; harmless.

### Improvements

- Add `umask 022` so non-interactive shells (cron, scripts) get a sane mask without depending on `~/.zshrc`.
- Consider exporting `LESS=-R -M -i -j5` and `MANPAGER` here so they reach non-interactive shells too.

---

## 4. gitconfig.master-oogway

### Bugs

- **LOW (UX) `gitconfig:14–18`** — `diff.tool = meld` set unconditionally, but meld is not an install dep. First `git difftool` fails non-obviously. Either ship meld via apt, prefer `vimdiff` (always present), or write the tool selection at install time.
- **LOW** — `[help] autocorrect = prompt` requires git ≥ 2.30. Ubuntu 24.04 (2.43) is safe; Raspberry Pi OS bullseye backport (2.30.2) is marginal. Worth a comment.

### Improvements (low-hanging quality wins)

- `[column] ui = auto` — multi-column `git branch`/`tag` for free.
- `[diff] algorithm = histogram` — better hunk grouping than myers.
- `[diff] colorMoved = zebra` + `colorMovedWS = allow-indentation-change`.
- `[rerere] autoUpdate = true` — auto-stage the replayed resolution since rerere is already enabled.
- `[maintenance] strategy = incremental` — background `git maintenance` keeps repos lean.

### New features

- Ship a few opinionated aliases: `co=checkout`, `sw=switch`, `lg=log --oneline --graph --decorate`, `last=log -1 HEAD --stat`, `unstage=reset HEAD --`.
- Optional `[commit] template = ~/.gitmessage.master-oogway` shipped with a tabular template — gentle prod for good commit messages, opt-out by editing the include path.

---

## 5. editorconfig.master-oogway

### Gaps

- **LOW** — no `[*.zsh-theme]` block. Dragon's entry shim is `dragon.zsh-theme`; without an explicit block it falls through to `[*]` defaults (no tab rule). Add a block mirroring `[*.zsh]`.
- **LOW** — no entries for Dockerfile, `*.toml`, `*.go`, `*.rs`. The file claims `root = true` at `$HOME` so it touches every project — either expand or note that per-project `.editorconfig` overrides.

### Improvements

- Add `max_line_length = 80` for `[*.sh]` and `[*.zsh]` to signal the convention to editors.

---

## 6. README.md & CONTRIBUTING.md

- **README.md:19** — lists `~/.gitconfig` as installed, but we write `~/.gitconfig.master-oogway` and *include* it. Wording is OK for end users but a one-liner about includeIf semantics would help confused contributors.
- **README.md** — no mention of `~/.editorconfig` implications (`root = true` at `$HOME` overrides everything below). One sentence helps.
- **CONTRIBUTING.md:11–44** — directory layout omits `omz-custom/lib/` (the new shared libs). Add a row.
- **CONTRIBUTING.md:88** — gitconfig edit-test loop says "re-run install.sh" but doesn't explain the include-not-copy model. Small clarification.
- Both docs hard-code preset/plugin counts (`43 presets`, `25 plugins`). Either auto-substitute at install time or drop the numbers.

---

## 7. Dragon theme — entry, schema, hot path

### Bugs

| Sev | Where | Issue |
|---|---|---|
| HIGH | `parts/segments_right.zsh` (exec_timer block) | `_DRAGON_TIMER_ACTIVE` is set in `preexec` but **not** cleared on bare Enter. Sequence: long cmd → `preexec` flips to true → cmd finishes → timer renders → reset to false. Bare Enter never re-enters preexec, so the flag stays `true` from the *previous* run. Next precmd hits the `else` branch with the stale `timer` and renders a huge "0 seconds since last `__set_timer`" duration. **Fix:** in `__save_exit_code`, also `_DRAGON_TIMER_ACTIVE=false` when no command ran. |
| HIGH | `parts/helpers.zsh` (`__get_xterm_color_by_name`) | Writes a global `XTERM_COLOR` as its return channel; callers chain through `__get_xterm_style_format` → `__dragon__show`, nesting reentry on a single global. Today safe (all synchronous), but a footgun. Either return via `print -r --` and `$()`, or pass a destination var name parameter. |
| MED | `parts/prompt.zsh` (ANSI strip in `__calc_prompt_length`) | `$'\e['[0-9;]#[A-Za-z]` does not match CSI sequences with `?` or `>` private markers. No segment emits those today, but if one ever does, the length math flips `GIT_SHOULD_BE_ON_NEW_LINE` incorrectly. Add `?>` to the bracket class. |
| MED | `parts/gitstatus.zsh` | When `_DRAGON_GITSTATUS_AVAILABLE=false`, the function returns without resetting `VCS_STATUS_*`. Stale values from prior queries can render outdated git info. Unset `VCS_STATUS_*` before returning. |
| MED | `aliases.zsh` `reset_theme_variables` + `rezsh` on SSH receiver | Resets `DRAGON__FORWARDED` along with the other vars, then re-sources conf.zsh. On the receiver, the guard no longer fires → conf.zsh exports the *receiver's* local defaults, blowing away the forwarded theme until the user reconnects. Either detect SSH and skip the unset, or snapshot forwarded vars at first source and replay. |
| LOW | `parts/gitstatus.zsh` | `gitstatus_start` failures suppressed via `2>/dev/null`. Users see an empty git segment with no clue why. Log to `~/.config/master-oogway/dragon.log` on first failure. |
| LOW | `schema.zsh` | `EXEC_TIMER_THRESHOLD` is `type=integer` but never validated when hand-edited in `~/.config/master-oogway/conf.zsh`. A user putting `1.5` breaks the arithmetic context silently. Add a per-type validator in `_dragon_load_current_conf`. |

### Improvements

- **Schema consolidation.** `_DRAGON_DEFAULTS`, `_DRAGON_TYPE`, `_DRAGON_HINT`, `_DRAGON_GROUP_VARS` are four parallel arrays that must be kept in sync. Collapse them into one source-of-truth table: `_DRAGON_SCHEMA[KEY]="type|group|default|hint"`. Derive the four arrays at init. Cuts the per-var update sites from 5 → 1; eliminates the entire class of "added the default, forgot the group" drift bugs. **Biggest leverage refactor in this audit.**
- **Add a parity assertion in `_dragon_init_presets`.** Today `_DRAGON_PRESET_NAMES` / `_DRAGON_PRESET_DESC` / `_DRAGON_PRESET_EXAMPLE` are three associative arrays with no enforcement. A missing desc renders an unlabeled entry in `--pick`. Add: `[[ ${#_DRAGON_PRESET_NAMES} == ${#_DRAGON_PRESET_DESC} && ${#_DRAGON_PRESET_DESC} == ${#_DRAGON_PRESET_EXAMPLE} ]] || die`.
- **Cache color lookups.** `__dragon__show` runs 4 × `${(P)var}` indirections + 2 × `__get_xterm_color_by_name` per segment per keystroke. With ~10 segments that's ~60 lookups every precmd. `typeset -gA _DRAGON_COLOR_CACHE; (( ${+_DRAGON_COLOR_CACHE[$color_name]} )) || _DRAGON_COLOR_CACHE[$color_name]=$(...)`. Invalidate on `rezsh`. Easy 30–50 % trim.
- **Dedup left/right separator builders.** `__add_separator_between_left_segments` and `__add_separator_between_right_segments` are 90 % identical; extract a single function taking side + separator-var pair. Same for the two multiline blocks in `prompt.zsh:51–91`.
- **`dragon.zsh` `__is_via_ssh`** — defined in dragon.zsh but called by segments. Move to `parts/helpers.zsh` so the dependency direction is tidy.

### New features

- **Segments**: `python_venv`, `kubectl_context`, `aws_profile`, `gcloud_project` — many people switch to starship just for these. Same `__dragon__show` machinery, segment renders only when env var is set, near-zero idle cost.
- **`DRAGON__HIGH_CONTRAST_MODE=true` runtime toggle** — forces an 8-colour palette, strips Powerline, adds visible text separators. Today `high-contrast` is a preset; promoting to a runtime toggle helps screen-sharing / presentations / colour-blind users.
- **Right-prompt fallback on narrow terminals** — complements `GIT_STATUS_ON_NEW_LINE=auto`. When `COLUMNS < threshold`, move rprompt to a tiny status line.
- **`dragon-configure --validate`** — walk `_DRAGON_CURRENT`, run each value through the type validator, report invalid hand-edits. Solves the integer coercion concern.
- **`dragon-configure --check`** — dry-run preset switch + `zsh -n` of generated conf without writing. Useful for CI on preset PRs.

---

## 8. Dragon theme — wizard / configure

### Bugs

| Sev | Where | Issue |
|---|---|---|
| MED | `configure/state.zsh:55` | `$'...'` regex `[^']*` will silently fail if any preset ever embeds an escaped `\'`. None today, but document the constraint and add a fallback `read -r`. |
| MED | `configure/wizard.zsh:60` (color picker hint string) | The pasted instructional `for i in {0..255}; do ...` has unbalanced braces vs. `writer.zsh:39`. Verify and align both copies. |
| LOW | `configure/wizard.zsh:359` (`*)` catchall in start menu) | Silently runs "Edit current config" on any unrecognised key. Add a "didn't recognise; defaulting to [1]" line. |
| LOW | `configure/wizard.zsh:155` | `(z)_DRAGON_GROUP_VARS[$group]` flag splits on shell tokens. `(s: :)` is safer for space-separated lists. |

### Improvements

- **Preview caching.** `_dragon_render_preview` spawns one `zsh -c` per group step. On slow hosts it flickers. Key the cache by `(group, ssh_mode, fail_mode, transient_mode, sha _DRAGON_CURRENT)`.
- **Gallery caching.** `_dragon_gallery` does 43 × 2 zsh subprocesses if `--ssh` variants are added. Same cache shape.

### New features

- **`dragon-configure --pick --no-preview`** for slow remote hosts.
- **`_DRAGON_GROUP_ORDER` for skipped-group navigation** — when `_dragon_filter_changed_groups` shrinks the list, `step_num/total` becomes confusing across re-entry. Track a stable order separately.

---

## 9. Dragon theme — presets

- **MED (drift)** — multiple presets export values identical to the schema default (e.g. `ascii.conf.zsh:8` `USERNAME_BACKGROUND_COLOR=''`, several in `aurora`, `cosmic`). CONTRIBUTING.md says "only values differing from defaults." Add a pre-commit lint or `install.sh` check: `diff <preset> <defaults>` and warn on no-op lines.
- **LOW** — `rainbow.conf.zsh` sets remote symbols without enabling `ENABLE_GIT_REMOTE_STATE` / `ENABLE_GIT_STASH_COUNT`. Symbols are inert; harmless but confusing.
- **LOW (documentation)** — `inferno.conf.zsh:5` uses `$' '` with a trailing space inside `$''`. State-loader preserves it, but call this out in CONTRIBUTING.

### New feature

- Generate the **README preset table** from `_DRAGON_PRESET_NAMES` / `_DRAGON_PRESET_DESC` at install time; eliminates the "bump the preset count in README" tax in the 3-step preset add.

---

## 10. mo-* plugin set

25 plugins; inventory below (line counts of `mo-<n>.plugin.zsh`, REQ=`requirements.zsh`, OPT=`optional-deps.zsh`, RDM=README):

```
248  mo-files              OPT RDM
210  mo-shell-tools            RDM   ← no requirements.zsh; calc() forks bc inline
161  mo-git              REQ OPT RDM
141  mo-ssh-tunnel       REQ     RDM
114  mo-cli                    RDM
103  mo-search           REQ OPT RDM
100  mo-welcome                RDM
 78  mo-process              OPT RDM
 75  mo-dirs                 OPT RDM
 73  mo-projects             OPT RDM
 65  mo-trash            REQ     RDM
 63  mo-network                RDM   ← no optional-deps.zsh; uses curl/python3/fzf
 58  mo-man                    RDM
 56  mo-docs                 OPT RDM
 42  mo-env                  OPT RDM
 36  mo-mkscript               RDM
 22  mo-build            REQ     RDM
 19  mo-bat-override     REQ     RDM
 14  mo-safety-override        RDM
 11  mo-lan-ssh          REQ OPT RDM
 11  mo-eza-override     REQ     RDM
  5  mo-nvim-override    REQ     RDM
  5  mo-colorize-override      RDM
  3  mo-color                  RDM
  3  mo-auto-ls                RDM
```

### CRITICAL cross-plugin finding

**HIGH (convention violation, repo-wide).** CLAUDE.md says plugins should query `_MO_OPT_BIN[tool]` instead of forking `command -v`. Only **3 of 25** plugins do this (`mo-search`, `mo-build`, `mo-bat-override`). The other 22 fork `command -v` — typically inside per-function dep checks. Net effect: every fp/fzf/calc/etc. invocation forks a subshell where a hash-table lookup would suffice.

- **Fix:** machine-rewrite all 22 plugins to query `_MO_OPT_BIN`. Then add an `install.sh` validation step: `grep -rn 'command -v' omz-custom/plugins/ \| grep -v requirements.zsh \| grep -v _mo_lan` should be empty.
- **Caveats:** per-function fallback chains like `bat → batcat → cat` still need the inline logic — but they can resolve via `${_MO_OPT_BIN[bat]:-cat}`. Worth designing a shared helper `_mo_choose <name1> <name2> ...` in `lib/optdeps.zsh`.

### Per-plugin findings (deeper for the larger plugins)

#### mo-files (248 lines, largest)

- **MED `mo-files.plugin.zsh:49`** — `extract()` is a 60-line `case` with one branch per format. The `*.gz`/`*.bz2`/`*.xz`/`*.zst` branches are destructive (decompress in-place). The symlink guard at lines 75–87 is good, but the function would benefit from being split: `_mo_extract_tar`, `_mo_extract_solo` (in-place decompressors), `_mo_extract_zip`. Improves testability.
- **MED `mo-files.plugin.zsh:148–164`** — `fp()` clipboard handling repeats the wl-copy/xclip dance also present in `mo-git:152–158` and `mo-shell-tools:32–38`. Extract to a shared helper (`_mo_clip` in `lib/optdeps.zsh`) — three callers stay in sync.
- **LOW** — `bak()` (line 106) creates timestamped backups but never prunes. A "keep last N" option would mirror the install-side concern.

#### mo-shell-tools (210 lines)

- ~~**HIGH (deps)** — no `requirements.zsh` or `optional-deps.zsh` despite calling `bat`, `wl-copy`, `xclip`, `bc`. `calc()` forks `command -v bc` per call (line 84). Add an `optional-deps.zsh` so installer surfaces missing tools.~~
- **MED `mo-shell-tools.plugin.zsh:32–38`** — clipboard helper duplicates `mo-files`/`mo-git`. Dedup.
- **LOW** — `please()` (line 125) is a `sudo $(fc -ln -1)` redo. Charming but a footgun if the last line was destructive. Worth a confirmation prompt.

#### mo-git (161 lines)

- **MED `mo-git.plugin.zsh:152–158`** — clipboard duplication (see above).
- **LOW** — `flog()` lives at line 144, `gtag` at 81, `fbranch` at 99. Each forks `command -v fzf`. Convert to `_MO_OPT_BIN[fzf]`.

#### mo-cli (114 lines)

- **LOW `mo-cli.plugin.zsh:26`** — `configure` subcommand forks `command -v dragon-configure` then calls the function. Since dragon-configure is defined in the same shell when the theme loads, prefer `(( $+functions[dragon-configure] ))` — cheaper and more accurate.
- **NEW feature**: `master-oogway log` to tail `~/.config/master-oogway/dragon.log` (pairs with the gitstatus_start logging idea above).

#### mo-search (103 lines)

- Already uses `_MO_OPT_BIN` — exemplary. The inline `command -v fzf` checks in `fhist`/`fman`/`frg` are defence in depth and OK to keep, though `_MO_OPT_BIN` would be terser.

#### mo-lan-ssh (11-line plugin.zsh; real logic in `_mo_lan_*.zsh`)

- **Exemplar pattern.** sha-cache (`_mo_lan_loader.zsh:164–179`) is the gold standard for file-writing plugins. Promote it: add `_mo_write_with_sha <path> <sha-state-file>` to `lib/optdeps.zsh` (or a new `lib/writers.zsh`) so future plugins import rather than re-implement.
- **LOW `_mo_lan_loader.zsh:50`** — md5sum forks awk-substr to get 8 chars. `printf '%.8s\n' "$(md5sum ...)"` avoids one fork.

#### mo-trash (65 lines)

- **LOW** — `requirements.zsh` checks `trash-put`; OK. But the plugin name + apt-package name (`trash-cli`) mismatch — a user reading the error sees `_missing+=(trash-cli)` which is the apt name. Good. Worth noting the pattern in CONTRIBUTING.

#### mo-welcome (100 lines)

- **NEW feature** — currently shows `host os sys now up` fields. Add `kubectl_ctx`, `aws_profile`, `last_login_ip`, `pending_updates` (count of `apt list --upgradable 2>/dev/null \| wc -l`).
- **LOW** — fields are computed every shell start. Cache them under `~/.cache/master-oogway/welcome.<field>` with a TTL; refresh only stale ones. Trims shell-start time on slow machines.

#### Smaller plugins

- ~~**mo-network**: missing `optional-deps.zsh` despite using `curl`/`python3`/`fzf`. Add.~~
- **mo-process**: per-function checks for `pgrep`, `lsof`, `fzf` — convert to `_MO_OPT_BIN`.
- **mo-docs**: per-function checks for `pandoc`/`xelatex` — same.
- **mo-projects, mo-dirs, mo-env, mo-trash**: each fork `command -v fzf`. Same.
- **mo-color (3 lines), mo-auto-ls (3 lines)**: tiny. No findings.

### New plugin ideas

| Plugin | Purpose |
|---|---|
| `mo-systemd` | `fsvc` fuzzy systemctl, `slog <unit>` = journalctl with sane defaults, `ssvc` = start, etc. Soft-dep `systemctl`. |
| `mo-docker` | `dsh <ctr>` exec sh, `dlogs` fzf-pick container + tail, `dprune` interactive cleanup, `dip <ctr>`. Soft-dep `docker`. |
| `mo-clipboard` | The one source of truth for the wl-copy/xclip dance — exports `_mo_clip` / `_mo_paste`. Pulls dup'd code out of mo-files/mo-git/mo-shell-tools. |
| `mo-history-better` | Fzf-backed Atuin-lite (no DB): dedup, time, exit code, frequency. Pairs with `MO_HISTORY_KEEP_DUP`. |
| `mo-secrets` | `secret get/set/edit` over `gpg --symmetric`. Stores under `~/.config/master-oogway/secrets/`. Soft-dep `gpg`. |
| `mo-py` | Lightweight `pyvenv create/list/use/remove` plus auto-activate on cd into a dir with `.venv/`. |
| `mo-rust` | Cargo aliases + `rust-update`. |

### Plugins to consider retiring / merging

- **mo-color (3 lines)** + **mo-auto-ls (3 lines)** — too small to justify a directory each. Fold into `mo-shell-tools` or a new `mo-misc`.

---

## 11. Shared libs

`lib/optdeps.zsh` (31 lines) and `lib/colors.zsh` (11 lines) are sourced before any plugin/theme.

- **Improvement:** add `lib/clip.zsh` exporting `_mo_clip` / `_mo_paste` so the wl-copy/xclip dance lives in one place (see plugin findings).
- **Improvement:** add `lib/writers.zsh` exporting `_mo_write_with_sha <path> <state-file>` lifted from `mo-lan-ssh`. Lets future file-writing plugins follow the same contract by importing rather than copying.
- **New feature:** `lib/log.zsh` exporting `_mo_log <level> <msg>` writing to `~/.config/master-oogway/dragon.log`. Backs the "log on failure" recommendations sprinkled through the audit.

---

## 12. Cross-cutting themes

1. **Convention without enforcement.** Three rules in CLAUDE.md are honor-system: `_MO_OPT_BIN` instead of `command -v` (22/25 plugins violate), sha-cache before writing user files (only mo-lan-ssh follows), 5-place schema update for new DRAGON__ vars (no parity assertion). Each can be enforced by a single `install.sh` step or a `make lint` target.

2. **Duplication that wants extraction.** The wl-copy/xclip dance is in 3 plugins. The bat/batcat fallback is in 4. The sha-cache write pattern is in 1 (mo-lan-ssh) but should be in a helper. The left/right separator builders inside dragon are 90 % identical. Each duplication is a place where a fix has to land twice.

3. **Globals as return channels.** `XTERM_COLOR`, `SHOW_RESULT`, `STYLE_FORMAT`, `GIT_STASH_STR`, `GIT_REMOTE_STATE_STR`, `_DRAGON_READABLE_TIME` — all deliberately global to dodge subshells in the prompt hot path. The performance argument is sound; the coupling cost is not. Add `# OUT: <global>` comments at every callee and a `typeset -g` at every call site to localise scope intent.

4. **Schema/preset drift.** Both the dragon schema and the preset registry have 3 parallel arrays each (defaults/type/group; names/desc/example) with no parity check. Same problem, same fix shape: collapse to one table, derive at init, assert parity.

5. **No CI.** `bash -n`, `shellcheck`, `zsh -n` are documented in CLAUDE.md but enforced manually. A 30-line GitHub Actions workflow would catch every "I forgot to run shellcheck" regression at PR time.

6. **Logging is missing.** Failures in async paths (gitstatus_start, zcompile) are silenced via `2>/dev/null`. A single `~/.config/master-oogway/dragon.log` with a tail subcommand (`master-oogway log`) would surface them on demand.

7. **Caching opportunities.** Welcome fields, color lookups, theme-var hash checks, wizard previews — all recomputed each call when memoization would trim noticeable time.

8. **`--dry-run` / `--check` parity.** Install, uninstall, and dragon-configure all touch user state without a preview mode.

---

## 13. Prioritized work queue

Ordered by `value ÷ effort`:

### Quick wins (1–3 hours each)

1. Add `install.sh` validation: fail when a plugin uses `command -v` outside `requirements.zsh` and outside `mo-lan-ssh`. Forces the 22 violators to migrate (or add a per-plugin opt-out comment).
2. Extract `lib/clip.zsh` (`_mo_clip` / `_mo_paste`). Migrate `mo-files`, `mo-git`, `mo-shell-tools`.
~~3. Fix the exec_timer bare-Enter bug (clear `_DRAGON_TIMER_ACTIVE` in `__save_exit_code`) — already fixed in current code.~~
~~4. Fix `_zc` swallowing zcompile errors.~~
5. Add the preset/desc/example parity assertion to `_dragon_init_presets`.
~~6. Add missing `optional-deps.zsh` to `mo-shell-tools` and `mo-network`.~~
~~7. Fix the `_find_backup` glob to require timestamp suffix.~~

### Medium wins (a day each)

8. Schema consolidation: `_DRAGON_SCHEMA[KEY]="type|group|default|hint"` + derive the four arrays. Cuts new-var update sites from 5 → 1.
9. Color-lookup cache in `__get_xterm_color_by_name`. 30–50 % prompt-render trim.
10. Add `install.sh --dry-run` and `install.sh --doctor`.
11. GitHub Actions workflow running `bash -n` + `shellcheck` + `zsh -n` on every PR.
12. SSH-receiver `rezsh` forwarded-vars snapshot/replay.

### Larger investments

13. Migrate all 22 plugins from inline `command -v` to `_MO_OPT_BIN`. Mechanical but wide.
14. Build `mo-systemd`, `mo-docker`, `mo-clipboard` plugins.
15. Wizard preview caching (`_dragon_render_preview` + `_dragon_gallery`).

---

*End of audit.*
