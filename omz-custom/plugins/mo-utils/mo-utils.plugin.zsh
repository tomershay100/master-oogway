# Provides: _mo_require (internal dependency-check helper used by all mo-* plugins).
# Must be loaded before all other mo-* additive plugins.

# Check that <cmd> is installed; print an error and return 1 if not.
# Usage: _mo_require <cmd> <caller> [apt-pkg]
_mo_require() {
    local cmd="$1" caller="$2" pkg="${3:-}"
    command -v "$cmd" &>/dev/null && return 0
    if [[ -n "$pkg" ]]; then
        echo "${caller}: ${cmd} not installed (try: sudo apt install ${pkg})" >&2
    else
        echo "${caller}: ${cmd} not installed" >&2
    fi
    return 1
}
