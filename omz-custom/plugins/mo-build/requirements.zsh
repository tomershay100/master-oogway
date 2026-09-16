# Hard deps — plugin does not load if make is absent.
local _missing=()
command -v make &>/dev/null || _missing+=(make)

if (( ${#_missing} )); then
	print -P "%F{yellow}[mo-build]%f missing: ${_missing[*]} (try: $(_mo_pkg_hint build-essential)) — plugin not loaded" >&2
	return 1
fi
