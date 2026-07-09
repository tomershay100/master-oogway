
natip() {
	command -v curl &>/dev/null || { echo "natip: curl not installed (try: sudo apt install curl)" >&2; return 1; }
	local ip
	ip=$(curl -s --max-time 5 ifconfig.me)
	if [[ -z "$ip" ]]; then
		echo "natip: lookup failed (timeout or no connectivity)" >&2
		echo "(unknown)"
		return 1
	fi
	echo "$ip"
}

serve() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: serve [port]"
		echo "  Start an HTTP server in the current directory."
		echo "  port — port to listen on (default: 8000)"
		echo ""
		echo "  Binds to 127.0.0.1 by default (localhost only)."
		echo "  Set SERVE_BIND=0.0.0.0 to expose to the local network."
		return
	fi
	command -v python3 &>/dev/null || { echo "serve: python3 not installed" >&2; return 1; }
	local port="${1:-8000}"
	local bind="${SERVE_BIND:-127.0.0.1}"
	echo "Serving $(pwd) on http://${bind}:${port}"
	[[ "$bind" != "127.0.0.1" ]] && echo "  WARNING: exposed to all network interfaces on ${bind}"
	python3 -m http.server "$port" --bind "$bind"
}

sshto() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: sshto"
		echo "  Fuzzy-select a host from ~/.ssh/config and ~/.ssh/config.d/* and connect."
		echo "  Include directives are followed recursively."
		return
	fi
	command -v fzf &>/dev/null || { echo "sshto: fzf not installed" >&2; return 1; }

	local -a config_files=()
	local -A _seen=()
	local -a _queue=( ~/.ssh/config(N) ~/.ssh/config.d/*(N) )
	local _f _inc _count=0
	while (( ${#_queue} > 0 && _count < 256 )); do
		_f="${_queue[1]}"; _queue=( "${_queue[@]:1}" )
		[[ -f "$_f" && -z "${_seen[$_f]:-}" ]] || continue
		_seen[$_f]=1
		(( _count++ ))
		config_files+=( "$_f" )
		while IFS= read -r _inc; do
			# Each token on an Include line is a separate pattern; split on whitespace.
			local -a _pats=( ${=_inc} )
			local _pat
			for _pat in "${_pats[@]}"; do
				# Tilde prefix expands before the ~/.ssh/ relative fallback.
				if [[ "$_pat" == ~* ]]; then
					_pat="${HOME}${_pat[2,-1]}"
				elif [[ "$_pat" != /* ]]; then
					_pat="${HOME}/.ssh/${_pat}"
				fi
				_queue+=( ${~_pat}(N) )
			done
		done < <(awk 'tolower($1)=="include"{$1=""; sub(/^ /,""); print}' "$_f" 2>/dev/null)
	done

	[[ ${#config_files} -gt 0 ]] || { echo "sshto: no SSH config files found" >&2; return 1; }
	local host
	# Parse all Host names; handle multi-name stanzas (Host alpha beta gamma → three entries).
	# Wildcards and '?' patterns are excluded — they are match rules, not connectable targets.
	host=$(awk 'tolower($1)=="host" { for (i=2; i<=NF; i++) if ($i !~ /[*?!]/) print $i }' "${config_files[@]}" \
		| sort -u \
		| fzf --height=40% --reverse --header='Select SSH host')
	[[ -n "$host" ]] && ssh "$host"
}
