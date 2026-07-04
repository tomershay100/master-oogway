# Remove this file to use the system cat and less as-is.

source "${0:h}/requirements.zsh" || return

: "${BAT_THEME:=Coldark-Dark}"  # `bat --list-themes` to see options; set BAT_THEME before loading to override
export BAT_THEME

_bat_cmd=""
command -v bat    &>/dev/null && _bat_cmd="bat"
command -v batcat &>/dev/null && _bat_cmd="${_bat_cmd:-batcat}"

if [[ -n "$_bat_cmd" ]]; then
	if command -v col &>/dev/null; then
		export MANPAGER="sh -c \"col -bx | ${_bat_cmd} -l man -p\""
		export MANROFFOPT="-c"
	fi

	alias cat="${_bat_cmd} --paging never --style=plain"
	alias pcat="cat --style=full"                             # pretty: headers, line numbers, git markers

	alias less="${_bat_cmd} --paging always --style=plain"
	alias pless="less --style=full"                           # pretty paged: headers, line numbers, grid, git markers
fi
unset _bat_cmd
