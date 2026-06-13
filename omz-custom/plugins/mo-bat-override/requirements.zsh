# Hard deps — plugin does not load if none of these are present.
local _missing=()
command -v bat    &>/dev/null || command -v batcat &>/dev/null || _missing+=(bat)

if (( ${#_missing} )); then
	print -P "%F{yellow}[mo-bat-override]%f missing: ${_missing[*]} (try: sudo apt install bat) — plugin not loaded"
	return 1
fi
