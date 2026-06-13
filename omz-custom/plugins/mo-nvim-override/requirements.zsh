# Hard deps — plugin does not load if none of these are present.
local _missing=()
command -v nvim &>/dev/null || _missing+=(neovim)

if (( ${#_missing} )); then
	print -P "%F{yellow}[mo-nvim-override]%f missing: ${_missing[*]} (try: sudo apt install neovim) — plugin not loaded"
	return 1
fi
