mo-man() {
    if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        echo "Usage: mo-man <plugin>"
        echo "  Open the README of a mo-* plugin."
        echo "  Accepts short name (git) or full name (mo-git)."
        echo ""
        echo "Examples:"
        echo "  mo-man git"
        echo "  mo-man mo-files"
        return
    fi

    local name="mo-${1#mo-}"
    local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/${name}"
    local readme="${plugin_dir}/README.md"

    if [[ ! -d "$plugin_dir" ]]; then
        echo "mo-man: plugin '${name}' not found in ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/" >&2
        return 1
    fi
    if [[ ! -f "$readme" ]]; then
        echo "mo-man: no README.md for '${name}'" >&2
        return 1
    fi

    if command -v bat &>/dev/null; then
        bat --style=plain --language=markdown "$readme"
    elif command -v batcat &>/dev/null; then
        batcat --style=plain --language=markdown "$readme"
    else
        less "$readme"
    fi
}
