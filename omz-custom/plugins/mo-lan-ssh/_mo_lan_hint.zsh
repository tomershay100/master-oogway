# _mo_lan_hint.zsh — hint-only SSH wrapper (sourced by _mo_lan_loader.zsh)
#
# For in-scope targets in regular interactive use, probes BatchMode=yes first.
# Probe fails → yellow hint to run ssh-copy-id. Probe succeeds → silent pass.
# In-scope = PC hostname in _MO_LAN_HOSTSET OR IP matching _MO_LAN_GADGET_GLOBS.
# Disable entirely: export MO_LAN_TRUST_HINTS=false in ~/.zshrc.

# Return the destination from ssh argv, stripped of user@ prefix.
# Skips values of option-taking flags so their arguments aren't mistaken
# for the host.
_mo_lan_extract_target() {
	local arg next_is_value=false
	for arg in "$@"; do
		if $next_is_value; then
			next_is_value=false
			continue
		fi
		case "$arg" in
			-[BbcDEeFIiJLlmOoPpRSWwQ])
				next_is_value=true
				;;
			-*)
				;;
			*)
				print -- "${arg##*@}"
				return
				;;
		esac
	done
}

# Return 0 if this looks like a regular interactive ssh (no tunnel/ctl/bg flags,
# no remote command). Used to skip the probe for scripts and port-forwarding.
_mo_lan_is_regular_interactive() {
	[[ -t 0 ]] || return 1
	local arg next_is_value=false target_seen=false
	for arg in "$@"; do
		if $next_is_value; then next_is_value=false; continue; fi
		case "$arg" in
			# Tunnel / background / control flags → not regular interactive
			-[LRDWNTf]) return 1 ;;
			-O*)         return 1 ;;
			-[BbcDEeFIiJLlmOoPpRSWwQ])
				next_is_value=true ;;
			-*)  ;;
			*)
				if $target_seen; then
					return 1  # remote command present
				fi
				target_seen=true
				;;
		esac
	done
	return 0
}

# Return 0 if $1 matches any glob in _MO_LAN_GADGET_GLOBS.
_mo_lan_in_gadget_subnet() {
	local target="$1" glob
	for glob in "${_MO_LAN_GADGET_GLOBS[@]:-}"; do
		[[ -n "$glob" && "$target" == ${~glob} ]] && return 0
	done
	return 1
}

_mo_lan_ssh_hint() {
	# Step 1: extract target (user@ already stripped by _mo_lan_extract_target)
	local target
	target=$(_mo_lan_extract_target "$@")

	# Step 2: out of scope → fast path (one hash lookup + a few glob tests)
	if [[ -z "$target" ]] \
	   || ( [[ -z "${_MO_LAN_HOSTSET[$target]:-}" ]] \
	        && ! _mo_lan_in_gadget_subnet "$target" ); then
		command ssh "$@"
		return $?
	fi

	# Step 3: not regular interactive → no probe, no hint
	if ! _mo_lan_is_regular_interactive "$@"; then
		command ssh "$@"
		return $?
	fi

	# Step 4: BatchMode probe
	local probe_rc
	command ssh -o BatchMode=yes \
	            -o ConnectTimeout="${MO_LAN_PROBE_TIMEOUT:-2}" \
	            -o LogLevel=ERROR \
	            "$@" true &>/dev/null
	probe_rc=$?

	# Steps 5-6: silent on success; yellow hint on failure, then real ssh
	if (( probe_rc != 0 )); then
		print -P "%F{yellow}[mo-lan-ssh]%f ${target} has no working key. Run: ssh-copy-id ${target}" >&2
		print -P "%F{245}  (silence: export MO_LAN_TRUST_HINTS=false in your zshrc)%f" >&2
	fi
	command ssh "$@"
}
