
source "${0:h}/requirements.zsh" || return

_mo_build_jobs=$(nproc 2>/dev/null) || _mo_build_jobs=1
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
