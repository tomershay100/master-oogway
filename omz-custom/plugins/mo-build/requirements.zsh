# Hard deps — plugin does not load if make is absent.
local _missing=()
command -v make &>/dev/null || _missing+=(make)

if (( ${#_missing} )); then
    print -P "%F{yellow}[mo-build]%f missing: ${_missing[*]} (try: sudo apt install build-essential) — plugin not loaded"
    return 1
fi
