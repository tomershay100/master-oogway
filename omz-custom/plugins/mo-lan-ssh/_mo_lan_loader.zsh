# _mo_lan_loader.zsh — paths, defaults, startup helpers, apply, shell loader

# EPOCHSECONDS lives in zsh/datetime; load once so loader paths don't fork date.
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
    subnet=$(ip -o -f inet addr show "$iface" 2>/dev/null | awk 'NR==1 { print $4 }')
    print -- "${gw}-${subnet}" | md5sum | awk '{ print substr($1,1,8) }'
}

_mo_lan_cache_age() {
    local mtime
    mtime=$(stat -c %Y "$_MO_LAN_SSH_CACHE" 2>/dev/null) || { echo 999999999; return; }
    echo $(( EPOCHSECONDS - mtime ))
}

_mo_lan_cache_network() {
    [[ -f "$_MO_LAN_SSH_CACHE" ]] || return 1
    awk '/^# Refreshed:/ { match($0, /network=([a-f0-9]+)/, m); if (m[1]) { print m[1]; exit } }' \
        "$_MO_LAN_SSH_CACHE" 2>/dev/null
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

# ── SSH wrapper ───────────────────────────────────────────────────────────────

source "${_MO_LAN_SSH_DIR}/_mo_lan_trust.zsh"

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
