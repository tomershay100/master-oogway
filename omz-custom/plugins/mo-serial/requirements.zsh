# Hard deps — plugin does not load if minicom is absent.
local _missing=()
command -v minicom &>/dev/null || _missing+=(minicom)

if (( ${#_missing} )); then
	print -P "%F{yellow}[mo-serial]%f missing: ${_missing[*]} (try: $(_mo_pkg_hint minicom)) — plugin not loaded" >&2
	return 1
fi
