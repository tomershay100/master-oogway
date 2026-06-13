# Hard deps — plugin does not load if git is absent.
local _missing=()
command -v git &>/dev/null || _missing+=(git)

if (( ${#_missing} )); then
	print -P "%F{yellow}[mo-git]%f missing: ${_missing[*]} (try: sudo apt install git) — plugin not loaded"
	return 1
fi
