
source "${0:h}/requirements.zsh" || return

# -- tunnel — SSH port-forward with a readable syntax --------------------------
#
# Syntax:  tunnel <left> to <right>
#
# Each side is  [host:]port  where host defaults to localhost.
# The remote host (if any) determines the SSH target and the direction:
#
#   local:port   to  remote:port  →  -L  (connect locally, packets exit on remote)
#   remote:port  to  local:port   →  -R  (connect on remote, packets exit locally)
#   port         to  port         →  -L  localhost to localhost (loopback)

# -- PID tracking — background tunnels register a file under tunnels/ ----------
# Layout: ${XDG_CONFIG_HOME:-~/.config}/master-oogway/tunnels/<key>.pid
# Key is <local_port>_<remote_host>_<remote_port> so it is stable + readable.
# Dir is created lazily (only when a bg tunnel starts or list/kill runs) to
# keep shell startup free of any filesystem work.

_tunnel_dir() {
	local dir="${XDG_CONFIG_HOME:-$HOME/.config}/master-oogway/tunnels"
	[[ -d "$dir" ]] || mkdir -p "$dir"
	print -r -- "$dir"
}

_tunnel_key() {
	# args: <local_port> <remote_host> <remote_port>
	local key="${1}_${2}_${3}"
	print -r -- "${key//[^A-Za-z0-9._-]/-}"
}

# Find the PID of the freshly-forked `ssh -f` listener on a local port.
# ssh -f detaches without printing its PID, so we poll the local listener.
_tunnel_find_pid() {
	local port="$1" pid="" _attempt
	for _attempt in 1 2 3 4 5 6; do
		if command -v lsof &>/dev/null; then
			pid="$(lsof -ti "tcp:${port}" -sTCP:LISTEN 2>/dev/null | head -n1)"
		elif command -v ss &>/dev/null; then
			pid="$(ss -tlnpH "sport = :${port}" 2>/dev/null \
				| grep -oE 'pid=[0-9]+' | head -n1 | cut -d= -f2)"
		else
			return 1
		fi
		[[ -n "$pid" ]] && { print -r -- "$pid"; return 0; }
		sleep 0.5
	done
	return 1
}

tunnel() {
	# -- subcommand dispatch: list / kill route to their handlers -----------------
	case "${1:-}" in
		list)  shift; _tunnel_list "$@"; return $? ;;
		kill)  shift; _tunnel_kill "$@"; return $? ;;
	esac

	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
		cat <<'EOF'
Usage: tunnel [-b] [[user@]host:]<port> to [[user@]host:]<port>
       tunnel list                    list running background tunnels
       tunnel kill <local_port>       stop a background tunnel by local port
       tunnel kill --all              stop all tracked background tunnels

  Each side is [user@host:]port — host defaults to localhost.
  user@ is accepted on the remote side and passed to ssh as the login.
  Direction is inferred from which side has the remote host:

  local:port   to  remote:port   connect to local port, packets exit on remote
								 (ssh -L — opens a local port that reaches the remote service)

  remote:port  to  local:port    connect on remote, packets exit locally
								 (ssh -R — opens a port on the remote that reaches your service)

  port         to  port          loopback — both sides are local

  -b, --background               run tunnel in the background (ssh -f)

Examples:
  tunnel 5432 to db.internal:5432       # local :5432 → postgres on db.internal
  tunnel -b 8080 to momo:3000           # background: local :8080 → momo's dev server
  tunnel root@192.168.1.2:9090 to 9090  # momo's :9090 → your local :9090 (reverse)
  tunnel 9000 to 9001                   # loopback: :9000 exits at local :9001
  tunnel 0.0.0.0:80 to momo:8080       # bind all interfaces locally on :80 → momo:8080
  tunnel momo:80 to 0.0.0.0:8080       # expose momo:80 on all remote interfaces (requires GatewayPorts yes in sshd)
EOF
		return
	fi

	# Optional -b/--background flag before the spec
	local bg=0
	if [[ "${1:-}" == "-b" || "${1:-}" == "--background" ]]; then
		bg=1; shift
	fi

	# Expect exactly:  <left_spec> to <right_spec>
	if [[ $# -ne 3 || "$2" != "to" ]]; then
		echo "tunnel: syntax error — expected: tunnel [-b] <left> to <right>" >&2
		echo "  Run: tunnel --help" >&2
		return 1
	fi

	local left_raw="$1"
	local right_raw="$3"

	# ── Parse [user@host:]port — sets _TUNNEL_HOST, _TUNNEL_PORT, _TUNNEL_LOGIN ──
	# _TUNNEL_LOGIN = full "user@host" or just "host" (passed to ssh as target)
	# _TUNNEL_HOST  = bare hostname (used for locality check and bind address)
	_tunnel_parse() {
		local raw="$1"
		_TUNNEL_LOGIN="" _TUNNEL_HOST="" _TUNNEL_PORT=""
		if [[ "$raw" =~ ^(([^@:]+)@)?([^:@]+):([0-9]+)$ ]]; then
			local user="${match[2]}" host="${match[3]}" port="${match[4]}"
			_TUNNEL_HOST="$host"
			_TUNNEL_PORT="$port"
			_TUNNEL_LOGIN="${user:+${user}@}${host}"
		elif [[ "$raw" =~ ^([0-9]+)$ ]]; then
			_TUNNEL_HOST="localhost"
			_TUNNEL_PORT="${match[1]}"
			_TUNNEL_LOGIN="localhost"
		else
			echo "tunnel: invalid side '${raw}' — expected [[user@]host:]port" >&2
			return 1
		fi
	}

	local _TUNNEL_HOST _TUNNEL_PORT _TUNNEL_LOGIN

	_tunnel_parse "$left_raw"  || return 1
	local left_host="$_TUNNEL_HOST" left_port="$_TUNNEL_PORT" left_login="$_TUNNEL_LOGIN"

	_tunnel_parse "$right_raw" || return 1
	local right_host="$_TUNNEL_HOST" right_port="$_TUNNEL_PORT" right_login="$_TUNNEL_LOGIN"

	unfunction _tunnel_parse 2>/dev/null

	local left_is_local right_is_local
	[[ "$left_host"  == "localhost" || "$left_host"  == "127.0.0.1" || "$left_host"  == "0.0.0.0" ]] \
		&& left_is_local=1  || left_is_local=0
	[[ "$right_host" == "localhost" || "$right_host" == "127.0.0.1" || "$right_host" == "0.0.0.0" ]] \
		&& right_is_local=1 || right_is_local=0

	local ssh_login flag bind_addr local_port remote_host remote_port

	if (( left_is_local && right_is_local )); then
		flag="-L"
		ssh_login="localhost"
		bind_addr="${left_host}"
		local_port="${left_port}"
		remote_host="localhost"
		remote_port="${right_port}"
		echo "tunnel: loopback  -L ${bind_addr}:${local_port}:${remote_host}:${remote_port}"

	elif (( left_is_local && !right_is_local )); then
		flag="-L"
		ssh_login="${right_login}"
		bind_addr="${left_host}"
		local_port="${left_port}"
		remote_host="localhost"
		remote_port="${right_port}"
		echo "tunnel: -L ${bind_addr}:${local_port}:${remote_host}:${remote_port}  via ${ssh_login}"

	elif (( !left_is_local && right_is_local )); then
		flag="-R"
		ssh_login="${left_login}"
		bind_addr="${right_host}"
		local_port="${right_port}"
		remote_host="localhost"
		remote_port="${left_port}"
		echo "tunnel: -R ${remote_port}:${remote_host}:${local_port}  via ${ssh_login}"

	else
		echo "tunnel: both sides are remote hosts — cannot determine SSH direction" >&2
		echo "  One side must be localhost / 127.0.0.1 / 0.0.0.0 / a bare port number." >&2
		return 1
	fi

	local -a ssh_opts=( -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=15 )
	(( bg )) && ssh_opts+=( -f )

	if [[ "$flag" == "-L" ]]; then
		ssh "${ssh_opts[@]}" "$flag" "${bind_addr}:${local_port}:${remote_host}:${remote_port}" "$ssh_login" || return
	else
		ssh "${ssh_opts[@]}" "$flag" "${remote_port}:${remote_host}:${local_port}" "$ssh_login" || return
	fi

	# A background tunnel forked and detached; record its PID so `tunnel list`
	# and `tunnel kill` can manage it later. Foreground tunnels don't return
	# until closed, so there is nothing to track.
	(( bg )) || return 0
	_tunnel_register "$local_port" "$remote_host" "$remote_port" "$flag" "$ssh_login"
}

# -- _tunnel_register — write the PID file for a background tunnel -------------
_tunnel_register() {
	local local_port="$1" remote_host="$2" remote_port="$3" flag="$4" ssh_login="$5"
	local pid
	if ! pid="$(_tunnel_find_pid "$local_port")"; then
		echo "tunnel: started, but could not find its PID to track (need lsof or ss)" >&2
		echo "  the tunnel is running; it just won't appear in 'tunnel list'." >&2
		return 0
	fi
	local dir key
	dir="$(_tunnel_dir)"
	key="$(_tunnel_key "$local_port" "$remote_host" "$remote_port")"
	printf '%s\t%s\t%s\t%s\t%s\n' \
		"$pid" "$local_port" "${flag}:${remote_host}:${remote_port}" "$ssh_login" "$(date +%s)" \
		> "${dir}/${key}.pid"
	echo "tunnel: tracking pid ${pid} (local :${local_port}) — 'tunnel list' / 'tunnel kill ${local_port}'"
}

# -- _tunnel_list — show tracked tunnels, prune dead ones ---------------------
_tunnel_list() {
	local dir
	dir="$(_tunnel_dir)"
	local -a files=( "${dir}"/*.pid(N) )
	if (( ! ${#files} )); then
		echo "tunnel: no background tunnels tracked"
		return 0
	fi

	printf '%-8s  %-10s  %-28s  %-18s  %s\n' "PID" "LOCAL" "FORWARD" "VIA" "STATUS"
	local f pid local_port forward via state
	for f in "${files[@]}"; do
		IFS=$'\t' read -r pid local_port forward via _ < "$f"
		if kill -0 "$pid" 2>/dev/null; then
			state="alive"
		else
			state="dead (pruned)"
			rm -f -- "$f"
		fi
		printf '%-8s  %-10s  %-28s  %-18s  %s\n' \
			"$pid" ":${local_port}" "$forward" "$via" "$state"
	done
}

# -- _tunnel_kill — SIGTERM a tracked tunnel by local port (or --all) ---------
_tunnel_kill() {
	local dir
	dir="$(_tunnel_dir)"

	if [[ -z "${1:-}" ]]; then
		echo "Usage: tunnel kill <local_port>" >&2
		echo "       tunnel kill --all" >&2
		return 1
	fi

	local -a files=( "${dir}"/*.pid(N) )
	if (( ! ${#files} )); then
		echo "tunnel: no background tunnels tracked"
		return 0
	fi

	local f pid local_port _rest killed=0
	if [[ "$1" == "--all" || "$1" == "-a" ]]; then
		for f in "${files[@]}"; do
			IFS=$'\t' read -r pid local_port _rest < "$f"
			kill "$pid" 2>/dev/null && echo "tunnel: killed pid ${pid} (local :${local_port})"
			rm -f -- "$f"
			(( killed++ ))
		done
		echo "tunnel: stopped ${killed} tunnel(s)"
		return 0
	fi

	local target="$1"
	for f in "${files[@]}"; do
		IFS=$'\t' read -r pid local_port _rest < "$f"
		if [[ "$local_port" == "$target" ]]; then
			kill "$pid" 2>/dev/null && echo "tunnel: killed pid ${pid} (local :${local_port})"
			rm -f -- "$f"
			(( killed++ ))
		fi
	done

	if (( ! killed )); then
		echo "tunnel: no tracked tunnel on local port ${target}" >&2
		return 1
	fi
}
