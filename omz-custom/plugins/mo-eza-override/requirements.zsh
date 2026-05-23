# Hard deps — plugin does not load if none of these are present.
local _missing=()
command -v eza &>/dev/null || command -v exa &>/dev/null || _missing+=(eza)

if (( ${#_missing} )); then
    print -P "%F{yellow}[mo-eza-override]%f missing: ${_missing[*]} (try: sudo apt install eza) — plugin not loaded"
    return 1
fi
