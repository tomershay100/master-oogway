# fzf-powered interactive functions
# All functions below are only defined if fzf is available.

command -v fzf &>/dev/null || return

############# sshto: fuzzy SSH host picker ##############
sshto()
{
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: sshto"
        echo "  Fuzzy-select a host from ~/.ssh/config and connect to it."
        return
    fi
    [[ -s "$HOME/.ssh/config" ]] || { echo "sshto: ~/.ssh/config is empty or missing" >&2; return 1; }
    local host
    host=$(awk '/^Host [^*]/{host=$2} /^[ \t]*(HostName|Port)/{val=$2; print host"\t"val}' ~/.ssh/config 2>/dev/null \
        | awk '!seen[$1]++' \
        | fzf --height=40% --reverse --header='Select SSH host' \
              --with-nth=1 --delimiter='\t' \
        | awk '{print $1}')
    [[ -n "$host" ]] && ssh "$host"
}

############# fcd: fuzzy cd ##############
fcd()
{
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: fcd [base-dir]"
        echo "  Interactively select a directory and cd into it."
        echo "  base-dir — where to search (default: current directory)"
        echo "  Preview pane shows directory contents."
        return
    fi
    local base="${1:-.}"
    local preview_cmd
    if command -v eza &>/dev/null; then
        preview_cmd='eza -1 --color=always {}'
    else
        preview_cmd='\ls -1 --color=always {}'
    fi
    local dir
    dir=$(find "$base" -type d 2>/dev/null \
        | grep -v '\.git' \
        | fzf --height=40% --reverse --preview-window=right:60%:wrap --preview "$preview_cmd") \
    && cd "$dir"
}

############# fkill: fuzzy process kill ##############
fkill()
{
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: fkill [signal]"
        echo "  Interactively select one or more processes to kill."
        echo "  signal — signal to send (default: -15 SIGTERM)"
        echo "  Examples:"
        echo "    fkill        — send SIGTERM"
        echo "    fkill -9     — send SIGKILL (force)"
        echo "  Tip: use TAB to select multiple processes."
        return
    fi
    local sig="${1:--15}"
    local pids
    pids=$(ps -ef \
        | sed 1d \
        | fzf -m --height=40% --reverse --header='Select process(es) to kill  [TAB = multi-select]' \
        | awk '{print $2}')
    [[ -z "$pids" ]] && return
    echo "$pids" | xargs kill "$sig"
}

############# flog: fuzzy git log — browse commits, copy hash ##############
flog()
{
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: flog"
        echo "  Interactively browse git log and copy the selected commit hash."
        echo "  Preview pane shows the commit diff stat."
        echo "  Copies hash to clipboard (xclip), or prints it if xclip is unavailable."
        return
    fi
    local hash
    hash=$(git log --oneline --color=always 2>/dev/null \
        | fzf --ansi --height=60% --reverse \
              --preview 'git show --color=always --stat {1}' \
              --preview-window=right:60% \
        | awk '{print $1}')
    [[ -z "$hash" ]] && return
    if command -v xclip &>/dev/null; then
        echo -n "$hash" | xclip -selection clipboard
        echo "Copied: $hash"
    else
        echo "$hash"
    fi
}

############# fpath: fuzzy file search — copy path to clipboard ##############
fpath()
{
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: fpath [base-dir]"
        echo "  Interactively select a file and copy its full path to clipboard."
        echo "  base-dir — where to search (default: current directory)"
        echo "  Preview pane shows file contents."
        echo "  Copies path to clipboard (xclip), or prints it if xclip is unavailable."
        return
    fi
    local base="${1:-.}"
    local preview_cmd
    if command -v bat &>/dev/null; then
        preview_cmd='bat --color=always --style=plain {}'
    elif command -v batcat &>/dev/null; then
        preview_cmd='batcat --color=always --style=plain {}'
    else
        preview_cmd='cat {}'
    fi
    local file
    file=$(find "$base" -type f 2>/dev/null \
        | grep -v '\.git' \
        | fzf --height=40% --reverse --preview-window=right:60%:wrap --preview "$preview_cmd") \
    || return
    local fullpath="${file:a}"  # resolve to absolute path
    if command -v xclip &>/dev/null; then
        echo -n "$fullpath" | xclip -selection clipboard
        echo "Copied: $fullpath"
    else
        echo "$fullpath"
    fi
}

############# fbranch: fuzzy git branch checkout ##############
fbranch()
{
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: fbranch"
        echo "  Fuzzy-select a git branch and switch to it."
        return
    fi
    local branch
    branch=$(git branch -a --color=always 2>/dev/null \
        | grep -v '\->' \
        | fzf --ansi --height=40% --reverse \
              --preview 'git log --oneline --color=always {-1} | head -20') \
    && git switch "${branch##* }"
}

############# fhist: fuzzy history — put selected command into buffer ##############
fhist()
{
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: fhist"
        echo "  Fuzzy-select a past command and put it in the readline buffer."
        return
    fi
    local cmd
    cmd=$(fc -ln 1 | fzf --tac --height=40% --reverse --no-sort)
    [[ -n "$cmd" ]] && print -z "$cmd"
}

############# fman: fuzzy man page browser ##############
fman()
{
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: fman"
        echo "  Fuzzy-select a man page and open it."
        return
    fi
    local page
    page=$(man -k '' 2>/dev/null \
        | fzf --height=50% --reverse --preview 'man {1}' \
        | awk '{print $1}')
    [[ -n "$page" ]] && man "$page"
}

############# frg: fuzzy ripgrep — search file contents and open in editor ##############
frg()
{
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: frg"
        echo "  Fuzzy search file contents with ripgrep and open result in \$EDITOR."
        return
    fi
    command -v rg &>/dev/null || { echo "frg: rg not installed" >&2; return 1; }
    local result
    result=$(rg --color=always --line-number "" 2>/dev/null \
        | fzf --ansi --height=60% --reverse \
              --delimiter ':' --nth='1,3..' \
              --preview 'bat --color=always --highlight-line {2} {1} 2>/dev/null || cat {1}')
    [[ -n "$result" ]] && ${EDITOR:-vim} "$(cut -d: -f1 <<< "$result")" "+$(cut -d: -f2 <<< "$result")"
}

############# fenv: fuzzy search, print, or edit env var ##############
fenv()
{
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: fenv [-e | -E]"
        echo "  Interactively search environment variables."
        echo "  (no flag)  — print the selected variable"
        echo "  -e         — edit value inline (prompted in terminal)"
        echo "  -E         — edit value in \$EDITOR ($EDITOR)"
        return
    fi

    local mode="print"
    if [[ "$1" == "-e" ]]; then
        mode="inline"
    elif [[ "$1" == "-E" ]]; then
        mode="editor"
    fi

    local selection
    selection=$(env | sort | fzf --height=40% --reverse)
    [[ -z "$selection" ]] && return

    local var_name="${selection%%=*}"
    local var_value="${selection#*=}"

    if [[ "$mode" == "print" ]]; then
        echo "$selection"
        return
    fi

    local new_value
    if [[ "$mode" == "inline" ]]; then
        echo "Current: $var_name=$var_value"
        echo -n "New value: "
        read -r new_value
    elif [[ "$mode" == "editor" ]]; then
        local tmpfile
        tmpfile=$(mktemp)
        echo "$var_value" > "$tmpfile"
        ${EDITOR:-vim} "$tmpfile"
        new_value=$(command cat "$tmpfile")
        rm -f "$tmpfile"
    fi

    export "${var_name}=${new_value}"
    echo "Exported: $var_name=$new_value"
}
