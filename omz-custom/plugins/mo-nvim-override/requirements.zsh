# Hard deps — plugin does not load if none of these are present.
local _missing=()
command -v nvim &>/dev/null || _missing+=(neovim)

if (( ${#_missing} )); then
	print -P "%F{yellow}[mo-nvim-override]%f missing: ${_missing[*]} (try: $(_mo_pkg_hint neovim)) — plugin not loaded" >&2
	return 1
fi
