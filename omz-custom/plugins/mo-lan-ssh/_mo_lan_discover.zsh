#!/usr/bin/env zsh
# ------------------------------------------------------------------------------
# _mo_lan_discover.zsh — find LAN SSH hosts and write the cache
#
# Invoked by the mo-lan-ssh plugin via `zsh _mo_lan_discover.zsh` either:
#   - in the background on shell start (cache stale / missing / network changed)
#   - in the foreground via `mo-lan-ssh refresh`
#
# Reads env vars for tuning; see plugin file for defaults.
# Writes atomically to ~/.config/master-oogway/lan-hosts.
# ------------------------------------------------------------------------------
emulate -L zsh
setopt err_return no_unset pipe_fail

CACHE="${HOME}/.config/master-oogway/lan-hosts"
PORTS="${MO_LAN_SSH_PORTS:-22}"
PROBE_TIMEOUT="${MO_LAN_PROBE_TIMEOUT:-2}"
PROBE_PARALLEL="${MO_LAN_PROBE_PARALLEL:-20}"
EXCLUDE="${MO_LAN_EXCLUDE:-}"
TTL="${MO_LAN_TTL:-86400}"

command mkdir -p "${CACHE:h}"

# ── Network fingerprint (used to detect "laptop moved between LANs") ──────────

network_id() {
    local gw iface subnet
    gw=$(ip route show default 2>/dev/null | awk '/default/ { print $3; exit }')
    iface=$(ip route show default 2>/dev/null | awk '/default/ { print $5; exit }')
    [[ -z "$iface" ]] && { echo "unknown"; return; }
    subnet=$(ip -o -f inet addr show "$iface" 2>/dev/null | awk '{ print $4 }')
    print -- "${gw}-${subnet}" | md5sum | cut -d' ' -f1 | cut -c1-8
}

local_hostname() { hostname -s 2>/dev/null || hostname; }

local_subnet() {
    [[ -n "${MO_LAN_SUBNET:-}" ]] && { echo "$MO_LAN_SUBNET"; return; }
    local iface
    iface=$(ip route show default 2>/dev/null | awk '/default/ { print $5; exit }')
    [[ -z "$iface" ]] && return 1
    ip -o -f inet addr show "$iface" 2>/dev/null | awk '{ print $4 }' | head -1
}

dns_server() {
    [[ -n "${MO_LAN_DNS_SERVER:-}" ]] && { echo "$MO_LAN_DNS_SERVER"; return; }
    awk '/^nameserver/ { print $2; exit }' /etc/resolv.conf 2>/dev/null
}

dns_zone() {
    [[ -n "${MO_LAN_DNS_ZONE:-}" ]] && { echo "$MO_LAN_DNS_ZONE"; return; }
    awk '/^search/ { print $2; exit }' /etc/resolv.conf 2>/dev/null
}

# ── Stage 1: enumerate candidate hostnames (4-strategy fallback) ──────────────

strat_axfr() {
    local srv zone
    srv=$(dns_server); zone=$(dns_zone)
    [[ -z "$srv" || -z "$zone" ]] && return 1
    command -v dig &>/dev/null || return 1
    local out
    out=$(dig "@$srv" "$zone" AXFR +short +noall +answer +time=2 +tries=1 2>/dev/null) || return 1
    [[ -z "$out" ]] && return 1
    # Refused / failed transfers come back with "Transfer failed" or "communications error"
    [[ "$out" == *"failed"* || "$out" == *"refused"* || "$out" == *"error"* ]] && return 1
    # Extract first label of A-record names (drop SOA/NS/etc., drop FQDN suffix)
    echo "$out" | awk '$4 == "A" || $4 == "AAAA" { sub(/\.$/, "", $1); print $1 }' \
        | awk -F. '{ print $1 }' | sort -u
}

strat_nmap() {
    command -v nmap &>/dev/null || return 1
    local subnet
    subnet=$(local_subnet) || return 1
    [[ -z "$subnet" ]] && return 1
    local ips
    ips=$(nmap -sn -n -PR "$subnet" -oG - 2>/dev/null | awk '/Up$/ { print $2 }') || return 1
    [[ -z "$ips" ]] && return 1
    # Reverse-DNS each IP, take first label, drop nulls
    echo "$ips" | while read -r ip; do
        dig +short -x "$ip" +time=1 +tries=1 2>/dev/null | sed 's/\.$//' | head -1
    done | awk -F. 'NF { print $1 }' | sort -u
}

strat_arp_scan() {
    command -v arp-scan &>/dev/null || return 1
    # Only attempt if passwordless sudo is configured for arp-scan — never prompt.
    local ips
    ips=$(sudo -n arp-scan --localnet -q 2>/dev/null | awk '/^[0-9]/ { print $1 }') || return 1
    [[ -z "$ips" ]] && return 1
    echo "$ips" | while read -r ip; do
        dig +short -x "$ip" +time=1 +tries=1 2>/dev/null | sed 's/\.$//' | head -1
    done | awk -F. 'NF { print $1 }' | sort -u
}

strat_known_hosts() {
    [[ -f "$HOME/.ssh/known_hosts" ]] || return 1
    # Skip hashed entries (start with |1|). Take the first field, split on
    # comma (multi-host lines), strip [host]:port wrapping, drop IPs.
    awk '!/^\|/ { print $1 }' "$HOME/.ssh/known_hosts" 2>/dev/null \
        | tr ',' '\n' \
        | sed 's/^\[//; s/\]:[0-9]*$//' \
        | grep -v '^[0-9]\+\.' \
        | awk -F. 'NF { print $1 }' | sort -u
}

# ── Filter — drop unsafe names, the local host, and user-excluded names ───────

filter_names() {
    local me
    me=$(local_hostname)
    local -a excludes=()
    [[ -n "$EXCLUDE" ]] && excludes=(${(s:,:)EXCLUDE})
    local name skip e
    while read -r name; do
        [[ -z "$name" || "$name" == "$me" ]] && continue
        [[ "$name" == *.* ]] && continue
        [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || continue
        skip=false
        for e in "${excludes[@]}"; do
            [[ "$name" == "$e" ]] && { skip=true; break; }
        done
        $skip && continue
        echo "$name"
    done
}

# ── Stage 2: confirm each candidate has an SSH listener on one of the ports ──

probe_host() {
    local host="$1" p
    for p in ${(s:,:)PORTS}; do
        if timeout "$PROBE_TIMEOUT" bash -c "</dev/tcp/$host/$p" 2>/dev/null; then
            (( p == 22 )) && echo "$host" || echo "$host:$p"
            return
        fi
    done
}

probe_all() {
    local -a names=()
    local n
    while read -r n; do names+=("$n"); done
    local i=0 batch_size="$PROBE_PARALLEL"
    local -a batch=()
    local h
    for n in "${names[@]}"; do
        batch+=("$n")
        if (( ${#batch[@]} >= batch_size )); then
            for h in "${batch[@]}"; do probe_host "$h" & done
            wait
            batch=()
        fi
    done
    for h in "${batch[@]}"; do probe_host "$h" & done
    wait
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    if ! command -v dig &>/dev/null && ! command -v nmap &>/dev/null; then
        echo "mo-lan-ssh: no dig or nmap — active discovery unavailable (install: sudo apt install nmap)" >&2
    fi
    local raw_names="" strategy="" strat
    for strat in strat_axfr strat_nmap strat_arp_scan strat_known_hosts; do
        raw_names=$("$strat" 2>/dev/null) || true
        if [[ -n "$raw_names" ]]; then
            strategy="${strat#strat_}"
            break
        fi
    done

    if [[ -z "$raw_names" ]]; then
        echo "mo-lan-ssh: all discovery strategies returned empty" >&2
        return 1
    fi

    local filtered
    filtered=$(echo "$raw_names" | filter_names)
    if [[ -z "$filtered" ]]; then
        echo "mo-lan-ssh: no valid hostnames after filtering" >&2
        return 1
    fi

    local probed
    probed=$(echo "$filtered" | probe_all | sort -u)
    if [[ -z "$probed" ]]; then
        echo "mo-lan-ssh: no hosts answered on ports ${PORTS}" >&2
        return 1
    fi

    # Atomic write
    local net now tmp
    net=$(network_id)
    now=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
    tmp="${CACHE}.tmp"
    {
        echo "# mo-lan-ssh cache — autogenerated, do not edit by hand"
        echo "# Refreshed: ${now} via ${strategy} (network=${net})"
        echo "# TTL: ${TTL}s"
        echo "${probed}"
    } > "$tmp"
    command mv "$tmp" "$CACHE"
}

main "$@"
