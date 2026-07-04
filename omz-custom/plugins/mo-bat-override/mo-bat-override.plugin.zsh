# Remove this file to use the system cat and less as-is.

source "${0:h}/requirements.zsh" || return

: "${BAT_THEME:=Coldark-Dark}"  # `bat --list-themes` to see options; set BAT_THEME before loading to override
export BAT_THEME

# Persist as a global — the cat/less functions read it at invocation time, not load time.
_MO_BAT_CMD=""
command -v bat    &>/dev/null && _MO_BAT_CMD="bat"
command -v batcat &>/dev/null && _MO_BAT_CMD="${_MO_BAT_CMD:-batcat}"

if [[ -n "$_MO_BAT_CMD" ]]; then
	if command -v col &>/dev/null; then
		export MANPAGER="sh -c \"col -bx | ${_MO_BAT_CMD} -l man -p\""
		export MANROFFOPT="-c"
	fi

	# bat can't emulate `cat -A/-v/-e/-t` (show non-printing chars) — fall back to real cat.
	cat() {
		local arg
		for arg in "$@"; do
			[[ "$arg" == -*[Avet]* ]] && { command cat "$@"; return; }
		done
		command "$_MO_BAT_CMD" --paging never --style=plain "$@"
	}
	alias pcat="command \"$_MO_BAT_CMD\" --paging never --style=full"   # pretty: headers, line numbers, git markers

	# bat can't emulate `less +F/+G/…` (position commands) — fall back to real less.
	less() {
		local arg
		for arg in "$@"; do
			[[ "$arg" == +* ]] && { command less "$@"; return; }
		done
		command "$_MO_BAT_CMD" --paging always --style=plain "$@"
	}
	alias pless="command \"$_MO_BAT_CMD\" --paging always --style=full" # pretty paged: headers, line numbers, grid, git markers
fi
