dragon__set_date_time()
{
	FINAL_DRAGON__DATE_TIME_CONTENT=""
	! $DRAGON__ENABLE_DATE_TIME && return
	[[ -z $DRAGON__DATE_TIME_FORMAT ]] && return

	REAL_DRAGON__DATE_TIME_CONTENT="$DRAGON__DATE_TIME_FORMAT"

	REAL_DRAGON__DATE_TIME_PREFIX="$DRAGON__DATE_TIME_PREFIX"
	REAL_DRAGON__DATE_TIME_SUFFIX="$DRAGON__DATE_TIME_SUFFIX"

	REAL_DRAGON__DATE_TIME_FOREGROUND_COLOR="$DRAGON__DATE_TIME_FOREGROUND_COLOR"
	REAL_DRAGON__DATE_TIME_BACKGROUND_COLOR="$DRAGON__DATE_TIME_BACKGROUND_COLOR"
	REAL_DRAGON__DATE_TIME_BOLD="$DRAGON__DATE_TIME_BOLD"
	REAL_DRAGON__DATE_TIME_UNDERLINE="$DRAGON__DATE_TIME_UNDERLINE"

	__dragon__show "DATE_TIME"
	FINAL_DRAGON__DATE_TIME_CONTENT="$SHOW_RESULT"
}

_DRAGON_CMD_RAN=false
timer=-1

__set_timer()
{
	timer=$SECONDS
}

__mark_cmd_ran()
{
	_DRAGON_CMD_RAN=true
}

__reset_timer()
{
	timer=-1
}

__get_readable_time()
{
	local total=$1
	local days=$(( total / 86400 ))
	local hours=$(( total % 86400 / 3600 ))
	local minutes=$(( total % 3600 / 60 ))
	local secs=$(( total % 60 ))

	(( days > 0 ))    && print -n "${days}d "
	(( hours > 0 ))   && print -n "${hours}h "
	(( minutes > 0 )) && print -n "${minutes}m "
	print -n "${secs}s"
}

dragon__set_execution_time()
{
	FINAL_DRAGON__EXEC_TIMER_CONTENT=""
	! $DRAGON__ENABLE_EXEC_TIMER && return

	if [[ -n "${DRAGON__PREVIEW_FAKE_EXEC_TIME:-}" ]]; then
		REAL_DRAGON__EXEC_TIMER_CONTENT="${DRAGON__PREVIEW_FAKE_EXEC_TIME}"
	elif ((timer == -1 || SECONDS - timer < $DRAGON__EXEC_TIMER_THRESHOLD)); then
		return
	else
		REAL_DRAGON__EXEC_TIMER_CONTENT="$(__get_readable_time $((SECONDS - timer)))"
	fi

	REAL_DRAGON__EXEC_TIMER_PREFIX="$DRAGON__EXEC_TIMER_PREFIX"
	REAL_DRAGON__EXEC_TIMER_SUFFIX="$DRAGON__EXEC_TIMER_SUFFIX"

	REAL_DRAGON__EXEC_TIMER_FOREGROUND_COLOR="$DRAGON__EXEC_TIMER_FOREGROUND_COLOR"
	REAL_DRAGON__EXEC_TIMER_BACKGROUND_COLOR="$DRAGON__EXEC_TIMER_BACKGROUND_COLOR"
	REAL_DRAGON__EXEC_TIMER_BOLD="$DRAGON__EXEC_TIMER_BOLD"
	REAL_DRAGON__EXEC_TIMER_UNDERLINE="$DRAGON__EXEC_TIMER_UNDERLINE"

	__dragon__show "EXEC_TIMER"
	FINAL_DRAGON__EXEC_TIMER_CONTENT="$SHOW_RESULT"
}

__set_job_count_prefix_and_suffix()
{
	REAL_DRAGON__JOB_COUNT_PREFIX="$DRAGON__JOB_COUNT_PREFIX"
	REAL_DRAGON__JOB_COUNT_SUFFIX="$DRAGON__JOB_COUNT_SUFFIX"
	if [[ "$jobs_count" -eq 1 ]]; then
		REAL_DRAGON__JOB_COUNT_PREFIX="${DRAGON__JOB_COUNT_PREFIX/jobs/job}"
		REAL_DRAGON__JOB_COUNT_SUFFIX="${DRAGON__JOB_COUNT_SUFFIX/jobs/job}"
	fi
}

dragon__set_job_count()
{
	FINAL_DRAGON__JOB_COUNT_CONTENT=""
	! $DRAGON__ENABLE_JOB_COUNT && return

	local jobs_count="${DRAGON__PREVIEW_FAKE_JOB_COUNT:-${#jobstates[@]}}"
	[[ "$jobs_count" -eq 0 ]] && return

	REAL_DRAGON__JOB_COUNT_CONTENT="%j"

	__set_job_count_prefix_and_suffix

	REAL_DRAGON__JOB_COUNT_FOREGROUND_COLOR="$DRAGON__JOB_COUNT_FOREGROUND_COLOR"
	REAL_DRAGON__JOB_COUNT_BACKGROUND_COLOR="$DRAGON__JOB_COUNT_BACKGROUND_COLOR"
	REAL_DRAGON__JOB_COUNT_BOLD="$DRAGON__JOB_COUNT_BOLD"
	REAL_DRAGON__JOB_COUNT_UNDERLINE="$DRAGON__JOB_COUNT_UNDERLINE"

	__dragon__show "JOB_COUNT"
	FINAL_DRAGON__JOB_COUNT_CONTENT="$SHOW_RESULT"
}

__set_ssh_connection_count_content()
{
	if [[ -n "${DRAGON__PREVIEW_FAKE_SSH_CONN_COUNT:-}" ]]; then
		REAL_DRAGON__SSH_CONNECTION_COUNT_CONTENT="${DRAGON__PREVIEW_FAKE_SSH_CONN_COUNT}"
		return
	fi

	local -a who_lines=( "${(f)$(who)}" )
	local -a pts_lines=( "${(M)who_lines[@]:#*pts*}" )
	local ip_pattern='^\([0-9]{1,3}(\.[0-9]{1,3}){3}\)$'
	local -a remote_ips=()
	local line
	for line in "${pts_lines[@]}"; do
		local ip="${line##* }"
		[[ "$ip" =~ $ip_pattern ]] && remote_ips+=( "$ip" )
	done

	local connection_count=${#remote_ips}
	if __is_via_ssh && [[ -n "$SSH_CLIENT" ]]; then
		local current_ip="(${SSH_CLIENT%% *})"
		local -a other_ips=( "${remote_ips[@]:#$current_ip}" )
		connection_count=${#other_ips}
	fi

	REAL_DRAGON__SSH_CONNECTION_COUNT_CONTENT="$connection_count"
}

dragon__set_ssh_connection_count()
{
	FINAL_DRAGON__SSH_CONNECTION_COUNT_CONTENT=""
	! $DRAGON__ENABLE_SSH_CONNECTION_COUNT && return

	__set_ssh_connection_count_content
	[[ "$REAL_DRAGON__SSH_CONNECTION_COUNT_CONTENT" -eq 0 ]] && return

	REAL_DRAGON__SSH_CONNECTION_COUNT_PREFIX="$DRAGON__SSH_CONNECTION_COUNT_PREFIX"
	REAL_DRAGON__SSH_CONNECTION_COUNT_SUFFIX="$DRAGON__SSH_CONNECTION_COUNT_SUFFIX"
	REAL_DRAGON__SSH_CONNECTION_COUNT_FOREGROUND_COLOR="$DRAGON__SSH_CONNECTION_COUNT_FOREGROUND_COLOR"
	REAL_DRAGON__SSH_CONNECTION_COUNT_BACKGROUND_COLOR="$DRAGON__SSH_CONNECTION_COUNT_BACKGROUND_COLOR"
	REAL_DRAGON__SSH_CONNECTION_COUNT_BOLD="$DRAGON__SSH_CONNECTION_COUNT_BOLD"
	REAL_DRAGON__SSH_CONNECTION_COUNT_UNDERLINE="$DRAGON__SSH_CONNECTION_COUNT_UNDERLINE"

	__dragon__show "SSH_CONNECTION_COUNT"
	FINAL_DRAGON__SSH_CONNECTION_COUNT_CONTENT="$SHOW_RESULT"
}

__save_exit_code()
{
	local last_exit="$?"
	if [[ "$_DRAGON_CMD_RAN" == "true" ]]; then
		exit_code="$last_exit"
	else
		exit_code=0
	fi
	_DRAGON_CMD_RAN=false
}

__get_full_exit_code()
{
	if [[ "$exit_code" -gt 128 ]]; then
		local sig_name
		sig_name="$(kill -l "$exit_code" 2>/dev/null)"
		local kill_status=$?
		if [[ $kill_status -eq 0 && -n "$sig_name" ]]; then
			echo "SIG$sig_name"
			return
		fi
	fi
	echo "$exit_code"
}

__get_exit_status_content()
{
	if "$DRAGON__ENABLE_FULL_EXIT_STATUS"; then
		__get_full_exit_code
	else
		echo "$exit_code"
	fi
}

dragon__set_exit_status()
{
	FINAL_DRAGON__EXIT_STATUS_CONTENT=""
	! "$DRAGON__ENABLE_EXIT_STATUS" && return
	[[ "$exit_code" -eq 0 ]] && return

	REAL_DRAGON__EXIT_STATUS_CONTENT="$(__get_exit_status_content)"

	REAL_DRAGON__EXIT_STATUS_PREFIX="$DRAGON__EXIT_STATUS_PREFIX"
	REAL_DRAGON__EXIT_STATUS_SUFFIX="$DRAGON__EXIT_STATUS_SUFFIX"

	REAL_DRAGON__EXIT_STATUS_FOREGROUND_COLOR="$DRAGON__EXIT_STATUS_FOREGROUND_COLOR"
	REAL_DRAGON__EXIT_STATUS_BACKGROUND_COLOR="$DRAGON__EXIT_STATUS_BACKGROUND_COLOR"
	REAL_DRAGON__EXIT_STATUS_BOLD="$DRAGON__EXIT_STATUS_BOLD"
	REAL_DRAGON__EXIT_STATUS_UNDERLINE="$DRAGON__EXIT_STATUS_UNDERLINE"

	__dragon__show "EXIT_STATUS"
	FINAL_DRAGON__EXIT_STATUS_CONTENT="$SHOW_RESULT"
}
