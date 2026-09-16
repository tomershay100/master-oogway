# Hard dep — plugin does not load without a trash tool, so `rm` stays intact.
# trash-cli on Linux, /usr/bin/trash (macOS 14+) on macOS.
local _missing=()
[[ -n "$(_mo_trash_tool)" ]] || _missing+=(trash-cli)

if (( ${#_missing} )); then
	print -P "%F{yellow}[mo-trash]%f missing: ${_missing[*]} (try: $(_mo_pkg_hint trash-cli)) — plugin not loaded" >&2
	return 1
fi
