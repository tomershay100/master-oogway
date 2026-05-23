# Hard deps — plugin does not load if ssh is absent.
local _missing=()
command -v ssh &>/dev/null || _missing+=(openssh-client)

if (( ${#_missing} )); then
    print -P "%F{yellow}[mo-lan-ssh]%f missing: ${_missing[*]} (try: sudo apt install openssh-client) — plugin not loaded"
    return 1
fi
