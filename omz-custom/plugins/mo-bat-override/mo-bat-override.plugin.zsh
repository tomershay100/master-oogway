# Remove this file to use the system cat and less as-is.

source "${0:h}/requirements.zsh" || return

: "${BAT_THEME:=Coldark-Dark}"  # `bat --list-themes` to see options; set BAT_THEME before loading to override
export BAT_THEME

# _MO_OPT_BIN[bat] holds the real command name (bat or batcat), set by optdeps.zsh.
if [[ -n "${_MO_OPT_BIN[bat]:-}" ]]; then
    _bat_cmd="${_MO_OPT_BIN[bat]}"
    export MANPAGER="sh -c \"col -bx | ${_bat_cmd} -l man -p\""

    alias cat="${_bat_cmd} --paging never --style=plain"
    alias pcat="cat --style=full"                             # pretty: headers, line numbers, git markers

    alias less="${_bat_cmd} --paging always --style=plain"
    alias pless="less --style=full"                           # pretty paged: headers, line numbers, grid, git markers
    unset _bat_cmd
fi
