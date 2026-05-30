# _mo_lan_loader.zsh — paths, defaults, startup helpers, apply, shell loader

zmodload -F zsh/datetime p:EPOCHSECONDS 2>/dev/null

# ── Paths ─────────────────────────────────────────────────────────────────────

typeset -g _MO_LAN_SSH_DIR="${0:a:h}"
typeset -g _MO_LAN_SSH_DISCOVER="${_MO_LAN_SSH_DIR}/_mo_lan_discover.zsh"
typeset -g _MO_LAN_SSH_CACHE="${HOME}/.config/master-oogway/lan-hosts"
typeset -g _MO_LAN_SSH_LOCK="${HOME}/.config/master-oogway/lan-hosts.lock"
typeset -g _MO_LAN_SSH_SHA="${HOME}/.config/master-oogway/lan-hosts.sshconf.sha"
typeset -g _MO_LAN_SSH_NETID="${HOME}/.config/master-oogway/lan-hosts.netid"
typeset -g _MO_LAN_SSH_MANUAL="${HOME}/.config/master-oogway/lan-hosts.manual"
typeset -g _MO_LAN_SSH_OUTPUT="${HOME}/.ssh/config.d/lan-hosts"
typeset -g _MO_LAN_SSH_USER_CONFIG="${HOME}/.ssh/config"
typeset -g _MO_LAN_SSH_USER_CONFIG_DIR="${HOME}/.ssh/config.d"

# ── Defaults ──────────────────────────────────────────────────────────────────

: ${MO_LAN_TTL:=86400}
: ${MO_LAN_AUTO_SCAN:=on}
: ${MO_LAN_SSH_PORTS:=22}
: ${MO_LAN_PROBE_TIMEOUT:=2}
: ${MO_LAN_PROBE_PARALLEL:=20}
: ${MO_LAN_EXCLUDE:=}
: ${MO_LAN_VERBOSE:=false}
: ${MO_LAN_GADGET_PORT:=2222}
: ${MO_LAN_IDENTITY:=}
: ${MO_LAN_CONNECT_TIMEOUT:=5}
: ${MO_LAN_SERVER_ALIVE_INTERVAL:=10}
: ${MO_LAN_SERVER_ALIVE_COUNT_MAX:=2}
: ${MO_LAN_TRUST_HINTS:=true}
# MO_LAN_GADGET_SUBNETS is a zsh array. Declare it here so it's always a
# proper array even if unset; user sets it in ~/.zshrc before the plugin loads.
typeset -ga MO_LAN_GADGET_SUBNETS

# ── Helpers ───────────────────────────────────────────────────────────────────

_mo_lan_log() {
	[[ "$MO_LAN_VERBOSE" == "true" ]] || return 0
	print -P "%F{245}[mo-lan-ssh]%f $*" >&2
}

_mo_lan_network_id() {
	local gw iface subnet
	read -r gw iface < <(ip route show default 2>/dev/null \
		| awk '/default/ { print $3, $5; exit }')
	[[ -z "$iface" ]] && { echo "unknown"; return; }
	subnet=$(ip -o -f inet addr show "$iface" 2>/dev/null | awk 'NR==1 { print $4 }')
	print -- "${gw}-${subnet}" | md5sum | awk '{ print substr($1,1,8) }'
}

_mo_lan_cache_age() {
	local mtime
	mtime=$(stat -c %Y "$_MO_LAN_SSH_CACHE" 2>/dev/null) || { echo 999999999; return; }
	echo $(( EPOCHSECONDS - mtime ))
}

_mo_lan_refresh_async() {
	[[ -f "$_MO_LAN_SSH_DISCOVER" ]] || return
	(
		flock -n 9 || exit 0
		zsh "$_MO_LAN_SSH_DISCOVER" 2>/dev/null
	) 9>"$_MO_LAN_SSH_LOCK" &!
}

# Foreground refresh: blocking flock so a concurrent background scan completes
# first, then this run gets the lock and overwrites with a fresh result.
_mo_lan_refresh_foreground() {
	[[ -f "$_MO_LAN_SSH_DISCOVER" ]] || { echo "mo-lan-ssh: discover script not found" >&2; return 1; }
	(
		flock 9
		zsh "$_MO_LAN_SSH_DISCOVER"
	) 9>"$_MO_LAN_SSH_LOCK"
}

_mo_lan_check_ttl_async() {
	local age
	age=$(_mo_lan_cache_age)
	if (( age > MO_LAN_TTL )); then
		_mo_lan_log "Cache stale (${age}s > ${MO_LAN_TTL}s) — refreshing in background"
		_mo_lan_refresh_async
	fi
}

_mo_lan_check_network_async() {
	# /proc/net/route mtime changes when the routing table changes — cheap gate.
	[[ -f "$_MO_LAN_SSH_NETID" && ! /proc/net/route -nt "$_MO_LAN_SSH_NETID" ]] && return
	local cur stored=""
	cur=$(_mo_lan_network_id)
	[[ -z "$cur" || "$cur" == "unknown" ]] && return
	[[ -f "$_MO_LAN_SSH_NETID" ]] && stored=$(< "$_MO_LAN_SSH_NETID")
	print -- "$cur" >| "$_MO_LAN_SSH_NETID"
	if [[ -n "$stored" && "$cur" != "$stored" ]]; then
		_mo_lan_log "Network changed (${stored} → ${cur}) — refreshing in background"
		_mo_lan_refresh_async
	fi
}

_mo_lan_valid_host() { [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]] }
_mo_lan_valid_port() { [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 )) }

_mo_lan_name_conflicts() {
	local n="$1"
	(( ${+commands[$n]}  )) && return 0
	(( ${+aliases[$n]}   )) && return 0
	(( ${+functions[$n]} )) && return 0
	(( ${+builtins[$n]}  )) && return 0
	(( ${+reswords[$n]}  )) && return 0
	return 1
}

_mo_lan_load_caches() {
	typeset -gA _MO_LAN_HOSTS=()
	typeset -gA _MO_LAN_PORTS=()
	local file line h p lineno
	for file in "$_MO_LAN_SSH_MANUAL" "$_MO_LAN_SSH_CACHE"; do
		[[ -f "$file" ]] || continue
		lineno=0
		while IFS= read -r line; do
			(( lineno++ ))
			[[ "$line" == '#'* || -z "$line" ]] && continue
			if [[ "$line" == *:* ]]; then
				h="${line%%:*}"; p="${line##*:}"
			else
				h="$line"; p="22"
			fi
			if ! _mo_lan_valid_host "$h"; then
				print -P "%F{yellow}[mo-lan-ssh]%f Skipped ${file}:${lineno}: invalid hostname '${h}'" >&2
				continue
			fi
			if ! _mo_lan_valid_port "$p"; then
				print -P "%F{yellow}[mo-lan-ssh]%f Skipped ${file}:${lineno}: invalid port '${p}' for '${h}'" >&2
				continue
			fi
			[[ -z "${_MO_LAN_HOSTS[$h]:-}" ]] && {
				_MO_LAN_HOSTS[$h]=1
				_MO_LAN_PORTS[$h]="$p"
			}
		done < "$file"
	done
}

# Convert a CIDR like 192.168.7.0/24 to an ssh Host glob 192.168.7.*
# Only /24 is supported; warns and returns 1 for any other prefix length.
_mo_lan_cidr_to_glob() {
	local prefix="${1##*/}"
	[[ "$prefix" == "24" ]] || {
		print -P "%F{yellow}[mo-lan-ssh]%f MO_LAN_GADGET_SUBNETS: ${1} — only /24 subnets supported; skipping" >&2
		return 1
	}
	local net="${1%%/*}"
	echo "${net%.*}.*"
}

# Write ~/.ssh/config.d/lan-hosts from current host maps + gadget config.
# SHA-gated: recomputes SHA over all inputs (including env vars) and skips
# the write when nothing has changed. ~1ms per apply in steady state.
_mo_lan_maybe_write_sshconf() {
	local pc_count=${#_MO_LAN_HOSTS[@]}
	local gadget_count=${#MO_LAN_GADGET_SUBNETS[@]}
	(( pc_count == 0 && gadget_count == 0 )) && return

	local current_sha
	current_sha=$( {
		[[ -f "$_MO_LAN_SSH_CACHE" ]]  && cat "$_MO_LAN_SSH_CACHE"
		[[ -f "$_MO_LAN_SSH_MANUAL" ]] && cat "$_MO_LAN_SSH_MANUAL"
		echo "PORT=${MO_LAN_GADGET_PORT}"
		echo "SUBNETS=${MO_LAN_GADGET_SUBNETS[*]:-}"
		echo "IDENTITY=${MO_LAN_IDENTITY:-}"
		echo "CONNTIMEOUT=${MO_LAN_CONNECT_TIMEOUT}"
		echo "ALIVEINT=${MO_LAN_SERVER_ALIVE_INTERVAL}"
		echo "ALIVECNT=${MO_LAN_SERVER_ALIVE_COUNT_MAX}"
	} 2>/dev/null | sha256sum | cut -d' ' -f1 )

	local last_sha=""
	[[ -f "$_MO_LAN_SSH_SHA" && -f "$_MO_LAN_SSH_OUTPUT" ]] \
		&& last_sha=$(< "$_MO_LAN_SSH_SHA")
	[[ "$current_sha" == "$last_sha" ]] && return

	command mkdir -p "$_MO_LAN_SSH_USER_CONFIG_DIR"
	chmod 700 "$_MO_LAN_SSH_USER_CONFIG_DIR"

	local tmp="${_MO_LAN_SSH_OUTPUT}.tmp"
	{
		echo "# mo-lan-ssh — autogenerated, do not edit by hand"
		echo "# Source of truth: ${_MO_LAN_SSH_CACHE}"
		[[ -f "$_MO_LAN_SSH_MANUAL" ]] && echo "# Manual overlay: ${_MO_LAN_SSH_MANUAL}"
		echo ""

		if (( pc_count > 0 )); then
			echo "# --- LAN PCs ---"
			echo "Host ${(@k)_MO_LAN_HOSTS}"
			echo "    StrictHostKeyChecking no"
			echo "    ConnectTimeout ${MO_LAN_CONNECT_TIMEOUT}"
			echo "    ServerAliveInterval ${MO_LAN_SERVER_ALIVE_INTERVAL}"
			echo "    ServerAliveCountMax ${MO_LAN_SERVER_ALIVE_COUNT_MAX}"
			[[ -n "${MO_LAN_IDENTITY:-}" ]] && echo "    IdentityFile ${MO_LAN_IDENTITY}"
			echo ""
			local h p
			for h in "${(@kon)_MO_LAN_HOSTS}"; do
				p="${_MO_LAN_PORTS[$h]:-22}"
				(( p != 22 )) || continue
				echo "Host ${h}"
				echo "    Port ${p}"
				echo ""
			done
		fi

		if (( gadget_count > 0 )); then
			echo "# --- Gadgets ---"
			local globs=()
			local cidr
			for cidr in "${MO_LAN_GADGET_SUBNETS[@]}"; do
				[[ "$cidr" =~ ^[0-9./]+$ ]] || continue
				local g
			g=$(_mo_lan_cidr_to_glob "$cidr") && globs+=("$g")
			done
			if (( ${#globs[@]} > 0 )); then
				echo "Host ${globs[*]}"
				echo "    User root"
				echo "    Port ${MO_LAN_GADGET_PORT}"
				echo "    StrictHostKeyChecking no"
				echo "    UserKnownHostsFile /dev/null"
				echo "    LogLevel ERROR"
				echo "    ConnectTimeout ${MO_LAN_CONNECT_TIMEOUT}"
				echo "    ServerAliveInterval ${MO_LAN_SERVER_ALIVE_INTERVAL}"
				echo "    ServerAliveCountMax ${MO_LAN_SERVER_ALIVE_COUNT_MAX}"
				[[ -n "${MO_LAN_IDENTITY:-}" ]] && echo "    IdentityFile ${MO_LAN_IDENTITY}"
				echo ""
			fi
		fi
	} > "$tmp"
	chmod 600 "$tmp"
	command mv "$tmp" "$_MO_LAN_SSH_OUTPUT"
	print -- "$current_sha" > "$_MO_LAN_SSH_SHA"
	_mo_lan_log "Wrote ${_MO_LAN_SSH_OUTPUT}"
}

_mo_lan_apply() {
	_mo_lan_load_caches
	# Tear down aliases from the previous apply to avoid false conflict-detection.
	local prev_alias
	for prev_alias in "${(@v)_MO_LAN_ALIAS_NAMES:-}"; do
		unalias -- "$prev_alias" 2>/dev/null
	done
	typeset -gA _MO_LAN_ALIAS_NAMES=()

	# 1. Aliases (bare name or s-<host> on collision)
	local h alias_name p ssh_cmd
	for h in "${(@kon)_MO_LAN_HOSTS}"; do
		if _mo_lan_name_conflicts "$h"; then
			alias_name="s-${h}"
		else
			alias_name="$h"
		fi
		p="${_MO_LAN_PORTS[$h]:-22}"
		if (( p != 22 )); then
			ssh_cmd="ssh -p ${p} ${h}"
		else
			ssh_cmd="ssh ${h}"
		fi
		alias -- "${alias_name}=${ssh_cmd}"
		_MO_LAN_ALIAS_NAMES[$h]="$alias_name"
	done

	# 2. Tab completion
	(( ${#_MO_LAN_HOSTS[@]} > 0 )) \
		&& zstyle ':completion:*:(ssh|scp|sftp|rsync|ssh-copy-id):*' hosts "${(@k)_MO_LAN_HOSTS}"

	# 3. Hint wrapper
	if [[ "${MO_LAN_TRUST_HINTS:-true}" != "false" ]]; then
		typeset -gA _MO_LAN_HOSTSET=()
		for h in "${(@k)_MO_LAN_HOSTS}"; do _MO_LAN_HOSTSET[$h]=1; done
		# Build glob list from gadget subnets for the hint wrapper scope check.
		typeset -ga _MO_LAN_GADGET_GLOBS=()
		local cidr
		for cidr in "${MO_LAN_GADGET_SUBNETS[@]}"; do
			[[ "$cidr" =~ ^[0-9./]+$ ]] || continue
			local g
			g=$(_mo_lan_cidr_to_glob "$cidr") && _MO_LAN_GADGET_GLOBS+=("$g")
		done
		if ! (( $+functions[ssh] )) \
		   || [[ "$(declare -f ssh 2>/dev/null)" == *"_mo_lan_ssh_hint"* ]]; then
			ssh() { _mo_lan_ssh_hint "$@"; }
		else
			print -P "%F{245}[mo-lan-ssh]%f ssh() already defined by something else — trust hints disabled this shell" >&2
		fi
	fi

	# 4. ssh-config write (SHA-gated, ~1ms in steady state)
	_mo_lan_maybe_write_sshconf
}

# ── Hint wrapper source ───────────────────────────────────────────────────────

source "${_MO_LAN_SSH_DIR}/_mo_lan_hint.zsh"

# ── Loader (runs once at shell startup) ───────────────────────────────────────

() {
	if [[ ! -f "$_MO_LAN_SSH_CACHE" && ! -f "$_MO_LAN_SSH_MANUAL" ]]; then
		[[ "${MO_LAN_AUTO_SCAN:-on}" == "on" ]] && _mo_lan_refresh_async
		return
	fi

	if [[ "${MO_LAN_AUTO_SCAN:-on}" == "on" ]]; then
		_mo_lan_check_ttl_async
		_mo_lan_check_network_async
	fi

	_mo_lan_apply
}
