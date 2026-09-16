# Hard deps — every command here wraps brew, which is macOS-only in practice.
local _missing=()
if ! _mo_is_macos; then
	# Silent on Linux: this plugin is simply not applicable there, and a
	# warning on every shell start would be noise.
	return 1
fi
command -v brew &>/dev/null || _missing+=(brew)

if (( ${#_missing} )); then
	print -P "%F{yellow}[mo-brew]%f missing: ${_missing[*]} (install from https://brew.sh) — plugin not loaded" >&2
	return 1
fi
