# Hard deps — plugin does not load if eza is absent.
local _missing=()
command -v eza &>/dev/null || _missing+=(eza)

if (( ${#_missing} )); then
    print -P "%F{yellow}[mo-eza-override]%f missing: ${_missing[*]} (try: sudo apt install eza) — plugin not loaded"
    return 1
fi
