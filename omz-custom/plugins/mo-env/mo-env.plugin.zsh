
fenv() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: fenv [-e | -E | -c]"
		echo "  Interactively search environment variables."
		echo "  (no flag)  — print the selected variable"
		echo "  -c         — copy the selected value to the clipboard"
		echo "  -e         — edit value inline (prompted in terminal)"
		echo "  -E         — edit value in \$EDITOR ($EDITOR)"
		return
	fi
	command -v fzf &>/dev/null || { echo "fenv: fzf not installed" >&2; return 1; }
	local mode="print"
	[[ "${1:-}" == "-c" ]] && mode="copy"
	[[ "${1:-}" == "-e" ]] && mode="inline"
	[[ "${1:-}" == "-E" ]] && mode="editor"
	local selection
	# env -0 emits NUL-separated records so values containing newlines don't
	# split into bogus entries; strip trailing NUL, sort NUL-delimited, feed
	# fzf on NUL boundaries. Fall back to plain env when env -0 is unavailable.
	if env -0 </dev/null &>/dev/null; then
		selection=$(env -0 | sort -z | fzf --height=40% --reverse --read0)
	else
		echo "fenv: env -0 unavailable — multiline values may render incorrectly" >&2
		selection=$(env | sort | fzf --height=40% --reverse)
	fi
	[[ -z "$selection" ]] && return
	local var_name="${selection%%=*}"
	local var_value="${selection#*=}"
	if [[ "$mode" == "print" ]]; then
		print -r -- "$selection"
		return
	fi
	if [[ "$mode" == "copy" ]]; then
		if command -v xclip &>/dev/null; then
			print -rn -- "$var_value" | xclip -selection clipboard
		elif command -v xsel &>/dev/null; then
			print -rn -- "$var_value" | xsel --clipboard --input
		else
			echo "fenv: neither xclip nor xsel installed" >&2
			return 1
		fi
		echo "Copied $var_name to clipboard"
		return
	fi
	local new_value
	if [[ "$mode" == "inline" ]]; then
		print -r -- "Current: $var_name=$var_value"
		echo -n "New value: "
		read -r new_value
	elif [[ "$mode" == "editor" ]]; then
		local tmpfile tmpdir
		# XDG_RUNTIME_DIR is a per-user tmpfs cleared on logout — safer than /tmp
		# for secrets. Fall back to /tmp if unset (non-systemd environments).
		tmpdir="${XDG_RUNTIME_DIR:-/tmp}"
		tmpfile=$(mktemp -p "$tmpdir")
		print -r -- "$var_value" > "$tmpfile"
		${EDITOR:-vim} "$tmpfile"
		new_value=$(command cat "$tmpfile")
		# `command rm` so a secrets temp file is really deleted, not sent to a
		# trash can by an `rm`→trash-put alias.
		command rm -f "$tmpfile"
	fi
	export "${var_name}=${new_value}"
	print -r -- "Exported: $var_name=$new_value"
}
