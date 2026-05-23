
# ── tunnel — SSH port-forward with a readable syntax ──────────────────────────
#
# Syntax:  tunnel <left> to <right>
#
# Each side is  [host:]port  where host defaults to localhost.
# The remote host (if any) determines the SSH target and the direction:
#
#   local:port   to  remote:port  →  -L  (connect locally, packets exit on remote)
#   remote:port  to  local:port   →  -R  (connect on remote, packets exit locally)
#   port         to  port         →  -L  localhost to localhost (loopback)

tunnel() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
        cat <<'EOF'
Usage: tunnel [-b] [[user@]host:]<port> to [[user@]host:]<port>

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
  tunnel 0.0.0.0:80 to momo:8080       # bind all interfaces on :80 → momo:8080
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

    local -a ssh_opts=( -N )
    (( bg )) && ssh_opts+=( -f )

    if [[ "$flag" == "-L" ]]; then
        ssh "${ssh_opts[@]}" "$flag" "${bind_addr}:${local_port}:${remote_host}:${remote_port}" "$ssh_login"
    else
        ssh "${ssh_opts[@]}" "$flag" "${remote_port}:${remote_host}:${local_port}" "$ssh_login"
    fi
}
