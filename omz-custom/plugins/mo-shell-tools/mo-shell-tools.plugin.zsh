
alias h="history 50"

'?'() { echo $?; }

cwhich() {
    local target
    target="$(whence -p "$1")" || { echo "cwhich: '$1' not found as a file" >&2; return 1; }
    if command -v bat &>/dev/null; then
        bat "$target"
    elif command -v batcat &>/dev/null; then
        batcat "$target"
    else
        cat "$target"
    fi
}

vwhich() {
    local target
    target="$(whence -p "$1")" || { echo "vwhich: '$1' not found as a file" >&2; return 1; }
    ${EDITOR:-vim} "$target"
}

clip() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        echo "Usage: <command> | clip"
        echo "  Copy stdin to the system clipboard."
        return
    fi
    local data
    data=$(command cat)
    if command -v wl-copy &>/dev/null; then
        printf '%s' "$data" | wl-copy
    elif command -v xclip &>/dev/null; then
        printf '%s' "$data" | xclip -selection clipboard
    else
        echo "clip: no clipboard tool found (try: sudo apt install wl-clipboard)" >&2
        printf '%s\n' "$data"
        return 1
    fi
    local bytes=${#data}
    local unit; (( bytes == 1 )) && unit="byte" || unit="bytes"
    echo "Copied ${bytes} ${unit} to clipboard." >&2
}

vizsh() { ${EDITOR:-vim} ~/.zshrc; }
alias soursh="source ~/.zshrc"

mo-where() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
        echo "Usage: mo-where <name>"
        echo "  Show which mo-* plugin defines <name> as an alias or function."
        return
    fi
    local name="$1"
    local dir="${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins"
    local found=0 f plugin match
    for f in "${dir}"/mo-*/*.plugin.zsh(N); do
        plugin="${f:h:t}"
        while IFS= read -r match; do
            printf "%s:%s\n" "$plugin" "$match"
            found=1
        done < <(grep -nE \
            "^alias ['\"]?${name}['\"]?=|^function ${name}([^a-zA-Z0-9_]|$)|^${name}[[:space:]]*\(\)" \
            "$f" 2>/dev/null)
    done
    (( found == 0 )) && { echo "mo-where: '${name}' not found in any mo-* plugin" >&2; return 1; }
}

calc() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        echo "Usage: calc <expression>"
        echo "  Evaluate a math expression using bc -l."
        echo "  Examples:"
        echo "    calc '2 ^ 10'"
        echo "    calc 'sqrt(2)'"
        echo "    calc 's(3.14159/4)'   # sin"
        return
    fi
    if [[ $# -eq 0 ]]; then
        echo "Usage: calc <expression>  (use -h for details)" >&2
        return 1
    fi
    command -v bc &>/dev/null || { echo "calc: bc not installed" >&2; return 1; }
    local expr="$*"
    if [[ ! "$expr" =~ '^[-0-9a-zA-Z_ +*/^().,%]+$' ]]; then
        echo "calc: expression contains invalid characters" >&2
        return 1
    fi
    bc -l <<< "$expr"
}

epoch() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        echo "Usage: epoch [timestamp | date-string]"
        echo "  (no args)         — print current unix timestamp"
        echo "  epoch 1700000000  — convert unix timestamp to human-readable date"
        echo "  epoch 'yesterday' — convert date string to unix timestamp"
        return
    fi
    if [[ $# -eq 0 ]]; then
        date +%s
    elif [[ "$1" =~ '^[0-9]+$' ]]; then
        date -d "@$1"
    else
        date -d "$*" +%s
    fi
}

# ${(Q)${(z)...}} splits respecting quoting; strips leading 'sudo' if already present.
please() {
    local last
    last=$(fc -ln -1 2>/dev/null)
    [[ -z "$last" ]] && { echo "please: no previous command" >&2; return 1; }
    local -a cmd
    cmd=( ${(Q)${(z)last}} )
    [[ "${cmd[1]:-}" == "sudo" ]] && cmd=( "${cmd[@]:1}" )
    [[ ${#cmd[@]} -eq 0 ]] && { echo "please: no command to run" >&2; return 1; }
    sudo "${cmd[@]}"
}
