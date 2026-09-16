
# oh-my-zsh does not source $ZSH_CUSTOM/lib; nor does a zshrc seeded before it.
[[ -n ${_MO_PLATFORM_LOADED-} ]] || source "${0:h}/../../lib/platform.zsh"

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
		_mo_clip "$var_value" || { echo "fenv: could not copy to clipboard" >&2; return 1; }
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
		# A per-user runtime dir, not /tmp: XDG_RUNTIME_DIR on Linux, TMPDIR
		# (0700, under /var/folders) on macOS. Reading XDG_RUNTIME_DIR
		# directly fell through to /tmp on macOS — the exact thing this
		# comment says to avoid.
		# for secrets. Fall back to /tmp if unset (non-systemd environments).
		tmpdir="$(_mo_runtime_dir)"
		tmpfile=$(mktemp -p "$tmpdir")
		print -r -- "$var_value" > "$tmpfile"
		# Split on words: zsh does not word-split an unquoted parameter, so
		# EDITOR="code -w" was looked up as one command name, the edit never
		# happened, and the OLD value was exported with status 0.
		local -a _ed=( ${(z)${EDITOR:-vim}} )
		"${_ed[@]}" "$tmpfile" || {
			echo "fenv: editor failed: ${_ed[*]}" >&2
			command rm -f "$tmpfile"
			return 1
		}
		new_value=$(command cat "$tmpfile")
		# `command rm` so a secrets temp file is really deleted, not sent to a
		# trash can by the `rm` alias mo-trash installs.
		command rm -f "$tmpfile"
	fi
	export "${var_name}=${new_value}"
	print -r -- "Exported: $var_name=$new_value"
}
