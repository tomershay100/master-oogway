# Hard deps — plugin does not load if fzf is absent.
local _missing=()
command -v fzf &>/dev/null || _missing+=(fzf)

if (( ${#_missing} )); then
	print -P "%F{yellow}[mo-search]%f missing: ${_missing[*]} (try: sudo apt install fzf) — plugin not loaded"
	return 1
fi
