# Shared clipboard helper — write a string to the system clipboard.
# Sourced by oh-my-zsh before any plugin; callers don't need to import it.
# Returns 1 (and prints to stderr) when no clipboard tool is found.
_mo_clip() {
	local data="${1}"
	if command -v wl-copy &>/dev/null; then
		printf '%s' "$data" | wl-copy
	elif command -v xclip &>/dev/null; then
		printf '%s' "$data" | xclip -selection clipboard
	else
		echo "_mo_clip: no clipboard tool found (try: sudo apt install wl-clipboard)" >&2
		return 1
	fi
}
