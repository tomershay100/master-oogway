
source "${0:h}/requirements.zsh" || return

_mo_build_jobs=$(nproc 2>/dev/null) || _mo_build_jobs=1
_mo_build_has_colormake=false; (( $+_MO_OPT_BIN[colormake] )) && _mo_build_has_colormake=true
_mo_build_has_banner=false;    (( $+_MO_OPT_BIN[banner]    )) && _mo_build_has_banner=true

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
