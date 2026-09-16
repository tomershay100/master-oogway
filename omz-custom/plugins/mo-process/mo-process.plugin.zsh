
# oh-my-zsh does not source $ZSH_CUSTOM/lib; nor does a zshrc seeded before it.
[[ -n ${_MO_PLATFORM_LOADED-} ]] || source "${0:h}/../../lib/platform.zsh"

psgrep() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
		echo "Usage: psgrep [-a] <name>"
		echo "  Show running processes whose full command line contains <name>."
		echo "  Case-sensitive by default; -a / --all flips to case-insensitive."
		echo "  (Full-line matching may produce false positives for common substrings.)"
		return
	fi
	command -v pgrep &>/dev/null || { echo "psgrep: pgrep not installed (try: $(_mo_pkg_hint procps))" >&2; return 1; }
	if [[ "$1" == "-a" || "$1" == "--all" ]]; then
		shift
		[[ $# -eq 0 ]] && { echo "psgrep: missing name after -a" >&2; return 1; }
		_mo_pgrep_full -i "$1"
	else
		_mo_pgrep_full "$1"
	fi
}

port() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: port <number>"
		echo "  Show which process is listening on the given TCP/UDP port."
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
	command -v lsof &>/dev/null || { echo "port: lsof not installed (try: $(_mo_pkg_hint lsof))" >&2; return 1; }
	local out
	out=$(lsof -iTCP:"$1" -iUDP:"$1" -sTCP:LISTEN -P -n 2>/dev/null)
	if [[ -z "$out" ]]; then
		echo "port: nothing listening on $1" >&2
		return 1
	fi
	echo "$out" | awk 'NR==1 || !seen[$2]++' \
		| awk 'NR==1 {print "COMMAND","PID","USER","PROTO","ADDRESS","STATE"}
			   NR>1  {proto=(NF>=10)?"TCP":"UDP"; state=(NF>=10)?$10:"-"; print $1,$2,$3,proto,$9,state}' \
		| column -t
}

connected() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: connected [-v]"
		echo "  List machines currently SSH-ed INTO this host (inbound sessions)."
		echo "  -v / --verbose — add TTY, source IP:port, PID and login time."
		return
	fi
	local verbose=false
	[[ "${1:-}" == "-v" || "${1:-}" == "--verbose" ]] && verbose=true

	# _mo_who_sessions normalises `who -u` to TSV, because the two platforms
	# disagree on field count: GNU prints one ISO date token ("2026-09-08
	# 21:38"), BSD prints three ("Sep  8 21:38"), so every column after the
	# username shifted by one on macOS and this printed the wrong values.
	#
	# Remote SSH logins carry a source host; local console/X logins show
	# (:0)/(login screen)/none. Keep only hosts containing a dot — an IP or
	# FQDN, i.e. genuinely remote.
	local rows
	rows=$(_mo_who_sessions | awk -F'\t' '$6 ~ /\./')
	if [[ -z "$rows" ]]; then
		echo "connected: no inbound SSH sessions" >&2
		return 1
	fi

	if [[ "$verbose" == false ]]; then
		echo "$rows" | awk -F'\t' '{ printf "%-12s from %-18s %s\n", $1, $6, $3 }'
		return
	fi

	local user tty login idle pid host peer
	{
		echo "USER TTY FROM PID LOGIN"
		while IFS=$'\t' read -r user tty login idle pid host; do
			# Upgrade the bare source IP to IP:port from the matching socket.
			peer=$(_mo_ssh_peer "$host" 2>/dev/null)
			[[ -n "$peer" ]] && host="$peer"
			echo "$user $tty $host ${pid:--} ${login// /_}"
		done <<< "$rows"
	} | column -t
}

fkill() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: fkill [signal]"
		echo "  Interactively select one or more processes to kill."
		echo "  signal — signal to send (default: -15 SIGTERM); must start with '-'"
		echo "  Examples:"
		echo "    fkill        — send SIGTERM"
		echo "    fkill -9     — send SIGKILL (force)"
		echo "    fkill -KILL  — send SIGKILL by name"
		echo "  Tip: use TAB to select multiple processes."
		return
	fi
	command -v fzf &>/dev/null || { echo "fkill: fzf not installed" >&2; return 1; }
	[[ $# -gt 0 && "${1}" != -* ]] && { echo "fkill: signal must start with '-' (e.g. -9, -KILL)" >&2; return 1; }
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
