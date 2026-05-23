source "${0:h}/requirements.zsh" || return

typeset -g MO_TRASH_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/Trash"

alias rm="trash-put"

trash-list() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        echo "Usage: trash-list"
        echo "  Show trashed files: original path and deletion date, newest first."
        return
    fi
    command trash-list 2>/dev/null | sort -k1,2r
}

trash-restore() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        echo "Usage: trash-restore"
        echo "  fzf-pick a trashed file and restore it to its original location."
        return
    fi
    if ! command -v fzf &>/dev/null; then
        echo "trash-restore: fzf not installed (try: sudo apt install fzf)" >&2
        return 1
    fi
    local selection
    selection=$(command trash-list 2>/dev/null | fzf --prompt="Restore> " --height=40%) || return 0
    # trash-restore is interactive: it lists files and asks for a number.
    # We extract the line number from trash-list output and feed it.
    local lineno
    lineno=$(command trash-list 2>/dev/null | grep -nF "$selection" | cut -d: -f1 | head -1)
    [[ -z "$lineno" ]] && { echo "trash-restore: could not locate selection" >&2; return 1; }
    # trash-restore prompts "Restore <N>?" — answer with the index then confirm.
    echo "$lineno" | command trash-restore
}

trash-empty() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        echo "Usage: trash-empty"
        echo "  Permanently delete all files in the trash (shows size first)."
        return
    fi
    local size
    size=$(du -sh "${MO_TRASH_DIR}/files" 2>/dev/null | cut -f1)
    echo "Trash size: ${size:-0}"
    printf '%s' "Permanently delete everything in the trash? [y/N] "
    local ans
    read -r ans
    [[ "$ans" =~ ^[Yy]([Ee][Ss])?$ ]] && command trash-empty
}

trash-prune() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
        echo "Usage: trash-prune <days>"
        echo "  Remove trash entries older than <days> days."
        echo "  Example: trash-prune 30"
        return
    fi
    local days="$1"
    if [[ ! "$days" =~ ^[0-9]+$ ]]; then
        echo "trash-prune: expected a number of days, got '$days'" >&2
        return 1
    fi
    command trash-empty --trash-dir="$MO_TRASH_DIR" "$days"
}
