__set_separator_parameters()
{
	REAL_DRAGON__PROMPT_SEPARATOR_PREFIX=""
	REAL_DRAGON__PROMPT_SEPARATOR_SUFFIX=""
	REAL_DRAGON__PROMPT_SEPARATOR_FOREGROUND_COLOR="$DRAGON__PROMPT_SEPARATOR_FOREGROUND_COLOR"
	REAL_DRAGON__PROMPT_SEPARATOR_BACKGROUND_COLOR="$DRAGON__PROMPT_SEPARATOR_BACKGROUND_COLOR"
	REAL_DRAGON__PROMPT_SEPARATOR_BOLD="$DRAGON__PROMPT_SEPARATOR_BOLD"
	REAL_DRAGON__PROMPT_SEPARATOR_UNDERLINE="$DRAGON__PROMPT_SEPARATOR_UNDERLINE"
}

__dragon_render_separator()
{
	local content_val="$1" final_var="$2"
	typeset -g "${final_var}="
	[[ -z "$content_val" ]] && return
	REAL_DRAGON__PROMPT_SEPARATOR_CONTENT="$content_val"
	__set_separator_parameters
	__dragon__show "PROMPT_SEPARATOR"
	typeset -g "${final_var}=${SHOW_RESULT}"
}

dragon__set_user_host_separator()        { __dragon_render_separator "$DRAGON__USER_HOST_SEPARATOR"       FINAL_DRAGON__USER_HOST_SEPARATOR_CONTENT; }
dragon__set_host_dir_separator()         { __dragon_render_separator "$DRAGON__HOST_DIR_SEPARATOR"        FINAL_DRAGON__HOST_DIR_SEPARATOR_CONTENT; }
dragon__set_multiline_first_line_prompt(){ __dragon_render_separator "$DRAGON__FIRST_LINE_SEPARATOR_CHAR" FINAL_DRAGON__MULTILINE_FIRST_LINE_SEPARATOR_CONTENT; }
dragon__set_multiline_new_line_prompt()  { __dragon_render_separator "$DRAGON__NEW_LINE_SEPARATOR_CHAR"   FINAL_DRAGON__MULTILINE_NEW_LINE_SEPARATOR_CONTENT; }
dragon__set_multiline_last_line_prompt() { __dragon_render_separator "$DRAGON__LAST_LINE_SEPARATOR_CHAR"  FINAL_DRAGON__MULTILINE_LAST_LINE_SEPARATOR_CONTENT; }

__add_separator_between_left_segments()
{
	# adds right separator to the `left_prompt` variable, by the color of the bg of the left segment and the bg of the right segment
	! $DRAGON__USE_NERD_FONT && return

	local segment_content="$1"
	local left_segment_left_bg_color="$2"

	[[ -z $segment_content ]] && return

	__get_xterm_color_by_name "$left_segment_left_bg_color"
	left_segment_left_bg_color="${XTERM_COLOR:-$TERMINAL_BACKGROUND_COLOR}"

	if [[ "$left_segment_left_bg_color" == "$_dragon_left_prev_bg" && "$left_segment_left_bg_color" == "$TERMINAL_BACKGROUND_COLOR" ]]; then
		return
	fi

	if [[ "$left_segment_left_bg_color" == "$_dragon_left_prev_bg" ]]; then
		__get_xterm_style_format "$TERMINAL_BACKGROUND_COLOR" "$_dragon_left_prev_bg" "false" "false"
		left_prompt+="$STYLE_FORMAT$DRAGON__LEFT_SEGMENT_SEPARATOR_SAME_COLOR"
	else
		__get_xterm_style_format "$_dragon_left_prev_bg" "$left_segment_left_bg_color" "false" "false"
		left_prompt+="$STYLE_FORMAT$DRAGON__LEFT_SEGMENT_SEPARATOR"
		_dragon_left_prev_bg="$left_segment_left_bg_color"
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

	if [[ "$right_segment_right_bg_color" == "$_dragon_right_prev_bg" && "$right_segment_right_bg_color" == "$TERMINAL_BACKGROUND_COLOR" ]]; then
		return
	fi

	if [[ "$right_segment_right_bg_color" == "$_dragon_right_prev_bg" ]]; then
		__get_xterm_style_format "$TERMINAL_BACKGROUND_COLOR" "$_dragon_right_prev_bg" "false" "false"
		right_prompt+="$STYLE_FORMAT$DRAGON__RIGHT_SEGMENT_SEPARATOR_SAME_COLOR"
	else
		__get_xterm_style_format "$right_segment_right_bg_color" "$_dragon_right_prev_bg" "false" "false"
		right_prompt+="$STYLE_FORMAT$DRAGON__RIGHT_SEGMENT_SEPARATOR"
		_dragon_right_prev_bg="$right_segment_right_bg_color"
	fi
}
