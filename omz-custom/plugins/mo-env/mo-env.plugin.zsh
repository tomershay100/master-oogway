
fenv() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: fenv [-e | -E]"
		echo "  Interactively search environment variables."
		echo "  (no flag)  — print the selected variable"
		echo "  -e         — edit value inline (prompted in terminal)"
		echo "  -E         — edit value in \$EDITOR ($EDITOR)"
		return
	fi
	command -v fzf &>/dev/null || { echo "fenv: fzf not installed" >&2; return 1; }
	local mode="print"
	[[ "$1" == "-e" ]] && mode="inline"
	[[ "$1" == "-E" ]] && mode="editor"
	local selection
	selection=$(env | sort | fzf --height=40% --reverse)
	[[ -z "$selection" ]] && return
	local var_name="${selection%%=*}"
	local var_value="${selection#*=}"
	if [[ "$mode" == "print" ]]; then
		echo "$selection"
		return
	fi
	local new_value
	if [[ "$mode" == "inline" ]]; then
		echo "Current: $var_name=$var_value"
		echo -n "New value: "
		read -r new_value
	elif [[ "$mode" == "editor" ]]; then
		local tmpfile tmpdir
		# XDG_RUNTIME_DIR is a per-user tmpfs cleared on logout — safer than /tmp
		# for secrets. Fall back to /tmp if unset (non-systemd environments).
		tmpdir="${XDG_RUNTIME_DIR:-/tmp}"
		tmpfile=$(mktemp -p "$tmpdir")
		echo "$var_value" > "$tmpfile"
		${EDITOR:-vim} "$tmpfile"
		new_value=$(command cat "$tmpfile")
		rm -f "$tmpfile"
	fi
	export "${var_name}=${new_value}"
	echo "Exported: $var_name=$new_value"
}
