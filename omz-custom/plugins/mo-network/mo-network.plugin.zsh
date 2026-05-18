# Provides: natip (public IP lookup) and sshto (fuzzy SSH host picker).
# Requires: curl for natip. sshto also requires fzf and ~/.ssh/config (or ~/.ssh/config.d/*).

natip() {
    command -v curl &>/dev/null || { echo "natip: curl not installed (try: sudo apt install curl)" >&2; return 1; }
    curl -s --max-time 5 ifconfig.me
}

sshto() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        echo "Usage: sshto"
        echo "  Fuzzy-select a host from ~/.ssh/config and ~/.ssh/config.d/* and connect."
        echo "  Include directives are followed recursively."
        return
    fi
    command -v fzf &>/dev/null || { echo "sshto: fzf not installed" >&2; return 1; }

    # Collect SSH config files, following Include directives recursively (BFS).
    # _seen prevents re-processing the same file if included from multiple places.
    # Per ssh_config(5), relative Include paths are relative to ~/.ssh/, not the including file.
    local -a config_files=()
    local -A _seen=()
    local -a _queue=( ~/.ssh/config(N) ~/.ssh/config.d/*(N) )
    local _f _inc
    while (( ${#_queue} > 0 )); do
        _f="${_queue[1]}"; _queue=( "${_queue[@]:1}" )
        [[ -f "$_f" && -z "${_seen[$_f]:-}" ]] || continue
        _seen[$_f]=1
        config_files+=( "$_f" )
        while IFS= read -r _inc; do
            [[ "$_inc" == /* ]] || _inc="${HOME}/.ssh/${_inc}"
            _queue+=( ${~_inc}(N) )
        done < <(awk 'tolower($1)=="include"{$1=""; sub(/^ /,""); print}' "$_f" 2>/dev/null)
    done

    [[ ${#config_files} -gt 0 ]] || { echo "sshto: no SSH config files found" >&2; return 1; }
    local host
    # Parse all Host names; handle multi-name stanzas (Host alpha beta gamma → three entries).
    # Wildcards and '?' patterns are excluded — they are match rules, not connectable targets.
    host=$(awk '/^Host / { for (i=2; i<=NF; i++) if ($i !~ /[*?]/) print $i }' "${config_files[@]}" \
        | sort -u \
        | fzf --height=40% --reverse --header='Select SSH host')
    [[ -n "$host" ]] && ssh "$host"
}
