# Provides: natip (public IP lookup) and sshto (fuzzy SSH host picker).
# Requires: curl for natip. sshto also requires fzf and a populated ~/.ssh/config.

alias natip="curl -s ifconfig.me"

sshto() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: sshto"
        echo "  Fuzzy-select a host from ~/.ssh/config and connect to it."
        return
    fi
    command -v fzf &>/dev/null || { echo "sshto: fzf not installed" >&2; return 1; }
    [[ -s "$HOME/.ssh/config" ]] || { echo "sshto: ~/.ssh/config is empty or missing" >&2; return 1; }
    local host
    host=$(awk '/^Host [^*]/{host=$2} /^[ \t]*(HostName|Port)/{val=$2; print host"\t"val}' ~/.ssh/config 2>/dev/null \
        | awk '!seen[$1]++' \
        | fzf --height=40% --reverse --header='Select SSH host' \
              --with-nth=1 --delimiter='\t' \
        | awk '{print $1}')
    [[ -n "$host" ]] && ssh "$host"
}
