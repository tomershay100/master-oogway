# Provides: natip (public IP lookup) and sshto (fuzzy SSH host picker).
# Requires: curl for natip. sshto also requires fzf and ~/.ssh/config (or ~/.ssh/config.d/*).

alias natip="curl -s ifconfig.me"

sshto() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: sshto"
        echo "  Fuzzy-select a host from ~/.ssh/config and ~/.ssh/config.d/* and connect."
        return
    fi
    command -v fzf &>/dev/null || { echo "sshto: fzf not installed" >&2; return 1; }
    local -a config_files=( ~/.ssh/config(N) ~/.ssh/config.d/*(N) )
    [[ ${#config_files} -gt 0 ]] || { echo "sshto: no SSH config files found" >&2; return 1; }
    local host
    # Parse all Host names; handle multi-name stanzas (Host alpha beta gamma → three entries).
    # Wildcards and '?' patterns are excluded — they are match rules, not connectable targets.
    host=$(awk '/^Host / && $2 !~ /[*?]/ { for (i=2; i<=NF; i++) print $i }' "${config_files[@]}" \
        | sort -u \
        | fzf --height=40% --reverse --header='Select SSH host')
    [[ -n "$host" ]] && ssh "$host"
}
