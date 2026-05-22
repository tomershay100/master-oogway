# Remove this file to use the system cat and less as-is.

if command -v batcat &>/dev/null; then
    _bat_cmd="batcat"
elif command -v bat &>/dev/null; then
    _bat_cmd="bat"
fi

if [[ -n "${_bat_cmd:-}" ]]; then
    alias rcat='\cat'   # escape hatch: rcat bypasses this override
    alias cat="${_bat_cmd} --theme Coldark-Dark --paging never --style=plain"
    alias pcat="cat --style=full"    # p = "pretty": adds headers, line numbers, and git diff markers

    alias rless='\less'  # escape hatch: rless bypasses this override
    alias less="${_bat_cmd} --theme Coldark-Dark --paging always"
    alias pless="less --style=plain" # p = "paged plain": bat pager without decorations
fi
unset _bat_cmd
