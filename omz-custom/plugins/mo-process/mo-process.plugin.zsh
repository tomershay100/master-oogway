# Provides: psgrep (search processes), port (what's on a port), fkill (fuzzy kill).
# Requires: fkill also requires fzf (skipped with an error if not installed).

function psgrep() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
        echo "Usage: psgrep <name>"
        echo "  Show running processes matching <name> (case-insensitive, full command line)."
        return
    fi
    command -v pgrep &>/dev/null || { echo "psgrep: pgrep not installed (try: sudo apt install procps)" >&2; return 1; }
    pgrep -lif "$1"
}

function port() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        echo "Usage: port <number>"
        echo "  Show which process is listening on the given TCP/UDP port."
        echo "  Falls back to sudo if the port is not visible without elevated permissions."
        echo "  Note: UDP sockets are shown without state filtering (UDP is connectionless)."
        return
    fi
    if [[ $# -eq 0 ]]; then
        echo "Usage: port <number>  (use -h for details)" >&2
        return 1
    fi
    if [[ ! "$1" =~ ^[0-9]+$ ]] || (( $1 < 1 || $1 > 65535 )); then
        echo "port: invalid port '$1' (must be 1–65535)" >&2
        return 1
    fi
    command -v lsof &>/dev/null || { echo "port: lsof not installed (try: sudo apt install lsof)" >&2; return 1; }
    local out lsof_rc
    out=$(lsof -iTCP:"$1" -iUDP:"$1" -sTCP:LISTEN -P -n 2>/dev/null); lsof_rc=$?
    if [[ -z "$out" && $lsof_rc -ne 0 ]]; then
        # Listener owned by another user — surface the elevation explicitly
        # so the sudo password prompt isn't a surprise.
        echo "port: nothing visible without root, retrying with sudo..." >&2
        out=$(sudo lsof -iTCP:"$1" -iUDP:"$1" -sTCP:LISTEN -P -n 2>/dev/null)
    fi
    if [[ -z "$out" ]]; then
        echo "port: nothing listening on $1" >&2
        return 1
    fi
    echo "$out" | awk 'NR==1 || !seen[$2]++' \
        | awk 'NR==1 {print "COMMAND","PID","USER","PROTO","ADDRESS","STATE"}
               NR>1  {print $1,$2,$3,$5,$9,$10}' \
        | column -t
}

fkill() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
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
