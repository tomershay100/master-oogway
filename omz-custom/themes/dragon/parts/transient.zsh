_DRAGON_JUST_CHANGED_DIR=false

__dragon_track_chpwd()
{
	_DRAGON_JUST_CHANGED_DIR=true
}

__dragon_zle_line_finish()
{
	local mode="$DRAGON__ENABLE_TRANSIENT_PROMPT"
	[[ "$mode" == "false" ]] && return

	if [[ "$mode" == "per-dir" ]]; then
		if [[ "$_DRAGON_JUST_CHANGED_DIR" == "true" ]]; then
			# First command after a directory change — keep the full prompt visible
			_DRAGON_JUST_CHANGED_DIR=false
			return
		fi
	fi

	local char="${DRAGON__TRANSIENT_PROMPT_CHAR:-$DRAGON__PROMPT_CHAR}"
	[[ -z "$char" ]] && return

	# _DRAGON_EXIT_CODE is set by __save_exit_code in the previous precmd cycle — it holds
	# the exit code of the last command, which is the same value the current full
	# prompt is already colored with. So we get the correct green/red here.
	local fg bg bold underline
	if $DRAGON__ENABLE_EXIT_STATUS_PROMPT_COLORING && [[ "$_DRAGON_EXIT_CODE" -eq 0 ]]; then
		fg="$DRAGON__PROMPT_CHAR_SUCCESS_FOREGROUND_COLOR"
		bg="$DRAGON__PROMPT_CHAR_SUCCESS_BACKGROUND_COLOR"
		bold="$DRAGON__PROMPT_CHAR_SUCCESS_BOLD"
		underline="$DRAGON__PROMPT_CHAR_SUCCESS_UNDERLINE"
	elif $DRAGON__ENABLE_EXIT_STATUS_PROMPT_COLORING; then
		fg="$DRAGON__PROMPT_CHAR_FAILURE_FOREGROUND_COLOR"
		bg="$DRAGON__PROMPT_CHAR_FAILURE_BACKGROUND_COLOR"
		bold="$DRAGON__PROMPT_CHAR_FAILURE_BOLD"
		underline="$DRAGON__PROMPT_CHAR_FAILURE_UNDERLINE"
	else
		fg="$DRAGON__PROMPT_CHAR_DEFAULT_FOREGROUND_COLOR"
		bg="$DRAGON__PROMPT_CHAR_DEFAULT_BACKGROUND_COLOR"
		bold="$DRAGON__PROMPT_CHAR_DEFAULT_BOLD"
		underline="$DRAGON__PROMPT_CHAR_DEFAULT_UNDERLINE"
	fi
	__get_xterm_style_format "$fg" "$bg" "$bold" "$underline"

	PROMPT="$RESET_FORMAT$STYLE_FORMAT${char//\%/%%}${DRAGON__PROMPT_CHAR_SUFFIX//\%/%%}$RESET_FORMAT"

	if $DRAGON__TRANSIENT_PROMPT_VERBOSE; then
		# Reuse the rprompt computed during precmd — timer is already reset by this
		# point so recomputing would lose the exec time; the saved value is accurate.
		RPROMPT="$_DRAGON_SAVED_RPROMPT"
	else
		RPROMPT=""
	fi

	zle reset-prompt
}
