
mkcd() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
		echo "Usage: mkcd <dir>"
		echo "  Create <dir> (including parents) and cd into it."
		return
	fi
	command mkdir -p "$1" && cd "$1"
}

up() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
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

tmpcd() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: tmpcd"
		echo "  Create a temporary directory and cd into it."
		echo "  Prints the path so you know where you are."
		return
	fi
	local d
	d=$(mktemp -d) && cd "$d" && echo "$d"
}

_mo_dirs_fd=""
command -v fd     &>/dev/null && _mo_dirs_fd="fd"
command -v fdfind &>/dev/null && _mo_dirs_fd="${_mo_dirs_fd:-fdfind}"

if [[ -n "$_mo_dirs_fd" ]]; then
	export FZF_ALT_C_COMMAND="${_mo_dirs_fd} --type d --hidden --strip-cwd-prefix --exclude .git"
fi

fcd() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: fcd [base-dir]"
		echo "  Interactively select a directory and cd into it."
		echo "  base-dir — where to search (default: current directory)"
		echo "  Preview pane shows directory contents."
		echo "  Tip: ALT+C (fzf plugin) does the same from any prompt."
		return
	fi
	command -v fzf &>/dev/null || { echo "fcd: fzf not installed" >&2; return 1; }
	local base="${1:-.}"
	local preview_cmd
	if command -v eza &>/dev/null; then
		preview_cmd='eza -1 --color=always {}'
	else
		preview_cmd='\ls -1 --color=always {}'
	fi
	local dir
	if [[ -n "$_mo_dirs_fd" ]]; then
		dir=$("$_mo_dirs_fd" --type d --hidden --exclude .git . "$base" 2>/dev/null \
			| fzf --height=40% --reverse --preview-window=right:60%:wrap --preview "$preview_cmd")
	else
		dir=$(find "$base" -type d -not -path '*/.git/*' -print0 2>/dev/null \
			| fzf --read0 --height=40% --reverse --preview-window=right:60%:wrap --preview "$preview_cmd")
	fi
	[[ -n "$dir" ]] && cd "$dir"
}

function n() {
	command -v xdg-open &>/dev/null \
		|| { echo "n: xdg-open not found (install xdg-utils)" >&2; return 1; }
	xdg-open .
}
