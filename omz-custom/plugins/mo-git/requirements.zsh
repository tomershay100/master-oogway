# Hard deps — plugin does not load if git is absent.
local _missing=()
command -v git &>/dev/null || _missing+=(git)

if (( ${#_missing} )); then
	print -P "%F{yellow}[mo-git]%f missing: ${_missing[*]} (try: $(_mo_pkg_hint git)) — plugin not loaded" >&2
	return 1
fi
