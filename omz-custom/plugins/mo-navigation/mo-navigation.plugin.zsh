# Provides: directory navigation helpers — mkcd, up, tmpcd, fcd.
# Requires: fcd also requires fzf (skipped with an error if not installed).

function mkcd() {
    if [[ "$1" == "-h" || "$1" == "--help" || $# -eq 0 ]]; then
        echo "Usage: mkcd <dir>"
        echo "  Create <dir> (including parents) and cd into it."
        return
    fi
    mkdir -p "$1" && cd "$1"
}

function up() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: up [n | dirname]"
        echo "  up          — go up one level (same as cd ..)"
        echo "  up 3        — go up 3 levels"
        echo "  up src      — go up to the nearest ancestor named 'src'"
        return
    fi
    if [[ $# -eq 0 ]]; then
        cd ..
        return
    fi
    if [[ "$1" =~ '^[0-9]+$' ]]; then
        local uppath=""
        for (( i = 0; i < $1; i++ )); do uppath+="../"; done
        cd "$uppath"
        return
    fi
    local dir=$PWD
    while [[ "$dir" != "/" ]]; do
        dir=$(dirname "$dir")
        if [[ "$(basename "$dir")" == "$1" ]]; then
            cd "$dir"
            return
        fi
    done
    echo "up: '$1' not found in path" >&2
    return 1
}

function tmpcd() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: tmpcd"
        echo "  Create a temporary directory and cd into it."
        echo "  Prints the path so you know where you are."
        return
    fi
    local d
    d=$(mktemp -d) && cd "$d" && echo "$d"
}

fcd() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: fcd [base-dir]"
        echo "  Interactively select a directory and cd into it."
        echo "  base-dir — where to search (default: current directory)"
        echo "  Preview pane shows directory contents."
        echo "  Tip: ALT+C (fzf plugin) does the same from any prompt."
        return
    fi
    _mo_require fzf fcd || return
    local base="${1:-.}"
    local preview_cmd
    if command -v eza &>/dev/null; then
        preview_cmd='eza -1 --color=always {}'
    else
        preview_cmd='\ls -1 --color=always {}'
    fi
    local dir
    # fzf substitutes {} into the preview shell literally — a dir named
    # ';rm -rf;' would execute on cursor-move. Filter unsafe names out
    # before they reach fzf (same defense as fbranch in mo-git).
    dir=$(find "$base" -type d 2>/dev/null \
        | grep -v '\.git' \
        | grep -vF -e '$' -e '`' -e '(' -e ')' -e ';' -e '|' -e '&' -e '<' -e '>' -e '"' -e "'" -e '\' \
        | fzf --height=40% --reverse --preview-window=right:60%:wrap --preview "$preview_cmd") \
    && cd "$dir"
}
