# _mo_lan_cli.zsh — CLI subcommand implementations and dispatcher

_mo_lan_status() {
	if [[ ! -f "$_MO_LAN_SSH_CACHE" && ! -f "$_MO_LAN_SSH_MANUAL" ]]; then
		print -P "%F{yellow}No cache or manual overlay yet.%f Run: %Bmo-lan-ssh refresh%b"
		return
	fi

	print -P "%BAuto cache:%b $_MO_LAN_SSH_CACHE"
	if [[ -f "$_MO_LAN_SSH_CACHE" ]]; then
		local age hours mins refreshed auto_count cur_net cache_net net_status
		age=$(_mo_lan_cache_age)
		hours=$(( age / 3600 ))
		mins=$(( (age % 3600) / 60 ))
		refreshed=$(grep -m1 '^# Refreshed:' "$_MO_LAN_SSH_CACHE" | sed 's/^# Refreshed: //')
		auto_count=$(grep -cvE '^(#|$)' "$_MO_LAN_SSH_CACHE")
		cur_net=$(_mo_lan_network_id)
		cache_net=""
		[[ -f "$_MO_LAN_SSH_NETID" ]] && cache_net=$(< "$_MO_LAN_SSH_NETID")
		if [[ "$cur_net" == "$cache_net" ]]; then
			net_status="%F{green}✓ stable%f"
		else
			net_status="%F{yellow}✗ changed (will refresh on next shell)%f"
		fi
		print -P "  Age:       ${hours}h ${mins}m"
		print -P "  Refreshed: ${refreshed}"
		print -P "  Hosts:     ${auto_count}"
		print -P "  Network:   ${cache_net:-(none)} (now: ${cur_net}) — ${net_status}"
	else
		print -P "  %F{245}(not present — will be created on first refresh)%f"
	fi

	print -P "%BManual overlay:%b $_MO_LAN_SSH_MANUAL"
	if [[ -f "$_MO_LAN_SSH_MANUAL" ]]; then
		local manual_count
		manual_count=$(grep -cvE '^(#|$)' "$_MO_LAN_SSH_MANUAL")
		print -P "  Hosts:     ${manual_count}"
	else
		print -P "  %F{245}(none — use 'mo-lan-ssh add <host>[:<port>]' to add)%f"
	fi

	if (( ${#MO_LAN_GADGET_SUBNETS[@]} > 0 )); then
		print -P "%BGadget subnets (from MO_LAN_GADGET_SUBNETS):%b"
		local cidr
		for cidr in "${MO_LAN_GADGET_SUBNETS[@]}"; do
			print -P "  ${cidr}"
		done
	else
		print -P "%BGadget subnets:%b %F{245}(none — set MO_LAN_GADGET_SUBNETS in ~/.zshrc)%f"
	fi

	print -P "%BSettings:%b"
	print -P "  TTL:           ${MO_LAN_TTL}s"
	print -P "  Auto-scan:     ${MO_LAN_AUTO_SCAN:-on}"
	print -P "  PC ports:      ${MO_LAN_SSH_PORTS}"
	print -P "  Gadget port:   ${MO_LAN_GADGET_PORT}"
	print -P "  Keepalive:     ConnectTimeout ${MO_LAN_CONNECT_TIMEOUT}, ServerAlive ${MO_LAN_SERVER_ALIVE_INTERVAL}×${MO_LAN_SERVER_ALIVE_COUNT_MAX} (~$(( MO_LAN_SERVER_ALIVE_INTERVAL * MO_LAN_SERVER_ALIVE_COUNT_MAX ))s drop)"
	print -P "  Excludes:      ${MO_LAN_EXCLUDE:-(none)}"
	print -P "  Trust hints:   ${MO_LAN_TRUST_HINTS:-true}"

	print -P "%BSSH config:%b"
	if grep -qE '^[[:space:]]*Include[[:space:]]+config\.d/' "$_MO_LAN_SSH_USER_CONFIG" 2>/dev/null; then
		print -P "  %F{green}✓%f ~/.ssh/config has Include config.d/* line"
	else
		print -P "  %F{yellow}✗%f ~/.ssh/config missing Include — run: %Bmo-lan-ssh setup%b"
	fi
	if [[ -f "$_MO_LAN_SSH_OUTPUT" ]]; then
		local last_write
		last_write=$(stat -c %y "$_MO_LAN_SSH_OUTPUT" 2>/dev/null | cut -d. -f1)
		print -P "  %F{green}✓%f ~/.ssh/config.d/lan-hosts exists (last write: ${last_write})"
	else
		print -P "  %F{yellow}✗%f ~/.ssh/config.d/lan-hosts absent — will be written on next apply"
	fi

	print -P "%BOptional deps:%b"
	local -A _dep_pkg=(
		[avahi-browse]=avahi-utils
		[dig]=dnsutils
		[nmap]=nmap
		[arp-scan]=arp-scan
		[avahi-daemon]=avahi-daemon
	)
	local _tool
	for _tool in avahi-browse dig nmap arp-scan avahi-daemon; do
		if command -v "$_tool" &>/dev/null; then
			print -P "  %F{green}✓%f ${_tool}"
		else
			print -P "  %F{yellow}✗%f ${_tool}  (apt install ${_dep_pkg[$_tool]})"
		fi
	done
}

_mo_lan_add() {
	local entry="$1"
	[[ -z "$entry" ]] && { echo "Usage: mo-lan-ssh add <host>[:<port>]" >&2; return 1; }

	local h p
	if [[ "$entry" == *:* ]]; then h="${entry%%:*}"; p="${entry##*:}"
	else h="$entry"; p=""; fi

	if ! _mo_lan_valid_host "$h"; then
		echo "mo-lan-ssh: invalid hostname '$h' (allowed: a-z A-Z 0-9 _ -)" >&2; return 1
	fi
	if [[ -n "$p" ]] && ! _mo_lan_valid_port "$p"; then
		echo "mo-lan-ssh: invalid port '$p' (must be 1–65535)" >&2; return 1
	fi

	command mkdir -p "${_MO_LAN_SSH_MANUAL:h}"
	if [[ -f "$_MO_LAN_SSH_MANUAL" ]]; then
		local tmp
		tmp=$(mktemp "${_MO_LAN_SSH_MANUAL}.XXXXXX")
		grep -vE "^${h}(:.*)?$" "$_MO_LAN_SSH_MANUAL" > "$tmp" 2>/dev/null || true
		command mv "$tmp" "$_MO_LAN_SSH_MANUAL"
	else
		{ echo "# mo-lan-ssh manual host overlay — edit freely; one host[:port] per line"
		  echo "# Manual entries win over auto-discovered ones on hostname collision."
		} > "$_MO_LAN_SSH_MANUAL"
	fi
	echo "$entry" >> "$_MO_LAN_SSH_MANUAL"

	_mo_lan_apply
	local alias_name="${_MO_LAN_ALIAS_NAMES[$h]:-$h}"
	echo "Added: $entry  (alias ${alias_name} now active in this shell)"
}

_mo_lan_remove() {
	local h="$1"
	[[ -z "$h" ]] && { echo "Usage: mo-lan-ssh remove <host>" >&2; return 1; }
	_mo_lan_valid_host "$h" || { echo "mo-lan-ssh: invalid hostname '$h'" >&2; return 1; }
	[[ -f "$_MO_LAN_SSH_MANUAL" ]] \
		|| { echo "mo-lan-ssh: no manual overlay (nothing to remove)" >&2; return; }

	if ! grep -qE "^${h}(:.*)?$" "$_MO_LAN_SSH_MANUAL" 2>/dev/null; then
		echo "mo-lan-ssh: '$h' is not in the manual overlay" >&2
		echo "  (auto-discovered entries are removed via: mo-lan-ssh purge $h)" >&2
		return 1
	fi
	local tmp
	tmp=$(mktemp "${_MO_LAN_SSH_MANUAL}.XXXXXX")
	grep -vE "^${h}(:.*)?$" "$_MO_LAN_SSH_MANUAL" > "$tmp" 2>/dev/null || true
	command mv "$tmp" "$_MO_LAN_SSH_MANUAL"

	if ! grep -qE "^${h}(:.*)?$" "$_MO_LAN_SSH_CACHE" 2>/dev/null; then
		unalias "${h}" "s-${h}" 2>/dev/null
	fi
	_mo_lan_apply
	echo "Removed: $h from manual overlay"
}

_mo_lan_purge() {
	local h="$1"
	[[ -z "$h" ]] && { echo "Usage: mo-lan-ssh purge <host>" >&2; return 1; }
	_mo_lan_valid_host "$h" || { echo "mo-lan-ssh: invalid hostname '$h'" >&2; return 1; }

	local -a removed=()
	local tmp

	if [[ -f "$_MO_LAN_SSH_CACHE" ]] \
	   && grep -qE "^${h}(:.*)?$" "$_MO_LAN_SSH_CACHE" 2>/dev/null; then
		tmp=$(mktemp "${_MO_LAN_SSH_CACHE}.XXXXXX")
		grep -vE "^${h}(:.*)?$" "$_MO_LAN_SSH_CACHE" > "$tmp"
		command mv "$tmp" "$_MO_LAN_SSH_CACHE"
		removed+=("auto-cache")
	fi

	if [[ -f "$_MO_LAN_SSH_MANUAL" ]] \
	   && grep -qE "^${h}(:.*)?$" "$_MO_LAN_SSH_MANUAL" 2>/dev/null; then
		tmp=$(mktemp "${_MO_LAN_SSH_MANUAL}.XXXXXX")
		grep -vE "^${h}(:.*)?$" "$_MO_LAN_SSH_MANUAL" > "$tmp"
		command mv "$tmp" "$_MO_LAN_SSH_MANUAL"
		removed+=("manual-overlay")
	fi

	local keygen_out
	keygen_out=$(command ssh-keygen -R "$h" 2>&1)
	[[ "$keygen_out" == *"Host found"* ]] && removed+=("known_hosts")

	unalias "${h}" "s-${h}" 2>/dev/null
	_mo_lan_apply

	if (( ${#removed[@]} > 0 )); then
		echo "Purged $h from: ${(j:, :)removed}"
		echo "  (also regenerated ~/.ssh/config.d/lan-hosts)"
	else
		echo "$h was not known to mo-lan-ssh."
	fi
}

_mo_lan_setup() {
	command mkdir -p "$_MO_LAN_SSH_USER_CONFIG_DIR"
	chmod 700 "$_MO_LAN_SSH_USER_CONFIG_DIR"

	if [[ ! -f "$_MO_LAN_SSH_USER_CONFIG" ]]; then
		touch "$_MO_LAN_SSH_USER_CONFIG"
		chmod 600 "$_MO_LAN_SSH_USER_CONFIG"
		echo "Created ${_MO_LAN_SSH_USER_CONFIG}"
	fi
	if ! grep -qE '^[[:space:]]*Include[[:space:]]+config\.d/' "$_MO_LAN_SSH_USER_CONFIG"; then
		local tmp
		tmp=$(mktemp "${_MO_LAN_SSH_USER_CONFIG}.XXXXXX")
		{ echo "Include config.d/*"; echo ""; cat "$_MO_LAN_SSH_USER_CONFIG"; } > "$tmp"
		chmod 600 "$tmp"
		command mv "$tmp" "$_MO_LAN_SSH_USER_CONFIG"
		echo "Added 'Include config.d/*' to ${_MO_LAN_SSH_USER_CONFIG}"
	else
		echo "Include line already present in ${_MO_LAN_SSH_USER_CONFIG}"
	fi

	if [[ -f "$HOME/.ssh/id_ed25519" || -f "$HOME/.ssh/id_rsa" || -f "$HOME/.ssh/id_ecdsa" ]]; then
		echo "SSH key present in ~/.ssh/"
	else
		echo "No SSH key found. Run: ssh-keygen -t ed25519"
	fi

	if ! command -v avahi-daemon &>/dev/null \
	   && ! systemctl is-active --quiet avahi-daemon 2>/dev/null; then
		echo ""
		printf "Install avahi-daemon? Advertises this host on the LAN so other master-oogway machines find you via mDNS. [y/N] "
		read -r avahi_answer </dev/tty
		if [[ "$avahi_answer" == [yY] ]]; then
			sudo apt install -y avahi-daemon
		fi
	fi

	echo "Running discovery (foreground)..."
	if _mo_lan_refresh_foreground; then
		_mo_lan_apply
		local count=0
		[[ -f "$_MO_LAN_SSH_CACHE" ]] && count=$(grep -cvE '^(#|$)' "$_MO_LAN_SSH_CACHE")
		echo "Setup complete: ${count} hosts discovered. Open a new terminal for the aliases to load."
	else
		echo "Discovery failed. Check 'mo-lan-ssh status' for details."
		return 1
	fi
}

mo-lan-ssh() {
	local sub="${1:-help}"
	shift 2>/dev/null

	case "$sub" in
		list)
			if [[ ! -f "$_MO_LAN_SSH_CACHE" && ! -f "$_MO_LAN_SSH_MANUAL" ]]; then
				echo "mo-lan-ssh: no cache yet — run: mo-lan-ssh refresh" >&2
				return 1
			fi
			_mo_lan_load_caches
			local h p src notes alias_name
			for h in "${(@kon)_MO_LAN_HOSTS}"; do
				p="${_MO_LAN_PORTS[$h]:-22}"
				if [[ -f "$_MO_LAN_SSH_MANUAL" ]] \
				   && grep -qE "^${h}(:.*)?$" "$_MO_LAN_SSH_MANUAL" 2>/dev/null; then
					src="manual"
				else
					src="auto"
				fi
				notes="$src"
				(( p != 22 )) && notes="${notes}, port ${p}"
				alias_name="${_MO_LAN_ALIAS_NAMES[$h]:-$h}"
				[[ "$alias_name" != "$h" ]] && notes="${notes}, aliased as ${alias_name} — name conflicts"
				printf "%-30s  (%s)\n" "$h" "$notes"
			done
			if (( ${#MO_LAN_GADGET_SUBNETS[@]} > 0 )); then
				echo ""
				echo "Gadget subnets (declarative, see MO_LAN_GADGET_SUBNETS):"
				local cidr
				for cidr in "${MO_LAN_GADGET_SUBNETS[@]}"; do
					printf "  %-24s → User root, Port %s\n" "$cidr" "${MO_LAN_GADGET_PORT}"
				done
			fi
			;;
		refresh)
			local bg=false
			local arg
			for arg in "$@"; do
				[[ "$arg" == "--background" ]] && bg=true
			done
			if $bg; then
				_mo_lan_refresh_async
				echo "Discovery running in background."
				return
			fi
			if _mo_lan_refresh_foreground; then
				_mo_lan_apply
				local count=0
				[[ -f "$_MO_LAN_SSH_CACHE" ]] && count=$(grep -cvE '^(#|$)' "$_MO_LAN_SSH_CACHE")
				echo "Refresh complete: ${count} hosts. Aliases updated in this shell."
			else
				return $?
			fi
			;;
		status)  _mo_lan_status ;;
		setup)   _mo_lan_setup ;;
		add)     _mo_lan_add "$@" ;;
		remove|rm) _mo_lan_remove "$@" ;;
		purge)   _mo_lan_purge "$@" ;;
		help|-h|--help)
			cat <<'EOF'
Usage: mo-lan-ssh <command> [args]

Discovery & state:
  list                    Print all known hosts (PCs auto + manual + gadget subnets)
  refresh [--background]  Refresh discovery now (foreground default)
  status                  Cache age, network, settings, dep state
  setup                   Bootstrap: Include line, avahi-daemon prompt, first refresh

Manual overlay (hosts not auto-discovered — non-standard ports, behind WireGuard, etc.):
  add <host>[:<port>]     Persist host in manual overlay; takes effect immediately
  remove <host>           Remove from manual overlay (alias: rm)

Cleanup:
  purge <host>            Remove from auto cache + manual + known_hosts + ssh-config + alias

  help                    Show this message

Env-var configuration (set in ~/.zshrc):
  MO_LAN_TTL              Cache freshness window (seconds, default 86400)
  MO_LAN_AUTO_SCAN        on (default) or off — off disables startup scans
  MO_LAN_SSH_PORTS        Comma-list of PC ports to probe (default 22)
  MO_LAN_PROBE_TIMEOUT    Per-port probe timeout seconds (default 2)
  MO_LAN_PROBE_PARALLEL   Concurrent probes (default 20)
  MO_LAN_EXCLUDE          Comma-list of hostnames to skip
  MO_LAN_SUBNET           Override discovery subnet (e.g. 10.0.1.0/24)
  MO_LAN_DNS_SERVER       Override DNS server for AXFR strategy
  MO_LAN_DNS_ZONE         Override DNS zone for AXFR strategy
  MO_LAN_GADGET_PORT      USB-gadget SSH port (default 2222)
  MO_LAN_GADGET_SUBNETS   zsh array of CIDR subnets for gadget wildcard blocks
  MO_LAN_IDENTITY         IdentityFile for both PC and gadget config blocks
  MO_LAN_CONNECT_TIMEOUT  ConnectTimeout (seconds, default 5)
  MO_LAN_SERVER_ALIVE_INTERVAL  ServerAliveInterval (seconds, default 10)
  MO_LAN_SERVER_ALIVE_COUNT_MAX ServerAliveCountMax (default 2, ~20s drop)
  MO_LAN_TRUST_HINTS      false disables the ssh hint wrapper entirely (default true)
  MO_LAN_VERBOSE          true enables [mo-lan-ssh] log lines (default false)
EOF
			;;
		*)
			echo "mo-lan-ssh: unknown command '$sub' — see 'mo-lan-ssh help'" >&2
			return 1
			;;
	esac
}
