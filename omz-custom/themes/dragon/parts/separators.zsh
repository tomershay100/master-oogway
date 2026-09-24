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
	typeset -g "${final_var}=${_DRAGON_SHOW_RESULT}"
}

dragon__set_user_host_separator()        { __dragon_render_separator "$DRAGON__USER_HOST_SEPARATOR"       FINAL_DRAGON__USER_HOST_SEPARATOR_CONTENT; }
dragon__set_host_dir_separator()         { __dragon_render_separator "$DRAGON__HOST_DIR_SEPARATOR"        FINAL_DRAGON__HOST_DIR_SEPARATOR_CONTENT; }
dragon__set_multiline_first_line_prompt(){ __dragon_render_separator "$DRAGON__FIRST_LINE_SEPARATOR_CHAR" FINAL_DRAGON__MULTILINE_FIRST_LINE_SEPARATOR_CONTENT; }
dragon__set_multiline_new_line_prompt()  { __dragon_render_separator "$DRAGON__NEW_LINE_SEPARATOR_CHAR"   FINAL_DRAGON__MULTILINE_NEW_LINE_SEPARATOR_CONTENT; }
dragon__set_multiline_last_line_prompt() { __dragon_render_separator "$DRAGON__LAST_LINE_SEPARATOR_CHAR"  FINAL_DRAGON__MULTILINE_LAST_LINE_SEPARATOR_CONTENT; }

__add_separator_between_left_segments()
{
	# adds right separator to the `_DRAGON_LEFT_PROMPT` variable, by the color of the bg of the left segment and the bg of the right segment
	! $DRAGON__USE_NERD_FONT && return

	local segment_content="$1"
	local left_segment_left_bg_color="$2"
	local is_last="${3:-0}"

	[[ -z $segment_content ]] && return

	__get_xterm_color_by_name "$left_segment_left_bg_color"
	left_segment_left_bg_color="${_DRAGON_XTERM_COLOR:-$_DRAGON_TERMINAL_BG_CODE}"

	if [[ "$left_segment_left_bg_color" == "$_dragon_left_prev_bg" && "$left_segment_left_bg_color" == "$_DRAGON_TERMINAL_BG_CODE" ]]; then
		return
	fi

	# Positional overrides: empty = fall back to the regular separator, so
	# presets that don't set them render identically to before. is_first is
	# tracker-driven: the first boundary that renders a glyph consumes it,
	# so the cap lands on the first *visible* pill, not a fixed slot that
	# may be empty (e.g. ssh_prefix when not over SSH).
	local is_first=0
	[[ $_dragon_left_first_pending == 1 ]] && is_first=1
	local sep="$DRAGON__LEFT_SEGMENT_SEPARATOR"
	local sep_same="$DRAGON__LEFT_SEGMENT_SEPARATOR_SAME_COLOR"
	[[ $is_first == 1 && -n "$DRAGON__LEFT_FIRST_SEGMENT_SEPARATOR" ]] && sep="$DRAGON__LEFT_FIRST_SEGMENT_SEPARATOR"
	[[ $is_first == 1 && -n "$DRAGON__LEFT_FIRST_SEGMENT_SEPARATOR_SAME_COLOR" ]] && sep_same="$DRAGON__LEFT_FIRST_SEGMENT_SEPARATOR_SAME_COLOR"
	[[ $is_last == 1 && -n "$DRAGON__LEFT_LAST_SEGMENT_SEPARATOR" ]] && sep="$DRAGON__LEFT_LAST_SEGMENT_SEPARATOR"
	[[ $is_last == 1 && -n "$DRAGON__LEFT_LAST_SEGMENT_SEPARATOR_SAME_COLOR" ]] && sep_same="$DRAGON__LEFT_LAST_SEGMENT_SEPARATOR_SAME_COLOR"

	if [[ "$left_segment_left_bg_color" == "$_dragon_left_prev_bg" ]]; then
		__get_xterm_style_format "$_DRAGON_TERMINAL_BG_CODE" "$_dragon_left_prev_bg" "false" "false"
		_DRAGON_LEFT_PROMPT+="$STYLE_FORMAT$sep_same"
	else
		# Rounded caps (E0B4–E0B7) fill with fg, unlike the classic
		# triangles (E0B0–E0B3) which fill with bg. The first cap is a
		# left-pointing rounded glyph opening from terminal — swap fg/bg
		# so the pill color fills the rounded edge.
		if [[ $is_first == 1 && -n "$DRAGON__LEFT_FIRST_SEGMENT_SEPARATOR" ]]; then
			__get_xterm_style_format "$left_segment_left_bg_color" "$_dragon_left_prev_bg" "false" "false"
		else
			__get_xterm_style_format "$_dragon_left_prev_bg" "$left_segment_left_bg_color" "false" "false"
		fi
		_DRAGON_LEFT_PROMPT+="$STYLE_FORMAT$sep"
		_dragon_left_prev_bg="$left_segment_left_bg_color"
	fi
	_dragon_left_first_pending=0
}

__add_separator_between_right_segments()
{
	# adds left separator to the `_DRAGON_RIGHT_PROMPT` variable, by the color of the bg of the right segment and the bg of the left segment
	! $DRAGON__USE_NERD_FONT && return

	local segment_content="$1"
	local right_segment_right_bg_color="$2"
	local is_last="${3:-0}"

	[[ -z $segment_content ]] && return

	__get_xterm_color_by_name "$right_segment_right_bg_color"
	right_segment_right_bg_color="${_DRAGON_XTERM_COLOR:-$_DRAGON_TERMINAL_BG_CODE}"

	if [[ "$right_segment_right_bg_color" == "$_dragon_right_prev_bg" && "$right_segment_right_bg_color" == "$_DRAGON_TERMINAL_BG_CODE" ]]; then
		return
	fi

	# Positional overrides: empty = fall back to the regular separator.
	# is_first is tracker-driven — see the left helper for the rationale.
	local is_first=0
	[[ $_dragon_right_first_pending == 1 ]] && is_first=1
	local sep="$DRAGON__RIGHT_SEGMENT_SEPARATOR"
	local sep_same="$DRAGON__RIGHT_SEGMENT_SEPARATOR_SAME_COLOR"
	[[ $is_first == 1 && -n "$DRAGON__RIGHT_FIRST_SEGMENT_SEPARATOR" ]] && sep="$DRAGON__RIGHT_FIRST_SEGMENT_SEPARATOR"
	[[ $is_first == 1 && -n "$DRAGON__RIGHT_FIRST_SEGMENT_SEPARATOR_SAME_COLOR" ]] && sep_same="$DRAGON__RIGHT_FIRST_SEGMENT_SEPARATOR_SAME_COLOR"
	[[ $is_last == 1 && -n "$DRAGON__RIGHT_LAST_SEGMENT_SEPARATOR" ]] && sep="$DRAGON__RIGHT_LAST_SEGMENT_SEPARATOR"
	[[ $is_last == 1 && -n "$DRAGON__RIGHT_LAST_SEGMENT_SEPARATOR_SAME_COLOR" ]] && sep_same="$DRAGON__RIGHT_LAST_SEGMENT_SEPARATOR_SAME_COLOR"

	if [[ "$right_segment_right_bg_color" == "$_dragon_right_prev_bg" ]]; then
		__get_xterm_style_format "$_DRAGON_TERMINAL_BG_CODE" "$_dragon_right_prev_bg" "false" "false"
		_DRAGON_RIGHT_PROMPT+="$STYLE_FORMAT$sep_same"
	else
		# The last cap is a right-pointing rounded glyph closing to terminal
		# — swap fg/bg so the pill color fills the rounded edge.
		if [[ $is_last == 1 && -n "$DRAGON__RIGHT_LAST_SEGMENT_SEPARATOR" ]]; then
			__get_xterm_style_format "$_dragon_right_prev_bg" "$right_segment_right_bg_color" "false" "false"
		else
			__get_xterm_style_format "$right_segment_right_bg_color" "$_dragon_right_prev_bg" "false" "false"
		fi
		_DRAGON_RIGHT_PROMPT+="$STYLE_FORMAT$sep"
		_dragon_right_prev_bg="$right_segment_right_bg_color"
	fi
	_dragon_right_first_pending=0
}
