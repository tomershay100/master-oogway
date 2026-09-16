
# oh-my-zsh does not source $ZSH_CUSTOM/lib; nor does a zshrc seeded before it.
[[ -n ${_MO_PLATFORM_LOADED-} ]] || source "${0:h}/../../lib/platform.zsh"

source "${0:h}/requirements.zsh" || return

_mo_build_jobs_value() { _mo_cpu_count }
_mo_build_jobs=$(_mo_build_jobs_value)
_mo_build_has_colormake=false
command -v colormake &>/dev/null && _mo_build_has_colormake=true

m() {
	if $_mo_build_has_colormake; then
		colormake -j"$_mo_build_jobs" "$@"
	else
		make -j"$_mo_build_jobs" "$@"
	fi
	local ret=$?
	if (( ret == 0 )); then
		print -P "%F{green}%BPASSED ✓%b%f"
	else
		print -P "%F{red}%BFAILED ✗%b%f"
	fi
	return $ret
}

alias mc="make clean"
