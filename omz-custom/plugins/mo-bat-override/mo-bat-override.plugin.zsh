# Remove this file to use the system cat and less as-is.

source "${0:h}/requirements.zsh" || return

export BAT_THEME='Coldark-Dark'  # `bat --list-themes` to see options

if command -v batcat &>/dev/null; then
    _bat_cmd="batcat"
elif command -v bat &>/dev/null; then
    _bat_cmd="bat"
fi

if [[ -n "${_bat_cmd:-}" ]]; then
    export MANPAGER="sh -c \"col -bx | ${_bat_cmd} -l man -p\""

    alias cat="${_bat_cmd} --paging never --style=plain"
    alias pcat="cat --style=full"                             # pretty: headers, line numbers, git markers

    alias less="${_bat_cmd} --paging always --style=plain"
    alias pless="less --style=full"                           # pretty paged: headers, line numbers, grid, git markers
fi
unset _bat_cmd
