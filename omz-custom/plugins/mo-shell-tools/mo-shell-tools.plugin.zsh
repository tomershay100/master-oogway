
alias h="history 50"                              # last 50 history entries

'?'() { echo $?; }                                # print exit code of the last command

# cat the source of a command — prefers bat/batcat for syntax highlighting if installed.
cwhich() {
    local target
    target="$(whence -p "$1")" || { echo "cwhich: '$1' not found as a file" >&2; return 1; }
    if command -v batcat &>/dev/null; then
        batcat "$target"
    elif command -v bat &>/dev/null; then
        bat "$target"
    else
        cat "$target"
    fi
}

vwhich() {
    local target
    target="$(whence -p "$1")" || { echo "vwhich: '$1' not found as a file" >&2; return 1; }
    ${EDITOR:-vim} "$target"
}

alias vizsh='${EDITOR:-vim} ~/.zshrc'             # open ~/.zshrc in $EDITOR
alias soursh="source ~/.zshrc"                    # reload ~/.zshrc

# Measure interactive zsh startup time over N runs (default 5).
# Uses `time` built-in to capture real elapsed time per run, then prints
# all "total" lines so the user can see variance across runs.
zshtime() {
    local n="${1:-5}"
    if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n < 1 )); then
        echo "Usage: zshtime [runs]  (default: 5)" >&2
        return 1
    fi
    echo "Measuring zsh startup time (${n} run$(( n == 1 ? 0 : 1 ))s)..."
    local i
    for (( i = 1; i <= n; i++ )); do
        { time zsh -i -c exit } 2>&1
    done | grep real
}
# Re-run the previous command with sudo.
# Uses ${(Q)${(z)...}} to split the history line into words respecting
# quoting (e.g. grep "hello world" file stays three args, not four).
# Strips a leading 'sudo' if the last command already had one.
# Find which mo-* plugin defines a command (alias or function).
# Prints plugin:line: content — e.g. "mo-git:12: alias gs='git status'"
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
