# `s-<hostname>` fallback when the bare name collides with an existing
# command/alias/function/builtin. Tab-completion for ssh/scp/sftp/rsync.
# Managed ~/.ssh/config.d/lan-hosts (Port directive for non-22 listeners).
# CLI: mo-lan-ssh list|refresh|status|setup|add|remove|trust|forget|help.
# An ssh wrapper auto-runs ssh-copy-id on first-password-prompt for LAN
# hosts, and auto-purges changed host keys (LAN trust). Disable wrapper
# with MO_LAN_AUTO_TRUST=false.
#
# Requires: dig (any one of strat_axfr/nmap/arp-scan/known_hosts for discovery)

# EPOCHSECONDS lives in zsh/datetime; load once so loader paths don't fork date.
# (b:EPOCHSECONDS is wrong — EPOCHSECONDS is a parameter, not a builtin.)
zmodload -F zsh/datetime p:EPOCHSECONDS 2>/dev/null

# ── Paths ─────────────────────────────────────────────────────────────────────

typeset -g _MO_LAN_SSH_DIR="${0:a:h}"
typeset -g _MO_LAN_SSH_DISCOVER="${_MO_LAN_SSH_DIR}/_mo_lan_discover.zsh"
typeset -g _MO_LAN_SSH_CACHE="${HOME}/.config/master-oogway/lan-hosts"
typeset -g _MO_LAN_SSH_LOCK="${HOME}/.config/master-oogway/lan-hosts.lock"
typeset -g _MO_LAN_SSH_SHA="${HOME}/.config/master-oogway/lan-hosts.sshconf.sha"
typeset -g _MO_LAN_SSH_MANUAL="${HOME}/.config/master-oogway/lan-hosts.manual"
typeset -g _MO_LAN_SSH_OUTPUT="${HOME}/.ssh/config.d/lan-hosts"
typeset -g _MO_LAN_SSH_USER_CONFIG="${HOME}/.ssh/config"
typeset -g _MO_LAN_SSH_USER_CONFIG_DIR="${HOME}/.ssh/config.d"

# ── Defaults (env-var overridable; same names used by _mo_lan_discover.zsh) ──

: ${MO_LAN_TTL:=86400}
: ${MO_LAN_SSH_PORTS:=22}
: ${MO_LAN_PROBE_TIMEOUT:=2}
: ${MO_LAN_PROBE_PARALLEL:=20}
: ${MO_LAN_EXCLUDE:=}
: ${MO_LAN_VERBOSE:=false}

# ── Helpers ───────────────────────────────────────────────────────────────────

_mo_lan_log() {
    [[ "$MO_LAN_VERBOSE" == "true" ]] || return 0
    print -P "%F{245}[mo-lan-ssh]%f $*" >&2
}

_mo_lan_network_id() {
    local gw iface subnet
    read -r gw iface < <(ip route show default 2>/dev/null \
        | awk '/default/ { print $3, $5; exit }')
    [[ -z "$iface" ]] && { echo "unknown"; return; }
    subnet=$(ip -o -f inet addr show "$iface" 2>/dev/null | awk '{ print $4 }' | head -1)
    print -- "${gw}-${subnet}" | md5sum | cut -d' ' -f1 | cut -c1-8
}

_mo_lan_cache_age() {
    local mtime
    mtime=$(stat -c %Y "$_MO_LAN_SSH_CACHE" 2>/dev/null) || { echo 999999999; return; }
    echo $(( EPOCHSECONDS - mtime ))
}

_mo_lan_cache_network() {
    [[ -f "$_MO_LAN_SSH_CACHE" ]] || return 1
    grep -m1 '^# Refreshed:' "$_MO_LAN_SSH_CACHE" 2>/dev/null \
        | sed -n 's/.*network=\([a-f0-9]*\).*/\1/p'
}

# Run discovery in background. flock prevents concurrent shells from trampling.
_mo_lan_refresh_async() {
    [[ -f "$_MO_LAN_SSH_DISCOVER" ]] || return
    (
        flock -n 9 || exit 0   # someone else is already refreshing — bail silently
        zsh "$_MO_LAN_SSH_DISCOVER" 2>/dev/null
    ) 9>"$_MO_LAN_SSH_LOCK" &!
}

_mo_lan_check_ttl_async() {
    local age
    age=$(_mo_lan_cache_age)
    if (( age > MO_LAN_TTL )); then
        _mo_lan_log "Cache stale (${age}s > ${MO_LAN_TTL}s) — refreshing in background"
        _mo_lan_refresh_async
    fi
}

_mo_lan_check_network_async() {
    local cur stored
    cur=$(_mo_lan_network_id)
    stored=$(_mo_lan_cache_network)
    if [[ -n "$cur" && -n "$stored" && "$cur" != "$stored" ]]; then
        _mo_lan_log "Network changed (${stored} → ${cur}) — refreshing in background"
        _mo_lan_refresh_async
    fi
}

# Merge auto cache + manual overlay into _MO_LAN_HOSTS (set) + _MO_LAN_PORTS
# (host→port map). Manual overlay wins on hostname collision. Lines are
# either "hostname" (port 22) or "hostname:port". # and blank lines skipped.
# Invalid lines (bad hostname or port) are skipped with a yellow warning to
# stderr so the user can clean them up — see _mo_lan_valid_host/_port.
_mo_lan_load_caches() {
    typeset -gA _MO_LAN_HOSTS=()
    typeset -gA _MO_LAN_PORTS=()
    local file line h p lineno
    # Manual first so it wins the "already present" check below.
    for file in "$_MO_LAN_SSH_MANUAL" "$_MO_LAN_SSH_CACHE"; do
        [[ -f "$file" ]] || continue
        lineno=0
        while IFS= read -r line; do
            (( lineno++ ))
            [[ "$line" == '#'* || -z "$line" ]] && continue
            if [[ "$line" == *:* ]]; then
                h="${line%%:*}"; p="${line##*:}"
            else
                h="$line"; p="22"
            fi
            if ! _mo_lan_valid_host "$h"; then
                print -P "%F{yellow}[mo-lan-ssh]%f Skipped ${file}:${lineno}: invalid hostname '${h}' (allowed: a-z A-Z 0-9 _ -)" >&2
                continue
            fi
            if ! _mo_lan_valid_port "$p"; then
                print -P "%F{yellow}[mo-lan-ssh]%f Skipped ${file}:${lineno}: invalid port '${p}' for host '${h}' (must be 1–65535)" >&2
                continue
            fi
            [[ -z "${_MO_LAN_HOSTS[$h]:-}" ]] && {
                _MO_LAN_HOSTS[$h]=1
                _MO_LAN_PORTS[$h]="$p"
            }
        done < "$file"
    done
}

# Re-render ~/.ssh/config.d/lan-hosts. Skip if combined (auto+manual) cache
# content hasn't changed since last render. Uses the merged _MO_LAN_PORTS
# map populated by _mo_lan_load_caches.
_mo_lan_maybe_write_sshconf() {
    (( ${#_MO_LAN_HOSTS[@]} == 0 )) && return
    # Combined sha covers both files so manual-only edits still trigger a rewrite.
    local combined_sha last_sha=""
    combined_sha=$( {
        [[ -f "$_MO_LAN_SSH_CACHE" ]] && cat "$_MO_LAN_SSH_CACHE"
        [[ -f "$_MO_LAN_SSH_MANUAL" ]] && cat "$_MO_LAN_SSH_MANUAL"
    } 2>/dev/null | sha256sum | cut -d' ' -f1 )
    [[ -f "$_MO_LAN_SSH_SHA" ]] && last_sha=$(< "$_MO_LAN_SSH_SHA")
    [[ "$combined_sha" == "$last_sha" ]] && return

    command mkdir -p "$_MO_LAN_SSH_USER_CONFIG_DIR"
    chmod 700 "$_MO_LAN_SSH_USER_CONFIG_DIR"

    local tmp="${_MO_LAN_SSH_OUTPUT}.tmp"
    {
        echo "# mo-lan-ssh — autogenerated, do not edit by hand"
        echo "# Source of truth: ${_MO_LAN_SSH_CACHE}"
        [[ -f "$_MO_LAN_SSH_MANUAL" ]] && echo "# Manual overlay: ${_MO_LAN_SSH_MANUAL}"
        echo ""
        local h p
        for h in "${(@kon)_MO_LAN_HOSTS}"; do
            p="${_MO_LAN_PORTS[$h]:-22}"
            echo "Host $h"
            (( p != 22 )) && echo "    Port $p"
            echo ""
        done
    } > "$tmp"
    chmod 600 "$tmp"
    command mv "$tmp" "$_MO_LAN_SSH_OUTPUT"
    print -- "$combined_sha" > "$_MO_LAN_SSH_SHA"
    _mo_lan_log "Wrote ${_MO_LAN_SSH_OUTPUT}"
}

# Validate hostname / port — used by both the file-format reader and the
# CLI `add` subcommand, so the rule lives in one place. The hostname regex
# is intentionally narrow (no dots, no whitespace) because LAN hostnames
# only ever pass through `ssh <host>` shorthand; FQDNs go in ~/.ssh/config
# the normal way.
_mo_lan_valid_host() { [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]] }
_mo_lan_valid_port() { [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 )) }

# Does `$1` already mean something in this shell? Checks every namespace
# zsh resolves a bare word against: external commands on PATH, aliases,
# functions, shell builtins, reserved words (if/for/select/…). Returns
# 0 if any conflict; 1 otherwise.
_mo_lan_name_conflicts() {
    local n="$1"
    (( ${+commands[$n]}  )) && return 0
    (( ${+aliases[$n]}   )) && return 0
    (( ${+functions[$n]} )) && return 0
    (( ${+builtins[$n]}  )) && return 0
    (( ${+reswords[$n]}  )) && return 0
    return 1
}

# Apply the merged cache to the current shell: define <host> aliases (bare
# hostname when no conflict, s-<host> prefix when the name is already taken),
# rebuild the HOSTSET used by the ssh wrapper, feed zsh completion, and
# rewrite the managed ssh-config file. Idempotent — safe to call multiple
# times (subcommands like `add`/`remove`/`forget` re-call to take effect
# in the current shell without requiring a new terminal).
_mo_lan_apply() {
    _mo_lan_load_caches
    (( ${#_MO_LAN_HOSTS[@]} == 0 )) && return

    typeset -gA _MO_LAN_ALIAS_NAMES=()   # hostname → actual alias name in this shell
    local h alias_name
    # 1. Aliases. Prefer the bare hostname for "just type momo" UX. Fall back
    #    to s-<host> when the bare name conflicts with an existing command,
    #    alias, function, builtin, or reserved word — so e.g. a LAN host named
    #    `make` becomes `s-make`.
    for h in "${(@kon)_MO_LAN_HOSTS}"; do
        if _mo_lan_name_conflicts "$h"; then
            alias_name="s-${h}"
        else
            alias_name="$h"
        fi
        alias -- "${alias_name}=ssh ${h}"
        _MO_LAN_ALIAS_NAMES[$h]="$alias_name"
    done

    # 2. Tab completion for ssh/scp/sftp/rsync via zsh's _hosts source.
    zstyle ':completion:*:(ssh|scp|sftp|rsync):*' hosts "${(@k)_MO_LAN_HOSTS}"

    # 3. SSH wrapper — registered only when the wrapper isn't explicitly
    #    disabled. The HOSTSET is the wrapper's "is this target in scope?" gate.
    if [[ "${MO_LAN_AUTO_TRUST:-true}" != "false" ]]; then
        typeset -gA _MO_LAN_HOSTSET=()
        for h in "${(@k)_MO_LAN_HOSTS}"; do _MO_LAN_HOSTSET[$h]=1; done
        # Only (re)define ssh() if it isn't already our wrapper — avoid
        # clobbering a user override.
        if ! (( $+functions[ssh] )) || [[ "$(declare -f ssh)" == *"_mo_lan_ssh_wrapper"* ]]; then
            ssh() { _mo_lan_ssh_wrapper "$@"; }
        fi
    fi

    # 4. ssh-config write — idempotent, skipped when nothing changed.
    _mo_lan_maybe_write_sshconf
}

# ── Loader (runs once at shell startup, no blocking, target <10ms) ────────────

() {
    # First-run case: no cache AND no manual overlay. Kick off background
    # discovery; this shell has no aliases. Per resolved decision (b):
    # never block shell start.
    if [[ ! -f "$_MO_LAN_SSH_CACHE" && ! -f "$_MO_LAN_SSH_MANUAL" ]]; then
        _mo_lan_refresh_async
        return
    fi

    # Background-refresh triggers (don't block this shell either way)
    _mo_lan_check_ttl_async
    _mo_lan_check_network_async

    _mo_lan_apply
}

# ── SSH wrapper (Phase 2) ─────────────────────────────────────────────────────
#
# Wraps the `ssh` command, but only for hosts in the LAN cache. For every
# other target (github.com, work servers, IP literals not in cache) the
# wrapper does ONE associative-array lookup then falls through to
# `command ssh` with zero added latency.
#
# What it does for LAN targets (and only for them):
#   1. Probe with BatchMode=yes — does pubkey auth work in ≤ probe_timeout?
#      - Yes  → just ssh.
#      - "Host key verification failed" / "REMOTE HOST IDENTIFICATION HAS
#         CHANGED" → ssh-keygen -R the host (we trust LAN key changes),
#         then re-probe. If now OK → just ssh.
#      - Permission denied / no working key → ssh-copy-id interactively,
#        then ssh.
#
# Safety gates (any one of these → pass through to bare ssh, no surprise):
#   - The target hostname isn't in _MO_LAN_HOSTSET.
#   - MO_LAN_AUTO_TRUST=false.
#   - Stdin isn't a TTY (script-pipe usage like `cmd | ssh foo ...`).

# Parse ssh argv to find the destination (first non-flag arg, skipping the
# values of option-taking flags). Returns empty string if no target found.
_mo_lan_extract_target() {
    local arg next_is_value=false
    for arg in "$@"; do
        if $next_is_value; then
            next_is_value=false
            continue
        fi
        case "$arg" in
            # Flags taking a separate-arg value (-l user / -p 2222 / -i key / etc.)
            -[BbcDEeFIiJLlmOoPpRSWwQ])
                next_is_value=true
                ;;
            # Flags with attached value (-p2222), or any other -flag (-v, -A, …)
            -*)
                ;;
            # First non-flag arg is the destination
            *)
                print -- "$arg"
                return
                ;;
        esac
    done
}

_mo_lan_ssh_wrapper() {
    # Non-interactive stdin (pipe/script) → exec replaces the wrapper process
    # with the real ssh binary directly (no shell waiting for a child).
    # exec is safe here because stdin is already not a tty — this is a
    # script/pipe context where process replacement is expected behaviour.
    # Interactive pass-throughs below keep command ssh (child process) so
    # exec doesn't close the user's interactive shell on disconnect.
    [[ -t 0 ]] || exec command ssh "$@"

    # MO_LAN_AUTO_TRUST=false → wrapper disabled, pass through
    [[ "${MO_LAN_AUTO_TRUST:-true}" == "false" ]] && { command ssh "$@"; return; }

    local target target_host
    target=$(_mo_lan_extract_target "$@")
    target_host="${target##*@}"   # strip user@ if present

    # Not a LAN host → pass through with zero ceremony
    if [[ -z "$target_host" || -z "${_MO_LAN_HOSTSET[$target_host]:-}" ]]; then
        command ssh "$@"
        return
    fi

    # Probe: BatchMode rejects password auth, so we only succeed on a working
    # key. accept-new auto-records a first-time host key but rejects changes.
    local probe_err probe_rc
    probe_err=$(command ssh -o BatchMode=yes \
                            -o ConnectTimeout="$MO_LAN_PROBE_TIMEOUT" \
                            -o StrictHostKeyChecking=accept-new \
                            "$target" true 2>&1)
    probe_rc=$?

    if (( probe_rc == 0 )); then
        # Key auth works — just ssh.
        command ssh "$@"
        return
    fi

    # Key mismatch? Trust the LAN, purge, re-probe. Stock ssh's normal
    # MITM defense is exactly what we're relaxing here, see README.
    if [[ "$probe_err" == *"REMOTE HOST IDENTIFICATION HAS CHANGED"* \
       || "$probe_err" == *"Host key verification failed"* ]]; then
        print -P "%F{yellow}[mo-lan-ssh]%f Host key changed for $target_host — purging old key (LAN host: trusted)"
        ssh-keygen -R "$target_host" >/dev/null 2>&1
        probe_err=$(command ssh -o BatchMode=yes \
                                -o ConnectTimeout="$MO_LAN_PROBE_TIMEOUT" \
                                -o StrictHostKeyChecking=accept-new \
                                "$target" true 2>&1)
        probe_rc=$?
        if (( probe_rc == 0 )); then
            command ssh "$@"
            return
        fi
    fi

    # Classify the failure. Only run ssh-copy-id when password (or
    # keyboard-interactive) auth is actually offered — copying a key
    # accomplishes nothing if the failure is "connection refused", a
    # KEX mismatch with an ancient device, network unreachable, etc.
    if [[ "$probe_err" == *"Permission denied"* \
       && ( "$probe_err" == *"password"* || "$probe_err" == *"keyboard-interactive"* ) ]]; then
        print -P "%F{cyan}[mo-lan-ssh]%f No working key for $target_host — running ssh-copy-id"
        if command ssh-copy-id "$target" </dev/tty; then
            print -P "%F{green}[mo-lan-ssh]%f Key installed; reconnecting…"
        else
            print -P "%F{yellow}[mo-lan-ssh]%f ssh-copy-id failed — falling through to interactive ssh"
        fi
    elif [[ "$probe_err" == *"Permission denied"* ]]; then
        # Pubkey-only server and our keys aren't authorized. ssh-copy-id
        # has no way to bootstrap. Tell the user the manual path.
        print -P "%F{yellow}[mo-lan-ssh]%f $target_host accepts only pubkey auth; bootstrap manually:" >&2
        print -P "%F{245}  ssh-copy-id -f -i ~/.ssh/<your-key.pub> $target%f" >&2
    fi
    # Network errors / protocol mismatch / etc. — say nothing, just let the
    # real ssh emit the actual error to the user.
    command ssh "$@"
}

# ── CLI dispatcher ────────────────────────────────────────────────────────────

_mo_lan_status() {
    if [[ ! -f "$_MO_LAN_SSH_CACHE" && ! -f "$_MO_LAN_SSH_MANUAL" ]]; then
        print -P "%F{yellow}No cache or manual overlay yet.%f Run: %Bmo-lan-ssh refresh%b"
        return
    fi

    # Auto cache
    print -P "%BAuto cache:%b $_MO_LAN_SSH_CACHE"
    if [[ -f "$_MO_LAN_SSH_CACHE" ]]; then
        local age=$(_mo_lan_cache_age)
        local hours=$(( age / 3600 )) mins=$(( (age % 3600) / 60 ))
        local refreshed=$(grep -m1 '^# Refreshed:' "$_MO_LAN_SSH_CACHE" | sed 's/^# Refreshed: //')
        local auto_count=$(grep -cvE '^(#|$)' "$_MO_LAN_SSH_CACHE")
        local cur_net=$(_mo_lan_network_id) cache_net=$(_mo_lan_cache_network)
        local net_status
        if [[ "$cur_net" == "$cache_net" ]]; then
            net_status="%F{green}✓ stable%f"
        else
            net_status="%F{yellow}✗ changed (will refresh on next shell)%f"
        fi
        print -P "  Age:       ${hours}h ${mins}m"
        print -P "  Refreshed: ${refreshed}"
        print -P "  Hosts:     ${auto_count}"
        print -P "  Network:   ${cache_net} (now: ${cur_net}) — ${net_status}"
    else
        print -P "  %F{245}(not present — will be created on first refresh)%f"
    fi

    # Manual overlay
    print -P "%BManual overlay:%b $_MO_LAN_SSH_MANUAL"
    if [[ -f "$_MO_LAN_SSH_MANUAL" ]]; then
        local manual_count=$(grep -cvE '^(#|$)' "$_MO_LAN_SSH_MANUAL")
        print -P "  Hosts:     ${manual_count}"
    else
        print -P "  %F{245}(none — use 'mo-lan-ssh add <host>[:<port>]' to add)%f"
    fi

    print -P "%BSettings:%b"
    print -P "  TTL:       ${MO_LAN_TTL}s"
    print -P "  Ports:     ${MO_LAN_SSH_PORTS}"
    print -P "  Excludes:  ${MO_LAN_EXCLUDE:-(none)}"
    print -P "  Auto-trust:${MO_LAN_AUTO_TRUST:-true}"

    print -P "%BSSH config:%b"
    if grep -qE '^[[:space:]]*Include[[:space:]]+config\.d/' "$_MO_LAN_SSH_USER_CONFIG" 2>/dev/null; then
        print -P "  %F{green}✓%f ~/.ssh/config has Include line"
    else
        print -P "  %F{yellow}✗%f ~/.ssh/config missing Include — run: %Bmo-lan-ssh setup%b"
    fi
}

_mo_lan_add() {
    local entry="$1"
    [[ -z "$entry" ]] && { echo "Usage: mo-lan-ssh add <host>[:<port>]" >&2; return 1; }

    local h p
    if [[ "$entry" == *:* ]]; then h="${entry%%:*}"; p="${entry##*:}"
    else h="$entry"; p=""; fi

    if ! _mo_lan_valid_host "$h"; then
        echo "mo-lan-ssh: invalid hostname '$h' (allowed: a-z A-Z 0-9 _ -)" >&2
        return 1
    fi
    if [[ -n "$p" ]] && ! _mo_lan_valid_port "$p"; then
        echo "mo-lan-ssh: invalid port '$p' (must be a number 1–65535)" >&2
        return 1
    fi

    command mkdir -p "${_MO_LAN_SSH_MANUAL:h}"
    # Strip any existing entry for this host, then append fresh.
    if [[ -f "$_MO_LAN_SSH_MANUAL" ]]; then
        local tmp="${_MO_LAN_SSH_MANUAL}.tmp"
        grep -vE "^${h}(:.*)?$" "$_MO_LAN_SSH_MANUAL" > "$tmp" 2>/dev/null || true
        command mv "$tmp" "$_MO_LAN_SSH_MANUAL"
    else
        echo "# mo-lan-ssh manual host overlay — edit freely; one host[:port] per line" \
            > "$_MO_LAN_SSH_MANUAL"
        echo "# Manual entries win over auto-discovered ones on hostname collision." \
            >> "$_MO_LAN_SSH_MANUAL"
    fi
    echo "$entry" >> "$_MO_LAN_SSH_MANUAL"

    _mo_lan_apply
    echo "Added: $entry  (alias s-$h now available in this shell)"
}

_mo_lan_remove() {
    local h="$1"
    [[ -z "$h" ]] && { echo "Usage: mo-lan-ssh remove <host>" >&2; return 1; }
    [[ -f "$_MO_LAN_SSH_MANUAL" ]] || { echo "mo-lan-ssh: no manual overlay (nothing to remove)" >&2; return; }

    if ! grep -qE "^${h}(:.*)?$" "$_MO_LAN_SSH_MANUAL" 2>/dev/null; then
        echo "mo-lan-ssh: '$h' is not in the manual overlay" >&2
        echo "  (auto-discovered entries are removed via: mo-lan-ssh forget $h)" >&2
        return 1
    fi
    local tmp="${_MO_LAN_SSH_MANUAL}.tmp"
    grep -vE "^${h}(:.*)?$" "$_MO_LAN_SSH_MANUAL" > "$tmp" 2>/dev/null || true
    command mv "$tmp" "$_MO_LAN_SSH_MANUAL"

    # Unalias only if the host won't reappear via the auto cache.
    # Try both possible alias names — bare and s-prefixed.
    if ! grep -qE "^${h}(:.*)?$" "$_MO_LAN_SSH_CACHE" 2>/dev/null; then
        unalias "${h}" "s-${h}" 2>/dev/null
    fi
    _mo_lan_apply
    echo "Removed: $h from manual overlay"
}

_mo_lan_trust() {
    local target="$1"
    [[ -z "$target" ]] && { echo "Usage: mo-lan-ssh trust <host>" >&2; return 1; }
    command -v ssh-copy-id &>/dev/null || {
        echo "mo-lan-ssh: ssh-copy-id not found (apt install openssh-client)" >&2
        return 1
    }

    # Skip work if a key already authenticates.
    if command ssh -o BatchMode=yes -o ConnectTimeout=3 \
                  -o StrictHostKeyChecking=accept-new \
                  "$target" true 2>/dev/null; then
        echo "Key already works for $target — nothing to do."
        return 0
    fi
    command ssh-copy-id "$target"
}

_mo_lan_forget() {
    local h="$1"
    [[ -z "$h" ]] && { echo "Usage: mo-lan-ssh forget <host>" >&2; return 1; }
    local -a removed=()
    local tmp

    if [[ -f "$_MO_LAN_SSH_CACHE" ]] && grep -qE "^${h}(:.*)?$" "$_MO_LAN_SSH_CACHE" 2>/dev/null; then
        tmp="${_MO_LAN_SSH_CACHE}.tmp"
        grep -vE "^${h}(:.*)?$" "$_MO_LAN_SSH_CACHE" > "$tmp"
        command mv "$tmp" "$_MO_LAN_SSH_CACHE"
        removed+=("auto-cache")
    fi

    if [[ -f "$_MO_LAN_SSH_MANUAL" ]] && grep -qE "^${h}(:.*)?$" "$_MO_LAN_SSH_MANUAL" 2>/dev/null; then
        tmp="${_MO_LAN_SSH_MANUAL}.tmp"
        grep -vE "^${h}(:.*)?$" "$_MO_LAN_SSH_MANUAL" > "$tmp"
        command mv "$tmp" "$_MO_LAN_SSH_MANUAL"
        removed+=("manual-overlay")
    fi

    if ssh-keygen -R "$h" 2>&1 | grep -q "Host found"; then
        removed+=("known_hosts")
    fi

    # Unalias both possible names — we don't track which one was used.
    unalias "${h}" "s-${h}" 2>/dev/null
    _mo_lan_apply

    if (( ${#removed[@]} > 0 )); then
        echo "Forgot $h from: ${(j:, :)removed}"
        echo "  (also rewrote ~/.ssh/config.d/lan-hosts)"
    else
        echo "$h was not known to mo-lan-ssh."
    fi
}

_mo_lan_setup() {
    command mkdir -p "$_MO_LAN_SSH_USER_CONFIG_DIR"
    chmod 700 "$_MO_LAN_SSH_USER_CONFIG_DIR"

    if [[ ! -f "$_MO_LAN_SSH_USER_CONFIG" ]]; then
        touch "$_MO_LAN_SSH_USER_CONFIG"
        chmod 600 "$_MO_LAN_SSH_USER_CONFIG"
        echo "Created ${_MO_LAN_SSH_USER_CONFIG}"
    fi
    if ! grep -qE '^[[:space:]]*Include[[:space:]]+config\.d/' "$_MO_LAN_SSH_USER_CONFIG"; then
        local tmp="${_MO_LAN_SSH_USER_CONFIG}.tmp"
        # Appended (not prepended) so the user's existing Host blocks win
        # ssh_config(5)'s "first match wins" rule on collision with our
        # auto-generated config.d/lan-hosts.
        { cat "$_MO_LAN_SSH_USER_CONFIG"; echo ""; echo "Include config.d/*"; } > "$tmp"
        chmod 600 "$tmp"
        command mv "$tmp" "$_MO_LAN_SSH_USER_CONFIG"
        echo "Added 'Include config.d/*' to ${_MO_LAN_SSH_USER_CONFIG}"
    else
        echo "Include line already in ${_MO_LAN_SSH_USER_CONFIG}"
    fi

    if [[ -f "$HOME/.ssh/id_ed25519" || -f "$HOME/.ssh/id_rsa" || -f "$HOME/.ssh/id_ecdsa" ]]; then
        echo "SSH key present in ~/.ssh/"
    else
        echo "No SSH key found. Run: ssh-keygen -t ed25519"
    fi

    echo "Running first discovery (foreground)..."
    if zsh "$_MO_LAN_SSH_DISCOVER"; then
        _mo_lan_maybe_write_sshconf
        local count
        count=$(grep -cvE '^(#|$)' "$_MO_LAN_SSH_CACHE")
        echo "Setup complete: ${count} hosts discovered. Open a new terminal to see the s-<host> aliases."
    else
        echo "Discovery failed. Check 'mo-lan-ssh status' for details."
        return 1
    fi
}

mo-lan-ssh() {
    local sub="${1:-help}"
    shift 2>/dev/null

    case "$sub" in
        list)
            if [[ ! -f "$_MO_LAN_SSH_CACHE" && ! -f "$_MO_LAN_SSH_MANUAL" ]]; then
                echo "mo-lan-ssh: no cache yet — run: mo-lan-ssh refresh" >&2
                return 1
            fi
            # Read from _MO_LAN_ALIAS_NAMES (populated by the last apply)
            # rather than re-running the conflict check — re-checking would
            # detect our OWN aliases as conflicts and flag every host.
            _mo_lan_load_caches
            local h p src notes alias_name
            for h in "${(@kon)_MO_LAN_HOSTS}"; do
                p="${_MO_LAN_PORTS[$h]:-22}"
                if [[ -f "$_MO_LAN_SSH_MANUAL" ]] && grep -qE "^${h}(:.*)?$" "$_MO_LAN_SSH_MANUAL" 2>/dev/null; then
                    src="manual"
                else
                    src="auto"
                fi
                notes="$src"
                (( p != 22 )) && notes="${notes}, port ${p}"
                alias_name="${_MO_LAN_ALIAS_NAMES[$h]:-$h}"
                [[ "$alias_name" != "$h" ]] && notes="${notes}, aliased as ${alias_name} (name conflicts)"
                printf "%-30s  (%s)\n" "$h" "$notes"
            done
            ;;
        refresh)
            local bg=false
            local arg
            for arg in "$@"; do
                case "$arg" in
                    --background) bg=true ;;
                    -f|--force) : ;;   # currently a no-op (refresh always rebuilds)
                esac
            done
            if $bg; then
                _mo_lan_refresh_async
                echo "Discovery running in background."
                return
            fi
            if zsh "$_MO_LAN_SSH_DISCOVER"; then
                _mo_lan_maybe_write_sshconf
                local count
                count=$(grep -cvE '^(#|$)' "$_MO_LAN_SSH_CACHE")
                echo "Refresh complete: ${count} hosts. Open a new terminal for updated aliases."
            else
                return $?
            fi
            ;;
        status)
            _mo_lan_status
            ;;
        setup)
            _mo_lan_setup
            ;;
        add)
            _mo_lan_add "$@"
            ;;
        remove|rm)
            _mo_lan_remove "$@"
            ;;
        trust)
            _mo_lan_trust "$@"
            ;;
        forget)
            _mo_lan_forget "$@"
            ;;
        help|-h|--help)
            cat <<'EOF'
Usage: mo-lan-ssh <command> [args]

Discovery & state:
  list                    Print all known hosts (auto + manual, one per line, with :port if non-22)
  refresh [-f]            Refresh discovery now (foreground)
  refresh --background    Refresh discovery in background, return immediately
  status                  Show cache age, network ID, host count, SSH config state
  setup                   Bootstrap: ensure ~/.ssh/config has Include line + first refresh

Manual overlay (hosts not found by auto-discovery, e.g. non-standard ports
that aren't in MO_LAN_SSH_PORTS, hosts behind WireGuard, etc.):
  add <host>[:<port>]     Persist a host in the manual overlay; takes effect immediately
  remove <host>           Remove a host from the manual overlay only (alias of: rm)

Key management:
  trust <host>            Run ssh-copy-id <host> if no key works yet (works for non-LAN hosts too)
  forget <host>           Remove host from auto cache, manual overlay, known_hosts, and ssh-config

  help                    Show this message

Env-var configuration (set in ~/.zshrc):
  MO_LAN_TTL              Cache freshness window in seconds (default: 86400)
  MO_LAN_SSH_PORTS        Comma-list of ports to probe (default: 22)
  MO_LAN_PROBE_TIMEOUT    Per-port probe timeout in seconds (default: 2)
  MO_LAN_PROBE_PARALLEL   Concurrent host probes (default: 20)
  MO_LAN_EXCLUDE          Comma-list of hostnames to never alias
  MO_LAN_SUBNET           Override discovery subnet (e.g. 10.0.1.0/24)
  MO_LAN_DNS_SERVER       Override DNS server for AXFR
  MO_LAN_DNS_ZONE         Override DNS zone for AXFR
  MO_LAN_AUTO_TRUST       Set to "false" to disable the ssh wrapper entirely (default: true)
  MO_LAN_VERBOSE          Print [mo-lan-ssh] log lines on background refresh (default: false)
EOF
            ;;
        *)
            echo "mo-lan-ssh: unknown command '$sub' — see 'mo-lan-ssh help'" >&2
            return 1
            ;;
    esac
}
