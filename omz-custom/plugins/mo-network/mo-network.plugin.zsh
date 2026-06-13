
natip() {
	command -v curl &>/dev/null || { echo "natip: curl not installed (try: sudo apt install curl)" >&2; return 1; }
	curl -s --max-time 5 ifconfig.me
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

	# Collect SSH config files, following Include directives recursively (BFS).
	# _seen prevents re-processing the same file if included from multiple places.
	# Per ssh_config(5), relative Include paths are relative to ~/.ssh/, not the including file.
	# Depth cap of 16 guards against misconfigured recursive includes that _seen
	# alone can't catch (e.g. a chain of 100 distinct files).
	local -a config_files=()
	local -A _seen=()
	local -a _queue=( ~/.ssh/config(N) ~/.ssh/config.d/*(N) )
	local _f _inc _depth=0
	while (( ${#_queue} > 0 && _depth < 16 )); do
		_f="${_queue[1]}"; _queue=( "${_queue[@]:1}" )
		[[ -f "$_f" && -z "${_seen[$_f]:-}" ]] || continue
		_seen[$_f]=1
		(( _depth++ ))
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
