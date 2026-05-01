# Provides: psgrep (search processes), port (what's on a port), fkill (fuzzy kill).
# Requires: fkill also requires fzf (skipped with an error if not installed).

function psgrep() {
    if [[ "$1" == "-h" || "$1" == "--help" || $# -eq 0 ]]; then
        echo "Usage: psgrep <name>"
        echo "  Show running processes matching <name> (case-insensitive)."
        return
    fi
    ps aux | grep -v grep | grep -i "$1"
}

function port() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: port <number>"
        echo "  Show which process is listening on the given TCP/UDP port."
        echo "  Falls back to sudo if the port is not visible without elevated permissions."
        return
    fi
    if [[ $# -eq 0 ]]; then
        echo "Usage: port <number>  (use -h for details)" >&2
        return 1
    fi
    local out
    out=$(lsof -iTCP:"$1" -iUDP:"$1" -sTCP:LISTEN -P -n 2>/dev/null)
    if [[ -z "$out" ]]; then
        out=$(sudo lsof -iTCP:"$1" -iUDP:"$1" -sTCP:LISTEN -P -n 2>/dev/null)
    fi
    if [[ -z "$out" ]]; then
        echo "port: nothing listening on $1" >&2
        return 1
    fi
    echo "$out" | awk 'NR==1 || !seen[$2]++' | awk '{printf "%-15s %-7s %-12s %-6s %s\n", $1, $2, $3, $5, $9}'
}

fkill() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: fkill [signal]"
        echo "  Interactively select one or more processes to kill."
        echo "  signal — signal to send (default: -15 SIGTERM)"
        echo "  Examples:"
        echo "    fkill        — send SIGTERM"
        echo "    fkill -9     — send SIGKILL (force)"
        echo "  Tip: use TAB to select multiple processes."
        return
    fi
    command -v fzf &>/dev/null || { echo "fkill: fzf not installed" >&2; return 1; }
    local sig="${1:--15}"
    local pids
    pids=$(ps -ef \
        | sed 1d \
        | fzf -m --height=40% --reverse --header='Select process(es) to kill  [TAB = multi-select]' \
        | awk '{print $2}')
    [[ -z "$pids" ]] && return
    while IFS= read -r pid; do
        kill -0 "$pid" 2>/dev/null || { echo "fkill: process $pid no longer exists" >&2; continue; }
        kill "$sig" "$pid"
    done <<< "$pids"
}
