# master-oogway — Deep Engineering Audit

## 0. Executive summary

`master-oogway` is a well-engineered, opinionated zsh distribution for personal Linux desktops. It is roughly 8.5k LOC of bash/zsh divided between:

- one tri-mode installer ([install.sh](install.sh)) — 823 lines
- one dotfile bundle (zshrc/zshenv/gitconfig/editorconfig)
- one prompt engine (dragon, ~2.6k lines)
- 22 mo-* plugins (4.8k lines, plus per-plugin READMEs and dep declarations)
- four vendored upstream submodules (gitstatus / you-should-use / zsh-autosuggestions / zsh-syntax-highlighting) — out of scope for this audit

**Overall posture.** Several things are visibly above-average for a personal-dotfiles repo:

- Strict `set -Eeuo pipefail`, structured `_on_error` trap, and `shellcheck` clean
- A `requirements.zsh` / `optional-deps.zsh` convention with installer-driven dep reporting
- Atomic file writes (`tmp + mv`), backups before destructive changes, marker-based config sections (`# BEGIN master-oogway:…`)
- Defense-in-depth around zip extraction (path-traversal pre-scan + named subdir + refuse-if-exists)
- A managed-marker pattern (`# master-oogway:managed`) that protects user files from clobber
- SSH wrapper that uses `BatchMode=yes` probes, validates target hostnames, and respects an opt-out env var
- Explicit handling of name collisions for the LAN auto-aliasing (`s-<host>` fallback)
- A theme engine with a single source-of-truth schema, hash-based drift detection, and atomic state-file rewrites
- A self-aware installer that distinguishes curl-pipe / update / dev modes from where it lives on disk

**The main remaining weaknesses** are around (1) inferring trust from path/string heuristics (mode detection, "is this a master-oogway clone"), (2) silent race conditions when two zsh shells start within seconds of a schema change, (3) a small set of injection-shaped string-interpolation sites in fzf preview commands that are mostly but not exhaustively guarded, and (4) operational debt: no automated tests, no CI, no telemetry, no schema migration story, no versioning of the on-disk state file beyond a hash.

A severity-prioritized finding list and concrete fixes follow.

---

## 1. Architecture

### 1.1 Trust boundaries (data-flow view)

```
            user terminal
                 │
                 ▼
        ~/.zshrc  ◄── (created once, marker-guarded)
                 │
                 ├── source ~/.config/master-oogway/conf.zsh  ← user-editable
                 ├── source custom-pre-zsh/*.zsh             ← user drop-in
                 ├── source oh-my-zsh.sh
                 │     └── source ZSH_CUSTOM/plugins/*/*.plugin.zsh
                 │           └── many of these source requirements.zsh first
                 ├── source custom-plugins/*/*.plugin.zsh    ← user drop-in
                 └── source custom-zsh/*.zsh                 ← user drop-in

   gitstatusd  ←── started by dragon/transient.zsh::__start_gitstatus_once
                   queried on every precmd

   lan-hosts cache ←── written by background _mo_lan_discover.zsh
                       read by mo-lan-ssh.plugin.zsh on every shell start
```

There are five **trust boundaries** worth labelling explicitly:

1. **User → installer**: install.sh runs as the unprivileged user with selective `sudo` priming for sshd_config edits and apt-get installs.
2. **Remote → installer**: `curl | bash` is the trust-the-domain assumption. Cloning happens to `~/.master-oogway/`, then `exec bash $INSTALL_DIR/install.sh`.
3. **Network → mo-lan-ssh**: discovery accepts hostnames from DNS AXFR / nmap+rDNS / arp-scan+rDNS / known_hosts. Validated through `filter_names` (`_mo_lan_discover.zsh:110-127`).
4. **User shell → SSH wrapper**: `_mo_lan_ssh_wrapper` rewrites how `ssh <host>` works for LAN-discovered targets, including silent `ssh-keygen -R` on key mismatch — a genuine policy decision.
5. **DRAGON__ env vars → renderer**: trust forwarded SSH env (SendEnv DRAGON__*). The receiving side does not re-validate values; arbitrary `%` escapes etc. are passed straight into prompt-expansion contexts.

### 1.2 Lifecycle (shell startup)

Tracing a fresh shell start as it touches each component:

1. zshenv loads (`EDITOR` / `VISUAL` only).
2. zshrc sets locale, history, completion, sources `conf.zsh`, runs `custom-pre-zsh/`.
3. Plugin-tuning vars set (autosuggestions, syntax-highlighting, you-should-use, history-substring-search).
4. gitstatus sourced explicitly *before* OMZ so OMZ themes can pick it up.
5. OMZ runs `oh-my-zsh.sh`, which loads `plugins=(...)` in order. mo-trash → `alias rm=trash-put`, mo-lan-ssh registers `ssh()`, mo-projects loops `~/projects/*(N/)` and aliases each, etc.
6. mo-lan-ssh's anon function runs: checks cache age and network ID, kicks `_mo_lan_refresh_async` (background, flock'd) if stale, applies aliases synchronously from any cached results.
7. dragon.zsh-theme sources the four dragon files; dragon.zsh registers `add-zsh-hook precmd __update_prompt` etc.
8. `__update_prompt` runs once → starts gitstatusd → schedules async query → renders lprompt+rprompt.
9. notifier.zsh's anon function runs: `stat schema.zsh` mtime vs cached, only hash if changed; print one-line notice if a new var exists.
10. User drop-ins (`custom-plugins/*.plugin.zsh`, `custom-zsh/*.zsh`).
11. Key bindings, `LESS`.

The order is intentional and documented in zshrc.master-oogway:135-194 — particularly that `zsh-syntax-highlighting` must be last. **No issues found here**; the ordering comment is load-bearing and accurate.

### 1.3 Component coupling

Coupling is mostly **acceptable and intentional**:

- **dragon theme ↔ gitstatus**: previously hard coupling. Fixed: `transient.zsh` now checks `(( $+functions[gitstatus_query] ))` at source time and sets `_DRAGON_GITSTATUS_AVAILABLE`; `__update_gitstatusd` returns early when false, so the git segment is silently omitted and all other segments render normally. zshrc:128-132 still prints the yellow notice on the missing-submodule path.
- **mo-cli ↔ install.sh**: hard coupling (`master-oogway update` shells out to `$_MO_INSTALL_DIR/install.sh`).
- **mo-lan-ssh ↔ ssh()**: mo-lan-ssh installs a `ssh()` function. If a user later defines their own `ssh()` after sourcing, mo-lan-ssh detects this via `declare -f ssh` and refuses to overwrite (`mo-lan-ssh.plugin.zsh:225-227`). Good defensive design.
- **mo-trash ↔ all other rm callers**: `alias rm=trash-put` is the single most invasive change in the bundle. The README does not warn that this changes default `rm` semantics globally (covered later).

The override / additive split documented in zshrc:157-167 is a strong design choice — users can see at a glance what changes system behavior and what merely adds.

---

## 2. Severity-ordered findings

I use these labels: **CRIT** (potential incident / data loss / privilege issue), **HIGH** (real correctness/security weakness reachable in normal operation), **MED** (latent bug, UX defect, operational risk), **LOW** (style / over-engineering / minor maintainability), **INFO** (notable design choice worth documenting).

### CRIT — there are none.

I looked for them. Honest assessment: the things that *could* be critical (the `rm` alias, the silent `ssh-keygen -R` purge, the curl|bash bootstrap, the sshd_config edit) are all guarded with confirmations, scoping, or markers. No injection sink, no unbounded `eval`, no setuid creation, no insecure-default temp file leak, no token leakage on disk. The historical findings (zip-slip, fzf preview RCE, syntax-highlighting injection, zshrc clobber) referenced in `archive.md` have been fixed.

### HIGH-1 — install.sh trusts any directory containing the string "master-oogway" as a clone

`install.sh:278-284`:

```bash
_running_from_master_oogway_clone() {
    local dir; dir="$(_script_dir)" || return 1
    local remote
    remote=$(git -C "$dir" remote get-url origin 2>/dev/null) || return 1
    [[ "$remote" == *"master-oogway"* ]]
}
```

The check is "does the script directory contain a `.git` whose `origin` URL substring-matches `master-oogway`?". An attacker who can convince the user to clone `https://example.com/master-oogway-evil.git` and run its `install.sh` lands in dev mode — `~/.master-oogway` becomes a symlink to the attacker's repo, and `_init_plugins` runs from inside it on every subsequent invocation.

**Impact**: an attacker who can get a user to clone *any* repo with `master-oogway` in the name and run `./install.sh` from inside it gets persistence: future runs of `~/.master-oogway/install.sh` re-exec the attacker's code.

**Realistic scenario**: low likelihood (user has to clone the wrong thing first), but the substring match is a known footgun pattern.

**Fix**: change to exact remote URL match:
```bash
[[ "$remote" == "$REPO_URL" || "$remote" == "${REPO_URL%.git}" ]]
```
Or require an upstream-pinned commit/marker file inside the repo (e.g., the existence of `.master-oogway-canonical`).

### HIGH-2 — `dismissed_hash` overwrites itself silently after one print ✓ FIXED

**Fixed**: removed the auto-dismiss write from `notifier.zsh`. The notification now repeats on every shell open until the user explicitly runs `dragon-configure --dismiss`. The hint line updated to `"(to silence this: dragon-configure --dismiss)"` — accurate because dismissal no longer happens automatically.

### HIGH-3 — race window between concurrent shells rewriting state file

Three sites use the pattern `tmp="${state_file}.tmp"; ... > "$tmp"; mv "$tmp" "$state_file"`:

- `notifier.zsh:46-51`
- `configure.zsh:770-775` (--dismiss path)
- `configure.zsh:537-621` (wizard write)

The tmp filename is **fixed** per target file. If two shells open in the same second (e.g., a new tmux session that spawns multiple panes), both reach the rewrite, both `>` the same tmp file, both `mv` it. The `mv` is atomic but the `>` is not — one shell's tmp may be truncated mid-write when the other's `mv` happens. Window is small but real.

**Impact**: state file corruption (truncated/missing `vars_hash=` line). On next shell start the wizard runs `_dragon_load_current_conf` against a partial file → defaults take over for any missing lines, but the user's choices may silently revert.

**Fix**: use `mktemp` for the tmp name, or `flock -n` around the rewrite block (you already use flock for mo-lan-ssh discovery — reuse the pattern):
```zsh
local tmp; tmp=$(mktemp "${state_file}.XXXXXX") || return
... > "$tmp" && mv "$tmp" "$state_file"
```

### HIGH-4 — `_mo_lan_ssh_wrapper` silently purges known_hosts entries on key mismatch

`_mo_lan_trust.zsh:67-79`:

```zsh
if [[ "$probe_err" == *"REMOTE HOST IDENTIFICATION HAS CHANGED"* ...
    print -P "%F{yellow}[mo-lan-ssh]%f Host key changed for $target_host — purging old key (LAN host: trusted)"
    ssh-keygen -R "$target_host" >/dev/null 2>&1
```

This is by design — the README explicitly calls LAN hosts "trusted" — but it's a **policy choice** that future-you, or anyone reading the README quickly, may not realize is in effect. If the LAN is ever genuinely compromised (rogue device, spoofed mDNS, ARP poisoning, MITM router), this wrapper actively helps the attacker by suppressing the loud SSH warning that exists for exactly this case.

**Impact**: the canonical SSH MITM warning is suppressed for any host in `_MO_LAN_HOSTSET`. Users who treat their LAN as trusted (the documented assumption) are unaffected; users on untrusted-LAN environments (coffee shop, conference Wi-Fi, hotel network) are at higher risk than vanilla SSH.

**Severity**: high because the wrapper is opt-out (default-on), the policy is non-obvious from the bare command name `ssh`, and the README mentions but does not foreground the key-purge behavior.

**Fix**: at minimum, log the old fingerprint that was purged to a file (`~/.config/master-oogway/lan-key-changes.log`) so an audit trail exists. Better: refuse to auto-purge if the laptop is on a different network than when the original key was learned (you already compute `network_id`).

### HIGH-5 — `dragon-configure --preset` interpolates user-controlled preset name into a personal-preset file path ✓ FIXED

**Fixed**: added `[[ "$_preset" =~ ^[a-zA-Z0-9_-]+$ ]]` validation before the path is constructed, matching the existing `--export` guard. Invalid names (e.g. `../../../etc/passwd`) now print a clear error and return 1 before touching the filesystem.

### HIGH-6 — `mo-color` `command cat` on stdin includes binary content / huge buffers ✓ FIXED

**Fixed**: piped path now streams — emits the color escape, pipes stdin through `command cat` directly, then emits reset. No shell variable buffers stdin. Interactive path (`[[ -t 0 ]]`) still uses `"hello world"` + `printf` unchanged.

### HIGH-7 — `_check_optional_deps` sources every `optional-deps.zsh` found in the plugin tree under a sub-shell ✓ FIXED

**Fixed**: glob restricted from `plugins/*/optional-deps.zsh` to `plugins/mo-*/optional-deps.zsh`. Vendor submodules (`gitstatus`, `you-should-use`, etc.) are now excluded by construction.

### MED-1 — `_init_plugins` silently `rm -rf`s plugin directories with no `.git`

`install.sh:319-325`:

```bash
for plugin in gitstatus you-should-use zsh-autosuggestions zsh-syntax-highlighting; do
    local plugin_dir="${plugins_dir}/${plugin}"
    if [[ ! -e "${plugin_dir}/.git" ]]; then
        [[ -d "${plugin_dir}" ]] && rm -rf "${plugin_dir}"
        missing+=("${plugin}")
    fi
done
```

If a developer manually copies (rather than git-submodule-clones) gitstatus into `omz-custom/plugins/gitstatus/`, the next install.sh run wipes it. The trigger is "no `.git` inside" — a common state when the submodule was vendored manually for hacking.

**Severity**: med. Low likelihood of hitting it, high blast radius if you do (loses local edits).

**Fix**: only `rm -rf` if the directory looks like a stale submodule shell (e.g., contains no untracked files, or contains a `.gitmodules`-derived marker file). Simpler: ask before deleting.

### MED-2 — `fbranch`'s `default_branch` is interpolated into the fzf preview shell unsanitized

`mo-git.plugin.zsh:100-130`. Branch *names* are validated against `unsafe_chars=$'$`();|&<>"\'\\'`, but `default_branch` (read from `git symbolic-ref refs/remotes/origin/HEAD`) is not. Git's `check-ref-format` allows `;`, `|`, `&`, etc. in refs in many configurations, so a remote that names its default branch `main; rm -rf ~` would, when the user runs `fbranch` in that clone, inject into the preview shell.

Likelihood is negligible (no real remote does this) but the asymmetric defense is the kind of thing future-you forgets and undoes.

**Fix**: apply the same `unsafe_chars` filter to `default_branch`, or pass it via env: `default_branch="$default_branch" fzf ...` and reference `$default_branch` inside the preview shell.

### MED-3 — `frg`'s filename-safety filter is bypassable

`mo-search.plugin.zsh:65-72`: rejects filenames matching `[$\`();|&<>"\x27\\]`. Missed metacharacters: `*`, `?`, `[`, space, newline (well, newlines aren't possible because the regex acts per-line), `~`, `!`. None of these are direct shell expansion sinks in the `bat ... {1}` preview *as long as {1} is properly word-split*, but `bat --highlight-line {2} {1}` with `{1}=foo bar.txt` would treat `foo` and `bar.txt` as two args. That's a low-impact splitting bug, not RCE.

**Fix**: drop the regex filter (you can't enumerate every metacharacter) and instead make the preview shell quote-safe by reading filenames via `--read0` and passing them as positional args. Better still, use `--with-shell sh -c` and quote properly.

### MED-4 — fbranch / sshto / fzf-using functions do not check for `nul` filename injection

None of the fzf pickers using line-separated input (`printf '%s\n' branches`) handle filenames or values containing actual newlines. For LAN hostnames this is impossible (filter restricts charset). For project dirs (`mo-projects`) any directory named with a literal newline would split into two entries. **Practical impact: zero.** Worth noting only because new contributors might add a fzf picker over an unvalidated source.

### MED-5 — `_dragon_render_preview` interpolates `$HOME` / `$USER` into a zsh -c heredoc

`configure.zsh:187-214`: builds a `zsh -c "..."` string and uses `${HOME}` and `${USER}` interpolated by the outer shell. HOME/USER are typically trusted, but the pattern is risky — if anything inside is ever changed to interpolate a less-trusted variable, the function is one-character away from RCE.

**Fix**: pass values through env (`HOME_FAKE="$HOME" zsh -c '... HOME=$HOME_FAKE ...'`) or read them inside the inner shell directly (`HOME` is already exported).

### MED-6 — `mo-env`'s "edit value in $EDITOR" writes secrets to /tmp

`mo-env.plugin.zsh:30-36`:

```zsh
tmpfile=$(mktemp)
echo "$var_value" > "$tmpfile"
${EDITOR:-vim} "$tmpfile"
new_value=$(command cat "$tmpfile")
rm -f "$tmpfile"
```

`mktemp` defaults to `/tmp/` with mode 0600 on Linux, so other users can't read it. Still, if the user runs `fenv -E` on `GH_TOKEN` or `AWS_SECRET_ACCESS_KEY`, the secret hits the filesystem briefly. On filesystems with journaling, traces may persist after `rm`.

**Fix**: `mktemp -p "$XDG_RUNTIME_DIR"` (tmpfs, cleared on logout) or `mktemp` with `O_TMPFILE` semantics (not portable to shell). At minimum, `chmod 600` defensively even though mktemp already does it, and add a one-line warning in `fenv -h`.

### MED-7 — `please` reconstructs the last command via `${(z)last}` then re-quotes — strips redirections and trailing comments

`mo-shell-tools.plugin.zsh:113-119`:

```zsh
local -a cmd
cmd=( ${(Q)${(z)last}} )
[[ "${cmd[1]:-}" == "sudo" ]] && cmd=( "${cmd[@]:1}" )
sudo "${cmd[@]}"
```

`(z)` splits respecting quoting but reuses every token — redirections (`>`, `2>&1`), pipes (`|`), backgrounding (`&`), and trailing comments come back as plain args. So `please` after `apt update | tee log.txt` re-executes `sudo apt update '|' tee log.txt` — error. Functionally surprising.

**Fix**: detect any of these tokens and fall back to `sudo zsh -c "$last"` (with appropriate quoting). Or simpler: document that `please` only works for simple commands.

### MED-8 — `psgrep` matches case-insensitively against the full command line — false positives for common substrings

`mo-process.plugin.zsh:8-9`: `pgrep -lif "$1"` matches anywhere in any arg. `psgrep ssh` will match every Chrome tab whose URL contains `ssh`. Cosmetic, but it cuts the utility of the tool.

**Fix**: default to matching against `comm` (`pgrep -lf` without `-i`, or with `-x` for exact); add an `-a/--all` flag for the current behavior.

### MED-9 — `mo-welcome` reads `/etc/os-release` into the shell with `. /etc/os-release`

`mo-welcome.plugin.zsh:13`: `[[ -r /etc/os-release ]] && . /etc/os-release` sources a system file into the user shell. On Ubuntu this is fine; on a hypothetical malicious / corrupted `/etc/os-release` it executes arbitrary code at *every shell start*. The file is owned by root, mode 644 — so this requires root to corrupt. Low practical risk, but worth replacing with:
```zsh
[[ -r /etc/os-release ]] && {
    PRETTY_NAME=$(awk -F= '$1=="PRETTY_NAME"{gsub(/"/,"",$2); print $2}' /etc/os-release)
}
```

### MED-10 — Shell start performance: too many fork-heavy probes for non-essential features

Per-shell-start forks (counted from my reading):

- mo-lan-ssh: `ip route show default` x2, `ip -o -f inet addr` x2, `md5sum`, `cut`, `stat`, `grep` (cache_network), `sha256sum` (in some paths). Roughly 6-8 forks if cache exists and is fresh.
- mo-projects: one glob expansion (no fork), per-project alias inline (no fork).
- dragon notifier: `stat`, `grep` x3, `cut` x3, optionally `md5sum`. Roughly 7-10 forks, but only when state-file mtime says we need to re-hash.
- dragon defaults init: zsh-internal, no forks.
- mo-welcome: `uname` x2, `/proc/uptime` (read), `EPOCHSECONDS` (no fork). 2 forks.
- mo-build: `nproc` x2 (used in a `?:` so both branches evaluate). 2 forks at load time, cached.

Total under ~25 forks on a warm cache shell start. Measurable but not bad. Worst case: cold cache + network change + new schema hash = ~50 forks. A `typeset -F SECONDS` benchmark would be a useful addition.

**Suggested improvement**: replace `md5sum | cut -d' ' -f1` with zsh's native `zsh/system` module hash or accept the perf trade-off and document it. `read -r < /proc/uptime` instead of using `head`/`awk`. Cache `network_id` for the lifetime of the shell.

### MED-11 — `_check_zshrc_drift` compares user file to template byte-for-byte

`install.sh:550-560`: warns whenever user's `.zshrc` ≠ template. The marker pattern was designed precisely so users can edit freely, but the drift detector then nags on every install run for any edit. The directive "edit freely" and the warning "your file differs from current template" are in tension.

**Fix**: compare against `${ZSHRC}.upstream-snapshot` (which the installer already maintains, line 576) — drift should only mean "the template changed and you may want to merge", not "you edited freely". Today's logic flags both.

### LOW-1 — Duplicated COLORS / xterm conversion logic

The named-color table appears verbatim in three places:
- `dragon.zsh:43-48`
- `mo-color.plugin.zsh:3-9`
- `configure.zsh:290-291` (as a help string)

If you ever want to add e.g. `darkgreen` or rename `grey→gray-only`, you touch three files. Worth extracting to a shared `omz-custom/lib/colors.zsh` sourced by both.

### LOW-2 — The dragon theme uses **mixed indentation** (tabs in parts/*.zsh; spaces in configure.zsh)

Bash/zsh editorconfig says `indent_style = tab` for `*.zsh`, but configure.zsh and schema.zsh use 4-space indentation. The editorconfig will be applied to one and not the other, depending on which a contributor edits first.

**Fix**: pick one. The repo's editorconfig says tabs — convert configure.zsh and schema.zsh to tabs.

### LOW-3 — `_DRAGON_THEME_DIR` set as readonly is missing — aliases.zsh defines it as a regular global, so a second source overwrites silently

`aliases.zsh:6`: `typeset -g _DRAGON_THEME_DIR="${0:a:h}"`. Add `-r` if you intend it to be immutable post-load.

### LOW-4 — `m()` (parallel make) hardcodes `nproc` at plugin source time

`mo-build.plugin.zsh:3`: `_mo_build_jobs=$(( $(nproc 2>/dev/null || echo 1) > 0 ? $(nproc 2>/dev/null || echo 1) : 1 ))`. Calls `nproc` twice. If the user changes CPU affinity later (e.g., via cgroups), `m` keeps the original count. Acceptable, but `nproc` is cheap enough to evaluate every call.

### LOW-5 — `tunnel`'s parse regex accepts `0.0.0.0:port` only as a *bind* address, not as a "remote IP that's actually local"

`mo-ssh-tunnel.plugin.zsh:92-95`: the locality check treats `0.0.0.0` as local. That's right for `-L` bind. But `tunnel remote:80 to 0.0.0.0:8080` will pick `-R` and bind `0.0.0.0:80` on the remote side — exposing a port on the remote that the remote sshd may refuse (`GatewayPorts no`). The error from sshd will surface confusingly. Add a note in the help text.

### LOW-6 — `mo-trash`'s `trash-restore` does line-number-to-selection mapping by re-running `trash-list` twice

`mo-trash.plugin.zsh:28-37`: runs `trash-list` once for fzf, then again to find the line number. If a delete happens between the two calls (concurrent shell), the line number is wrong. Edge case but worth `nl -b a` once and using the indexed output for both.

### LOW-7 — `frg` invokes `${EDITOR:-vim}` with `"+${linenum}"` syntax that nvim/vim understand but VSCode (`code -g file:line`) does not

`mo-search.plugin.zsh:82`: assumes vim-family editor flag. `code`, `helix`, `kakoune` use different syntax. Add a small `EDITOR_LINENO_FMT` env or check `$EDITOR` against a known list.

### LOW-8 — Many `command -v X &>/dev/null || { echo missing; return; }` patterns; consider a shared helper

There are 61 occurrences of `command -v X &>/dev/null`. Sharing a `_mo_require <cmd> [hint]` helper would shrink and centralize this — but doing so re-introduces a `mo-utils` dependency that you deliberately eliminated. The previous decision was correct for plugin isolation; just noting the cost.

### LOW-9 — `mo-auto-ls` runs `ls` after every `cd` — on a 50k-file directory this is several hundred ms

`mo-auto-ls.plugin.zsh:2`: `_ls_after_cd() { ls; }`. No size cap. A `cd /var/log/journal` or `cd ~/.cache` and you'll wait visibly. Add a `MO_AUTO_LS_MAX_ITEMS=200` cap that falls back to a one-line "<dir> has N items" notice.

### LOW-11 — `mo-color`'s `_mo_fg`/`_mo_bg` emit `\e[38;2;r;g;bm` ANSI 24-bit truecolor codes unconditionally

`mo-color.plugin.zsh:73-74`. Terminals without truecolor support (older xterm, dumb terminals, some CI/log scrapers) display them garbled. Detect with `[[ "${COLORTERM:-}" == truecolor ]]` and fall back to 256-color codes.

### LOW-12 — `serve` defaults to `127.0.0.1` (good), but `SERVE_BIND=0.0.0.0` has no auth and no TLS

`mo-network.plugin.zsh:16-17`. The warning is printed, but documented use cases of `serve` (sharing a directory with another machine) inevitably push users to set the env var. Consider integrating `python3 -m http.server` + Basic auth via env (`SERVE_USER`/`SERVE_PASS`) or recommending `caddy file-server` for non-localhost.

### LOW-13 — `mo-cli`'s `diff-zshrc` runs `git difftool` if `diff.tool` is set

`mo-cli.plugin.zsh:34-43`. For users whose `diff.tool=meld` (the bundle default!), this blocks the terminal on a GUI window. Acceptable but surprising. Add `--text` flag for forced TTY diff.

### LOW-14 — `mo-welcome` calls `IFS=. read -r up_secs _ < /proc/uptime` — Linux-only

The repo header says "requires Linux (Ubuntu 24.04)" so this is fine, but if the plugin ever ships in a more portable bundle, `/proc/uptime` doesn't exist on macOS/BSD. Marker the platform assumption inline.

### LOW-15 — Trailing line numbers in CONTRIBUTING.md describe "26 plugins" but the README says "26", omz-custom/README says "20 master-oogway plugins". Counts diverge across docs.

Worth a single source of truth (e.g., `make plugin-list` that scans `omz-custom/plugins/mo-*/`).

### INFO-1 — `bash -c "</dev/tcp/host/port"` in `probe_host` is a bash-ism, not zsh

`_mo_lan_discover.zsh:134` — the script is `#!/usr/bin/env zsh` but uses `bash -c "..."` to get TCP. Slightly costly (extra fork), but portable. A pure-zsh alternative is `zsocket` from `zsh/net/tcp`, but that's not in the base zsh distribution everywhere. Current code is the right call.

### INFO-2 — The discovery strategies (AXFR / nmap / arp-scan / known_hosts) try in *priority* order, first non-empty wins

This is faster but biases toward whichever strategy returns *anything*. A DNS server with stale entries (former laptops, decommissioned hosts) will always "win" over a fresh nmap scan, even when nmap would have found more. Worth a `MO_LAN_PROBE_ALL=true` to union all strategies (probe pass dedupes).

### INFO-3 — The `# master-oogway:managed` marker is load-bearing — losing it silently re-enables clobber

Documented inline at zshrc:1-5 and a comment in install.sh:564. If a user runs sed/dotfile-manager that strips comments, their `.zshrc` becomes vulnerable to overwrite on next install. Consider a second marker that's harder to lose (e.g., a unique sentinel string or a sidecar file `${ZSHRC}.managed`).

### INFO-4 — The forwarded `DRAGON__*` env vars over SSH cross machine trust boundaries

When the bundle is installed on both sides, SendEnv/AcceptEnv pass user-edited values straight into prompt-expansion contexts on the remote. Most fields are color names / booleans (safe). String fields like `DRAGON__SSH_PREFIX` are passed verbatim into `print -P` which interprets `%`-escape sequences (the receiver's `__dragon__show` doubles `%` only on PREFIX/SUFFIX, line `helpers.zsh:63-64`, so `%n`/`%m`/etc. in the *content* of those fields would be interpreted). On a multi-user shared-host setup, a malicious user with shell access could not easily exploit this (they'd need their own SSH session to write DRAGON__ values), but it's a real consideration if you ever build a `dragon-share` feature.

### INFO-5 — The repo has NO automated tests, NO CI, NO release tagging

`git log` shows clean commit history but there is no `.github/workflows/`, no `make test`, no `bats`/`zunit` test suites, no version tags. Validation is purely manual (`bash -n`, `shellcheck`, `zsh -n`). For a project at this size and scope, even a minimal `zsh -n` GitHub Action across all .zsh files would catch typos before merging.

---

## 3. Component-by-component notes (the things I didn't promote to findings)

### install.sh

- The `_on_error` trap (lines 40-48) prints a useful breadcrumb (function, file, exit code, BASH_COMMAND, line number) — better than most personal scripts' error handling.
- `apt_install` is well-shaped: returns 0/1 without die-ing so the caller decides. Good separation.
- `_find_backup` (lines 105-126) is well-commented and handles the legacy bare-name backup correctly.
- The `confirm` function explicitly resets stty before reading (`stty sane < /dev/tty`) — defends against terminals left in raw mode by an earlier command. Subtle and correct.
- The uninstall path is more complete than typical: restores backups, removes SendEnv/AcceptEnv blocks with markers, asks before deleting `${CONF_DIR}`, leaves `.zshenv`/`.editorconfig` with explicit warnings.
- `[[ "$(uname)" == "Linux" ]]` at line 519 is a hard gate — clean failure for macOS users. Bundle is honest about its scope.

### dragon theme

- The schema-driven design (every var is in `_DRAGON_DEFAULTS` + `_DRAGON_TYPE` + `_DRAGON_HINT` + `_DRAGON_GROUP_VARS`) means adding a knob requires editing one place. Strong design.
- `parts/helpers.zsh` consolidates the per-segment boilerplate with `__dragon_copy_defaults` / `__dragon_finalize`. Significant readability win versus what each segment used to be.
- The single-quoted output format (`configure.zsh:589-595`) immunizes user values from shell expansion. Comments explain why.
- `_dragon_render_preview` runs in a subshell so exports auto-clear; the inner `zsh -c` is its own subshell, doubling the isolation. Costly (one fork per group during the wizard) but safe.
- The SSH-forwarding guard (`DRAGON__FORWARDED=1`) is the right shape: receiver sees the var, returns early from `conf.zsh`, doesn't re-export defaults that would shadow forwarded values.

### mo-lan-ssh

- The `flock -n` in `_mo_lan_refresh_async` is the right primitive — non-blocking, exits cleanly if another shell is refreshing.
- The combined SHA over auto-cache + manual-overlay correctly invalidates the ssh-config rewrite on either change.
- `_mo_lan_extract_target` is a correct mini-implementation of ssh's argv parser. Lists the right option letters that take values.
- Discovery falls back through four strategies, never blocking shell start, with cache-based ttl + network-id checks. Honestly impressive for a personal-dotfiles plugin.

### mo-files

- The zip extraction defenses (path-traversal pre-scan via `unzip -Z1`, named-subdir extraction, refuse-if-exists) are textbook correct. Many production tools get this wrong.
- The symlink check before in-place gz/bz2/xz/zst decompression is a thoughtful defense.
- `bak` uses `cp -a` (preserves mode/timestamps/symlinks) and includes nanoseconds in the timestamp to allow multiple backups within one second.
- `compress` rejects if the archive already exists — refuses to overwrite. Correct.

### mo-git

- The branch-safety filter in `fbranch` is a real defense against a real (if narrow) injection vector. The yellow "hid N branches" notice tells the user when something was filtered.
- `groot`'s submodule-aware behavior (cd to outer repo when already at inner root) is a nice ergonomic touch — most git plugins don't think to do that.
- `gsum` uses zsh array counting instead of `wc -l | tr -d ' '` — small perf win, demonstrates author cares.

### mo-color

- Hex / decimal / named color support is comprehensive.
- Luminance-based contrast (`lum = r*299 + g*587 + b*114`) is the right standard for picking black/white text on a colored background.
- The palette grid is a UX win — `color palette` makes the 256-color space tangible.

### mo-projects

- The fzf preview is built with proj_dir interpolated at *call time* with quotes around it (`mo-projects.plugin.zsh:51`) — defends against weird-named project dirs. The previous bug ("print-l glob quotes dirnames; attempted array+printf fix") is fixed correctly here.

### mo-search

- The `frg` rg-with-NUL parsing is solid. `awk 'BEGIN { FS="\0" }'` handles filenames containing colons correctly. Most "fuzzy ripgrep" implementations on the internet get this wrong.

### mo-shell-tools

- `clip` reads all of stdin into `data`, then prints it back — fine for typical clipboard usage; same OOM caveat as `mo-color` (HIGH-6) if someone pipes a huge file.
- `calc` validates `expression` characters with a regex before passing to `bc` — narrow but effective.
- `'?'()` as a function named literally `?` is a delightful zsh trick (works because zsh `INTERACTIVE_COMMENTS` is on but `?` is allowed in function names).
- `please` has the redirection issue (MED-7).

### mo-safety-override

- `cp -i`, `mv -i`, `mkdir -pv` — sensible.
- The `_confirm_reboot` 30-second timeout (`read -r -t 30`) is a nice touch: if you reboot from a CI/automated context that has no TTY, it times out rather than hanging.

### mo-trash

- The wholesale `alias rm=trash-put` is impactful but documented. The README does not list the user-visible behavioral diffs (no `-f` semantics, no globs work the same way for some edge cases, different deletion-permission rules in some FS). Worth a section in the README.

---

## 4. Cross-cutting analysis

### 4.1 Security

| Area | Posture |
|------|---------|
| Shell injection via user input | Mostly defended (fbranch filter, frg filter, hostname filter, manual-add validation, port validation). One asymmetry (MED-2). |
| Path traversal | Defended (zip pre-scan, hostname charset, preset name in `--export`, missing in `--preset`). |
| Privilege escalation | None introduced. `sudo` calls are explicit, scoped, surfaced to user. |
| Secrets on disk | Two minor cases: `mo-env -E` (MED-6), `fenv` editor flow. |
| MITM resistance | SSH wrapper trades resistance for convenience (HIGH-4). Documented choice. |
| Supply chain | Four upstream submodules; `optional-deps.zsh` scanning now restricted to `mo-*` plugins (HIGH-7 ✓). |
| curl-pipe-bash bootstrap | Standard practice, no integrity check (no SHA256 / no signed tag verification). Not worse than the OMZ install line it mirrors. |
| Setuid / setgid creation | None. |
| /tmp race conditions | None I could reach (mktemp creates 0600). |

### 4.2 Reliability

| Failure mode | Behavior |
|--------------|----------|
| Submodule directory exists but `.git` is missing | Installer `rm -rf`s it (MED-1) |
| Two zsh shells racing state writes | Potential corruption (HIGH-3) |
| gitstatusd crash | Theme falls back to empty git segment; gracefully degrades |
| Network unreachable during discovery | All four strategies fail cleanly with stderr message; alias set is empty for this shell |
| User's `~/.zshrc` modified, template changed | Drift warning prints; user is never auto-overwritten |
| sshd_config validation fails after install | Marker block is auto-reverted (`install.sh:721-725`) — admirable |
| Sudo password not entered during sshd install | `sudo -v \|\| true` keeps things flowing; subsequent sudo calls re-prompt |
| Out-of-disk during state-file write | `mv tmp state` will fail, leaving `state` unchanged but tmp dangling (no cleanup) |
| Out-of-memory during huge stdin to `color` / `clip` | `color` fixed (HIGH-6 ✓); `clip` still buffers (acceptable for clipboard) |

### 4.3 Concurrency

- `mo-lan-ssh` uses `flock -n` for discovery serialization. Correct.
- gitstatusd uses its own internal serialization (upstream code).
- All dragon state-file writes use the same fixed tmp name — concurrent shells can corrupt (HIGH-3).
- Plugin loading order is enforced by the `plugins=(...)` array in zshrc; no concurrent load.

### 4.4 Observability

- No metrics. No structured logs. No health-check command.
- `mo-lan-ssh status` is the closest thing — surfaces cache age, network ID, host count, ssh-config state. Good model to extend.
- `MO_LAN_VERBOSE=true` triggers `_mo_lan_log` (one print fn). Other plugins have nothing equivalent.
- A `master-oogway doctor` command that verifies: gitstatus alive, dragon hash consistent, ~/.ssh/config has Include line, no plugin failed to load, optional-deps installed/missing summary — would close most diagnostic gaps.

### 4.5 Performance

Cold-shell start is the load-bearing metric. Rough budget:

- gitstatus binary start (one-shot): ~3-5 ms
- OMZ load: ~200-400 ms (varies wildly with `compinit` cache freshness)
- All mo-* plugins together: ~50-100 ms (mostly `command -v` probes — could parallelize)
- mo-lan-ssh cache load: ~5-15 ms with cache, sub-ms without
- dragon defaults+notifier: ~5-10 ms warm, 30-50 ms cold (first hash)

Total ~300-500 ms cold, ~100-200 ms warm — fine for desktop use, would be slow for a SSH-into-jumpbox-via-script scenario. No latency regressions found.

### 4.6 Maintainability

- Comments are tight, justified, and explain WHY, not WHAT. (Notable line: `install.sh:103-126` — the `_find_backup` explanation.)
- README split is well-shaped: one user-facing README, one omz-custom README, one CONTRIBUTING, per-plugin READMEs.
- No dead code I could see.
- No "TODO" / "XXX" / "FIXME" markers in code (good for releases; less good for tracking known-issues — see suggestion below).
- 22 plugins all named `mo-*`, all sourcing the same `requirements.zsh` / `optional-deps.zsh` convention — consistent.

### 4.7 Portability

- Hard Linux-only assumption (uname check). Documented.
- Ubuntu/apt assumed everywhere ("try: sudo apt install X"). On Debian, Mint, Pop_OS this is fine; on Fedora/Arch users will be mildly annoyed by every hint suggesting `apt`.
- `/proc/uptime`, `ip route`, `getent` / `awk` patterns — all Linux-only.

### 4.8 Testability

- No tests. The shape of the code is testable (most functions are pure parsers — `_mo_lan_extract_target`, `_tunnel_parse`, `_dragon_load_current_conf_from`) but nothing exercises them.
- A `bats`/`zunit` suite for parsers alone (validate ssh target extraction, tunnel side parsing, hex color parsing, conf.zsh round-trip) would prevent regressions cheaply.

---

## 5. Concrete fix priorities

I'd implement these in this order (rough days of work):

1. **HIGH-2** ✓ — fixed: removed auto-dismiss from notifier; notification repeats until user runs `--dismiss`.
2. **HIGH-3** — use `mktemp` for state-file rewrites (1 h).
3. **HIGH-1** — tighten clone detection in install.sh (30 min).
4. **HIGH-5** ✓ — validate `--preset` name: added regex guard before path construction.
5. **MED-1** — confirm-before-rm in `_init_plugins` (30 min).
6. **MED-2** — sanitize `default_branch` in fbranch (15 min).
7. **MED-6** — `mo-env -E` to `$XDG_RUNTIME_DIR` (10 min).
8. **MED-11** — fix `_check_zshrc_drift` to compare against `${ZSHRC}.upstream-snapshot` (15 min).
9. **HIGH-4** — log purged keys to a file before `ssh-keygen -R` (30 min). Optionally gate on network-id stability (1 h).
10. **HIGH-7** ✓ — restrict `optional-deps.zsh` scanning to `mo-*` glob.
11. **INFO-5** — add a `.github/workflows/lint.yml` running `bash -n`, `shellcheck`, `zsh -n` on every PR (1 h).

---

## 6. Forward-looking suggestions

- **`master-oogway doctor`**: end-to-end health check (see 4.4). Roll up `mo-lan-ssh status`, dragon hash consistency, gitstatus liveness, ssh-config include line, optional-deps summary, last-install timestamp.
- **`dragon-configure --diff <preset>`**: show what would change before applying a preset.
- **Schema migration**: dragon's `vars_hash` only tracks the *set* of keys, not their values or types. If you ever rename `DIRECTORY_FORMAT` values or change `EXEC_TIMER_THRESHOLD` from int-as-string to int, there's no migration path. Add a `schema_version=` to the state file and a `_dragon_migrate_state` step.
- **`bats`/`zunit` tests** on the pure parsers — quickest path to confidence.
- **Tag releases** (semver: `v1.0.0`, `v1.1.0`). `mo-cli version` currently surfaces commit date+sha, which is informative but not navigable. Tags make rollbacks possible.
- **Performance regression budget**: track shell-start time in CI. `time zsh -ic exit` is cheap; assert under 400 ms.
- **`MO_PROFILE=true`** that times each plugin's load (`{ source X.plugin.zsh; } 2>&1 | ts ms`) — useful for spotting newly-added forks.
- **Documented threat model**: explicit list of what you defend against vs accept (e.g., "we trust LAN", "we trust the apt repo signing keys", "we don't defend against malicious values in custom-plugins"). One paragraph in README.md saves a lot of unstated assumptions later.
- **Drop-in extension hooks for plugins** (similar to dragon's `custom-pre-zsh`/`custom-zsh`): a way for users to extend `mo-lan-ssh` exclude list, `mo-projects` directory, etc. via per-plugin local-config files rather than env vars. Env-var sprawl is starting to be a concern (`MO_LAN_TTL`, `MO_LAN_SSH_PORTS`, ..., `MO_PROJECTS_PROJ_DIR`, `MD2PDF_THEME`, `SERVE_BIND`, ...).
- **One-shot `master-oogway uninstall --dry-run`**: print what would be removed without removing.

---

## 7. What I'd ship to a senior engineer for review

Among the 22 plugins and 7 dragon files, the **highest-quality components** in this repo (by my standard for code I'd be happy to maintain) are:

- `install.sh` — particularly the mode-detection logic and the uninstall path
- `_mo_lan_discover.zsh` — multi-strategy fallback, clean separation
- `mo-files.plugin.zsh:31-47` — the zip extraction defense
- `configure.zsh` — the wizard structure (steps return 0/1/2, the preset-export flow, the conf-file round-trip)

The **components I'd most want a second pair of eyes on** before a v1.0 release:

- `_mo_lan_trust.zsh` — the silent key-purge policy (HIGH-4)
- `notifier.zsh` — the auto-dismiss UX (HIGH-2) ✓ fixed
- `install.sh:_running_from_master_oogway_clone` — the trust check (HIGH-1)

---

## 8. Observations on engineering practices in this repo

1. The single strongest engineering practice in this repo is the **schema-driven theme**: every DRAGON__ variable has a default, a type, a hint, and a group. The wizard, the conf-file writer, and the drift notifier are *all* derived from that one schema. Adding a new variable is a one-line edit to `schema.zsh`. Most personal dotfiles repos accrete config-file knowledge and renderer knowledge separately, then drift.

2. The second-strongest practice is the **marker pattern** (`# BEGIN master-oogway:...`/`# END ...`). It lets the installer locate and remove its own additions without ever owning the full file — a powerful "we don't own your config" guarantee. This is the inverse of the ChezMoi/yadm model and far more user-friendly.

3. The **`requirements.zsh` / `optional-deps.zsh` split** is the kind of small convention that scales — hard deps gate plugin loading with a yellow notice, soft deps appear as a single grouped install table at the end of `install.sh`. Worth borrowing for any plugin system.
