
source "${0:h}/requirements.zsh" || return

_mo_build_jobs=$(nproc 2>/dev/null) || _mo_build_jobs=1
_mo_build_has_colormake=false; command -v colormake &>/dev/null && _mo_build_has_colormake=true
_mo_build_has_banner=false;    command -v banner    &>/dev/null && _mo_build_has_banner=true

m() {
    if $_mo_build_has_colormake; then
        colormake -j"$_mo_build_jobs" "$@"
    else
        make -j"$_mo_build_jobs" "$@"
    fi
    local ret=$?
    if $_mo_build_has_banner; then
        (( ret == 0 )) && banner PASSED || banner FAILED
    fi
    return $ret
}

alias mc="make clean"
