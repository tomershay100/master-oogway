# Provides: shell inspection and config helpers — h, ?, cwhich, vwhich, vizsh, soursh, zshtime, please (re-run last cmd with sudo).

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
