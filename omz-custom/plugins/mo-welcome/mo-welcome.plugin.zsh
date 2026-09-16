# oh-my-zsh does not source $ZSH_CUSTOM/lib; nor does a zshrc seeded before it.
[[ -n ${_MO_PLATFORM_LOADED-} ]] || source "${0:h}/../../lib/platform.zsh"

_mo_welcome_field_host() {
	print -P "  %F{245}host%f   %F{cyan}%B${USER}%b%F{245} @ %f%F{green}%B${HOST%%.*}%b%f"
}

_mo_welcome_field_os() {
	print -P "  %F{245}os  %f   %F{magenta}$(_mo_os_name)%f"
}

_mo_welcome_field_sys() {
	print -P "  %F{245}sys %f   %F{blue}$(_mo_kernel)%f"
}

_mo_welcome_field_arch() {
	print -P "  %F{245}arch%f   %F{blue}$(_mo_arch)%f"
}

_mo_welcome_field_now() {
	local date_line
	zmodload zsh/datetime
	strftime -s date_line '%a, %d %b %Y · %H:%M' $EPOCHSECONDS
	print -P "  %F{245}now %f   %F{yellow}${date_line}%f"
}

_mo_welcome_field_up() {
	local up_secs up_str
	up_secs=$(_mo_uptime_secs)
	up_str="$(( up_secs / 86400 ))d $(( up_secs % 86400 / 3600 ))h $(( up_secs % 3600 / 60 ))m"
	print -P "  %F{245}up  %f   %F{green}${up_str}%f"
}

_mo_welcome_field_ip() {
	local ip
	ip=$(_mo_local_ip)
	[[ -n "$ip" ]] && print -P "  %F{245}ip  %f   %F{cyan}${ip}%f"
}

_mo_welcome_field_shell() {
	print -P "  %F{245}sh  %f   %F{blue}zsh ${ZSH_VERSION}%f"
}

_mo_welcome_field_load() {
	local load1 cores summary pct color
	load1=$(_mo_load_avg)
	cores=$(_mo_cpu_count)
	(( cores > 0 )) || cores=1
	# Apple Silicon core tiers are named per chip, so the summary is read from
	# the hardware rather than assumed; on Linux this is just the count.
	summary=$(_mo_core_summary)
	printf -v pct "%.0f" "$(( load1 * 100 / cores ))"
	if   (( pct >= 80 )); then color=red
	elif (( pct >= 50 )); then color=yellow
	else                       color=green
	fi
	printf -v load1 "%.2f" "$load1"
	print -P "  %F{245}load%f   %F{${color}}${load1} load  ·  ${summary} cores  ·  ${pct}%% busy%f"
}

_mo_welcome_field_mem() {
	local used total pct used_gb total_gb
	read -r used total <<< "$(_mo_mem_stats)"
	(( total > 0 )) || return 0
	pct=$(( used * 100 / total ))
	printf -v used_gb  "%.1f" "$(( used  / 1073741824.0 ))"
	printf -v total_gb "%.1f" "$(( total / 1073741824.0 ))"
	print -P "  %F{245}mem %f   %F{magenta}${used_gb} / ${total_gb} GB (${pct}%%)%f"
}

_mo_welcome_field_disk() {
	# _mo_disk_pct, not `df -P /`: on macOS / is the sealed, read-only system
	# snapshot, which sits at a couple of percent no matter how full the disk
	# is — so this under-reported badly and the thresholds below could never
	# fire. The writable volume is /System/Volumes/Data.
	local pct color mount=/
	pct=$(_mo_disk_pct)
	[[ -n "$pct" ]] || return 0
	_mo_is_macos && [[ -d /System/Volumes/Data ]] && mount="/System/Volumes/Data"
	if   (( pct >= 90 )); then color=red
	elif (( pct >= 70 )); then color=yellow
	else                       color=green
	fi
	print -P "  %F{245}disk%f   %F{${color}}${mount} at ${pct}%%%f"
}

_mo_welcome_field_tmux() {
	[[ -n "${TMUX:-}" ]] || return 0
	local session
	session=$(tmux display-message -p '#S' 2>/dev/null) || return 0
	print -P "  %F{245}tmux%f   %F{green}${session}%f"
}

_mo_welcome_field_ssh() {
	[[ -n "${SSH_CONNECTION:-}" ]] || return 0
	# SSH_CONNECTION = "<client-ip> <client-port> <server-ip> <server-port>"
	local from="${SSH_CONNECTION%% *}"
	print -P "  %F{245}ssh %f   %F{yellow}${USER}@${HOST%%.*} ← ${from}%f"
}

() {
	local field
	local -a fields
	fields=(${(z)${MO_WELCOME_FIELDS-host os sys now up}})
	(( ${#fields[@]} )) || return
	print -P ""
	for field in "${fields[@]}"; do
		if (( ${+functions[_mo_welcome_field_${field}]} )); then
			_mo_welcome_field_${field}
		fi
	done
	print -P ""
}
