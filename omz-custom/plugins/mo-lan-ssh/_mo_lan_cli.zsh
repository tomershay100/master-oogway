# _mo_lan_cli.zsh — CLI subcommand implementations and dispatcher

_mo_lan_status() {
    if [[ ! -f "$_MO_LAN_SSH_CACHE" && ! -f "$_MO_LAN_SSH_MANUAL" ]]; then
        print -P "%F{yellow}No cache or manual overlay yet.%f Run: %Bmo-lan-ssh refresh%b"
        return
    fi

    # Auto cache
    print -P "%BAuto cache:%b $_MO_LAN_SSH_CACHE"
    if [[ -f "$_MO_LAN_SSH_CACHE" ]]; then
        local age hours mins refreshed auto_count cur_net cache_net net_status
        age=$(_mo_lan_cache_age)
        hours=$(( age / 3600 ))
        mins=$(( (age % 3600) / 60 ))
        refreshed=$(grep -m1 '^# Refreshed:' "$_MO_LAN_SSH_CACHE" | sed 's/^# Refreshed: //')
        auto_count=$(grep -cvE '^(#|$)' "$_MO_LAN_SSH_CACHE")
        cur_net=$(_mo_lan_network_id)
        cache_net=$(_mo_lan_cache_network)
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
        local manual_count
        manual_count=$(grep -cvE '^(#|$)' "$_MO_LAN_SSH_MANUAL")
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
    local alias_name="${_MO_LAN_ALIAS_NAMES[$h]:-$h}"
    echo "Added: $entry  (alias ${alias_name} now available in this shell)"
}

_mo_lan_remove() {
    local h="$1"
    [[ -z "$h" ]] && { echo "Usage: mo-lan-ssh remove <host>" >&2; return 1; }
    _mo_lan_valid_host "$h" || { echo "mo-lan-ssh: invalid hostname '$h'" >&2; return 1; }
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
    _mo_lan_valid_host "$h" || { echo "mo-lan-ssh: invalid hostname '$h'" >&2; return 1; }
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

    local keygen_out
    keygen_out=$(command ssh-keygen -R "$h" 2>&1)
    [[ "$keygen_out" == *"Host found"* ]] && removed+=("known_hosts")

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
        _mo_lan_load_caches
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
