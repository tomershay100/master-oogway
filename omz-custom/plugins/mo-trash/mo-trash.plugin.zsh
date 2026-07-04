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
	# trash-list prints "DATE TIME /original/path"; fzf picks one line and we
	# pull its original path (fields 3+, may contain spaces). We can't reuse
	# trash-list's own line number: `command trash-restore` builds its OWN
	# 0-based, cwd-scoped, date-sorted candidate list, so any index from here
	# points at the wrong file. Instead we scope trash-restore to the exact
	# path — that yields a one-entry list where index 0 is unambiguous.
	local selection path
	selection=$(command trash-list 2>/dev/null | fzf --prompt="Restore> " --height=40%) || return 0
	path=$(printf '%s\n' "$selection" | awk '{ $1=""; $2=""; sub(/^  /, ""); print }')
	[[ -z "$path" ]] && { echo "trash-restore: could not locate selection" >&2; return 1; }
	echo 0 | command trash-restore "$path"
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
