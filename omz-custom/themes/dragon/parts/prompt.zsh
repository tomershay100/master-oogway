__calc_prompt_length()
{
	setopt local_options extended_glob
	local zsh_prompt_length=${(m)#${${(%)PROMPT}//$'\e['[0-9;]#[A-Za-z]/}}
	local git_prompt_length=${(m)#${${(%)FINAL_GIT_STATUS_CONTENT}//$'\e['[0-9;]#[A-Za-z]/}}
	FINAL_ONE_LINE_LPROMPT_LEN=$(( zsh_prompt_length + git_prompt_length ))
}

dragon__set_lprompt()
{
	__get_xterm_color_by_name "$TERMINAL_BACKGROUND_COLOR"
	_dragon_left_prev_bg="${XTERM_COLOR:-$DRAGON__TERMINAL_BACKGROUND}"
	GIT_SHOULD_BE_ON_NEW_LINE=false
	left_prompt=""
	local curr_content

	if $DRAGON__ENABLE_MULTILINE; then
		dragon__set_multiline_first_line_prompt
		__add_separator_between_left_segments "$FINAL_DRAGON__MULTILINE_FIRST_LINE_SEPARATOR_CONTENT" "$DRAGON__PROMPT_SEPARATOR_BACKGROUND_COLOR"
		left_prompt+="$FINAL_DRAGON__MULTILINE_FIRST_LINE_SEPARATOR_CONTENT"
	fi

	dragon__set_ssh_prefix
	__add_separator_between_left_segments "$FINAL_DRAGON__SSH_PREFIX_CONTENT" "$DRAGON__SSH_PREFIX_BACKGROUND_COLOR"
	left_prompt+="$FINAL_DRAGON__SSH_PREFIX_CONTENT"

	dragon__set_username
	__add_separator_between_left_segments "$FINAL_DRAGON__USERNAME_CONTENT" "$DRAGON__USERNAME_BACKGROUND_COLOR"
	left_prompt+="$FINAL_DRAGON__USERNAME_CONTENT"

	dragon__set_user_host_separator
	__add_separator_between_left_segments "$FINAL_DRAGON__USER_HOST_SEPARATOR_CONTENT" "$DRAGON__PROMPT_SEPARATOR_BACKGROUND_COLOR"
	left_prompt+="$FINAL_DRAGON__USER_HOST_SEPARATOR_CONTENT"

	dragon__set_hostname
	__add_separator_between_left_segments "$FINAL_DRAGON__HOSTNAME_CONTENT" "$DRAGON__HOSTNAME_BACKGROUND_COLOR"
	left_prompt+="$FINAL_DRAGON__HOSTNAME_CONTENT"

	dragon__set_host_dir_separator
	__add_separator_between_left_segments "$FINAL_DRAGON__HOST_DIR_SEPARATOR_CONTENT" "$DRAGON__PROMPT_SEPARATOR_BACKGROUND_COLOR"
	left_prompt+="$FINAL_DRAGON__HOST_DIR_SEPARATOR_CONTENT"

	dragon__set_directory
	__add_separator_between_left_segments "$FINAL_DRAGON__DIRECTORY_CONTENT" "$DRAGON__DIRECTORY_BACKGROUND_COLOR"
	left_prompt+="$FINAL_DRAGON__DIRECTORY_CONTENT"

	PROMPT="$left_prompt"
	left_prompt=""

	dragon__set_git_prompt

	if [[ -n $FINAL_GIT_STATUS_CONTENT ]] && $DRAGON__ENABLE_MULTILINE && $GIT_SHOULD_BE_ON_NEW_LINE; then
		dragon__set_multiline_new_line_prompt
		curr_content="$FINAL_DRAGON__MULTILINE_NEW_LINE_SEPARATOR_CONTENT"
		if [[ -n $curr_content ]]; then
			__add_separator_between_left_segments " " ""
			PROMPT+="$left_prompt"
			left_prompt=""
			__add_separator_between_left_segments "$curr_content" "$DRAGON__PROMPT_SEPARATOR_BACKGROUND_COLOR"
			PROMPT+="
$left_prompt$curr_content"
			left_prompt=""
		else
			__add_separator_between_left_segments " " ""
			PROMPT+="$left_prompt
"
			left_prompt=""
		fi
	fi

	__add_separator_between_left_segments "$FINAL_GIT_STATUS_CONTENT" "$REAL_DRAGON__GIT_STATUS_BACKGROUND_COLOR"
	PROMPT+="$left_prompt$FINAL_GIT_STATUS_CONTENT"
	left_prompt=""
	
	if $DRAGON__ENABLE_MULTILINE; then
		dragon__set_multiline_last_line_prompt
		curr_content="$FINAL_DRAGON__MULTILINE_LAST_LINE_SEPARATOR_CONTENT"
		if [[ -n $curr_content ]]; then
			__add_separator_between_left_segments " " ""
			PROMPT+="$left_prompt"
			left_prompt=""
			__add_separator_between_left_segments "$curr_content" "$DRAGON__PROMPT_SEPARATOR_BACKGROUND_COLOR"
			PROMPT+="
$left_prompt$curr_content"
			left_prompt=""
		else
			__add_separator_between_left_segments " " ""
			PROMPT+="$left_prompt
"
			left_prompt=""
		fi
	fi

	dragon__set_prompt_char
	__add_separator_between_left_segments "$FINAL_PROMPT_CHAR_CONTENT" "$REAL_DRAGON__PROMPT_CHAR_BACKGROUND_COLOR"
	left_prompt+="$FINAL_PROMPT_CHAR_CONTENT"

	__add_separator_between_left_segments " " ""

	PROMPT+="$left_prompt"
	left_prompt=""
}

dragon__set_rprompt()
{
	__get_xterm_color_by_name "$TERMINAL_BACKGROUND_COLOR"
	_dragon_right_prev_bg="${XTERM_COLOR:-$DRAGON__TERMINAL_BACKGROUND}"
	right_prompt=""

	dragon__set_exit_status
	__add_separator_between_right_segments "$FINAL_DRAGON__EXIT_STATUS_CONTENT" "$DRAGON__EXIT_STATUS_BACKGROUND_COLOR"
	right_prompt+="$FINAL_DRAGON__EXIT_STATUS_CONTENT"

	dragon__set_ssh_connection_count
	__add_separator_between_right_segments "$FINAL_DRAGON__SSH_CONNECTION_COUNT_CONTENT" "$DRAGON__SSH_CONNECTION_COUNT_BACKGROUND_COLOR"
	right_prompt+="$FINAL_DRAGON__SSH_CONNECTION_COUNT_CONTENT"

	dragon__set_job_count
	__add_separator_between_right_segments "$FINAL_DRAGON__JOB_COUNT_CONTENT" "$DRAGON__JOB_COUNT_BACKGROUND_COLOR"
	right_prompt+="$FINAL_DRAGON__JOB_COUNT_CONTENT"

	dragon__set_execution_time
	__add_separator_between_right_segments "$FINAL_DRAGON__EXEC_TIMER_CONTENT" "$DRAGON__EXEC_TIMER_BACKGROUND_COLOR"
	right_prompt+="$FINAL_DRAGON__EXEC_TIMER_CONTENT"

	dragon__set_date_time
	__add_separator_between_right_segments "$FINAL_DRAGON__DATE_TIME_CONTENT" "$DRAGON__DATE_TIME_BACKGROUND_COLOR"
	right_prompt+="$FINAL_DRAGON__DATE_TIME_CONTENT"

	RPROMPT="$right_prompt"
	_DRAGON_SAVED_RPROMPT="$right_prompt"  # saved for verbose transient reuse
}
