__set_separator_parameters()
{
	REAL_DRAGON__PROMPT_SEPARATOR_PREFIX=""
	REAL_DRAGON__PROMPT_SEPARATOR_SUFFIX=""
	REAL_DRAGON__PROMPT_SEPARATOR_FOREGROUND_COLOR="$DRAGON__PROMPT_SEPARATOR_FOREGROUND_COLOR"
	REAL_DRAGON__PROMPT_SEPARATOR_BACKGROUND_COLOR="$DRAGON__PROMPT_SEPARATOR_BACKGROUND_COLOR"
	REAL_DRAGON__PROMPT_SEPARATOR_BOLD="$DRAGON__PROMPT_SEPARATOR_BOLD"
	REAL_DRAGON__PROMPT_SEPARATOR_UNDERLINE="$DRAGON__PROMPT_SEPARATOR_UNDERLINE"
}

dragon__set_user_host_separator()
{
	FINAL_DRAGON__USER_HOST_SEPARATOR_CONTENT=""
	[[ -z $DRAGON__USER_HOST_SEPARATOR ]] && return

	REAL_DRAGON__PROMPT_SEPARATOR_CONTENT="$DRAGON__USER_HOST_SEPARATOR"
	__set_separator_parameters

	__dragon__show "PROMPT_SEPARATOR"
	FINAL_DRAGON__USER_HOST_SEPARATOR_CONTENT="$SHOW_RESULT"
}

dragon__set_host_dir_separator()
{
	FINAL_DRAGON__HOST_DIR_SEPARATOR_CONTENT=""
	[[ -z $DRAGON__HOST_DIR_SEPARATOR ]] && return

	REAL_DRAGON__PROMPT_SEPARATOR_CONTENT="$DRAGON__HOST_DIR_SEPARATOR"
	__set_separator_parameters

	__dragon__show "PROMPT_SEPARATOR"
	FINAL_DRAGON__HOST_DIR_SEPARATOR_CONTENT="$SHOW_RESULT"
}

dragon__set_multiline_first_line_prompt()
{
	FINAL_DRAGON__MULTILINE_FIRST_LINE_SEPARATOR_CONTENT=""
	[[ -z $DRAGON__FIRST_LINE_SEPARATOR_CHAR ]] && return

	REAL_DRAGON__PROMPT_SEPARATOR_CONTENT="$DRAGON__FIRST_LINE_SEPARATOR_CHAR"
	__set_separator_parameters

	__dragon__show "PROMPT_SEPARATOR"
	FINAL_DRAGON__MULTILINE_FIRST_LINE_SEPARATOR_CONTENT="$SHOW_RESULT"
}

dragon__set_multiline_new_line_prompt()
{
	FINAL_DRAGON__MULTILINE_NEW_LINE_SEPARATOR_CONTENT=""
	[[ -z $DRAGON__NEW_LINE_SEPARATOR_CHAR ]] && return

	REAL_DRAGON__PROMPT_SEPARATOR_CONTENT="$DRAGON__NEW_LINE_SEPARATOR_CHAR"
	__set_separator_parameters

	__dragon__show "PROMPT_SEPARATOR"
	FINAL_DRAGON__MULTILINE_NEW_LINE_SEPARATOR_CONTENT="$SHOW_RESULT"
}

dragon__set_multiline_last_line_prompt()
{
	FINAL_DRAGON__MULTILINE_LAST_LINE_SEPARATOR_CONTENT=""
	[[ -z $DRAGON__LAST_LINE_SEPARATOR_CHAR ]] && return

	REAL_DRAGON__PROMPT_SEPARATOR_CONTENT="$DRAGON__LAST_LINE_SEPARATOR_CHAR"
	__set_separator_parameters

	__dragon__show "PROMPT_SEPARATOR"
	FINAL_DRAGON__MULTILINE_LAST_LINE_SEPARATOR_CONTENT="$SHOW_RESULT"
}

__add_separator_between_left_segments()
{
	# adds right separator to the `left_prompt` variable, by the color of the bg of the left segment and the bg of the right segment
	! $DRAGON__USE_NERD_FONT && return

	local segment_content="$1"
	local left_segment_left_bg_color="$2"

	[[ -z $segment_content ]] && return

	__get_xterm_color_by_name "$left_segment_left_bg_color"
	left_segment_left_bg_color="${XTERM_COLOR:-$TERMINAL_BACKGROUND_COLOR}"

	if [[ "$left_segment_left_bg_color" == "$left_segment_right_bg_color" && "$left_segment_left_bg_color" == "$TERMINAL_BACKGROUND_COLOR" ]]; then
		return
	fi
	
	if [[ "$left_segment_left_bg_color" == "$left_segment_right_bg_color" ]]; then
		__get_xterm_style_format "$TERMINAL_BACKGROUND_COLOR" "$left_segment_right_bg_color" "false" "false"
		left_prompt+="$STYLE_FORMAT$DRAGON__LEFT_SEGMENT_SEPARATOR_SAME_COLOR"
	else
		__get_xterm_style_format "$left_segment_right_bg_color" "$left_segment_left_bg_color" "false" "false"
		left_prompt+="$STYLE_FORMAT$DRAGON__LEFT_SEGMENT_SEPARATOR"
		left_segment_right_bg_color="$left_segment_left_bg_color"
	fi
}

__add_separator_between_right_segments()
{
	# adds left separator to the `right_prompt` variable, by the color of the bg of the right segment and the bg of the left segment
	! $DRAGON__USE_NERD_FONT && return

	local segment_content="$1"
	local right_segment_right_bg_color="$2"

	[[ -z $segment_content ]] && return

	__get_xterm_color_by_name "$right_segment_right_bg_color"
	right_segment_right_bg_color="${XTERM_COLOR:-$TERMINAL_BACKGROUND_COLOR}"

	if [[ "$right_segment_right_bg_color" == "$right_segment_left_bg_color" && "$right_segment_right_bg_color" == "$TERMINAL_BACKGROUND_COLOR" ]]; then
		return
	fi
	
	if [[ "$right_segment_right_bg_color" == "$right_segment_left_bg_color" ]]; then
		__get_xterm_style_format "$TERMINAL_BACKGROUND_COLOR" "$right_segment_left_bg_color" "false" "false"
		right_prompt+="$STYLE_FORMAT$DRAGON__RIGHT_SEGMENT_SEPARATOR_SAME_COLOR"
	else
		__get_xterm_style_format "$right_segment_right_bg_color" "$right_segment_left_bg_color" "false" "false"
		right_prompt+="$STYLE_FORMAT$DRAGON__RIGHT_SEGMENT_SEPARATOR"
		right_segment_left_bg_color="$right_segment_right_bg_color"
	fi
}
