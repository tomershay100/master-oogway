# Provides: natip (public IP lookup) and sshto (fuzzy SSH host picker).
# Requires: curl for natip. sshto also requires fzf and ~/.ssh/config (or ~/.ssh/config.d/*).

natip() {
    _mo_require curl natip curl || return
    curl -s --max-time 5 ifconfig.me
}

sshto() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: sshto"
        echo "  Fuzzy-select a host from ~/.ssh/config and ~/.ssh/config.d/* and connect."
        return
    fi
    _mo_require fzf sshto || return
    local -a config_files=( ~/.ssh/config(N) ~/.ssh/config.d/*(N) )
    [[ ${#config_files} -gt 0 ]] || { echo "sshto: no SSH config files found" >&2; return 1; }
    local host
    # Parse all Host names; handle multi-name stanzas (Host alpha beta gamma → three entries).
    # Wildcards and '?' patterns are excluded per-field — they are match rules, not connectable targets.
    # Note: arbitrary `Include` directives inside config files are NOT recursively resolved.
    # If you need full resolution (Include, Match, defaults), use `ssh -G <host>` instead.
    host=$(awk '/^Host / { for (i=2; i<=NF; i++) if ($i !~ /[*?]/) print $i }' "${config_files[@]}" \
        | sort -u \
        | fzf --height=40% --reverse --header='Select SSH host')
    [[ -n "$host" ]] && ssh "$host"
}
