dragon__set_date_time()
{
	FINAL_DRAGON__DATE_TIME_CONTENT=""
	! $DRAGON__ENABLE_DATE_TIME && return
	[[ -z $DRAGON__DATE_TIME_FORMAT ]] && return

	REAL_DRAGON__DATE_TIME_CONTENT="$DRAGON__DATE_TIME_FORMAT"
	__dragon_copy_defaults DATE_TIME
	__dragon_finalize DATE_TIME
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

__get_readable_time()
{
	local total=$1
	local days=$(( total / 86400 ))
	local hours=$(( total % 86400 / 3600 ))
	local minutes=$(( total % 3600 / 60 ))
	local secs=$(( total % 60 ))

	# Write to a global to avoid a subshell at call sites
	_DRAGON_READABLE_TIME=""
	(( days > 0 ))    && _DRAGON_READABLE_TIME+="${days}d "
	(( hours > 0 ))   && _DRAGON_READABLE_TIME+="${hours}h "
	(( minutes > 0 )) && _DRAGON_READABLE_TIME+="${minutes}m "
	_DRAGON_READABLE_TIME+="${secs}s"
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
		# Call without $() to avoid a subshell — result written to _DRAGON_READABLE_TIME
		__get_readable_time $((SECONDS - timer))
		REAL_DRAGON__EXEC_TIMER_CONTENT="${_DRAGON_READABLE_TIME}"
		unset _DRAGON_READABLE_TIME
	fi

	__dragon_copy_defaults EXEC_TIMER
	__dragon_finalize EXEC_TIMER
}

# When there's exactly one job, swap "jobs" → "job" in prefix/suffix.
# Runs AFTER __dragon_copy_defaults JOB_COUNT, so the multi-job defaults are
# already in REAL_; this just rewrites them in-place for the singular case.
__set_job_count_prefix_and_suffix_singular()
{
	(( jobs_count == 1 )) || return
	REAL_DRAGON__JOB_COUNT_PREFIX="${DRAGON__JOB_COUNT_PREFIX/jobs/job}"
	REAL_DRAGON__JOB_COUNT_SUFFIX="${DRAGON__JOB_COUNT_SUFFIX/jobs/job}"
}

dragon__set_job_count()
{
	FINAL_DRAGON__JOB_COUNT_CONTENT=""
	! $DRAGON__ENABLE_JOB_COUNT && return

	local jobs_count="${DRAGON__PREVIEW_FAKE_JOB_COUNT:-${#jobstates[@]}}"
	(( jobs_count == 0 )) && return

	REAL_DRAGON__JOB_COUNT_CONTENT="%j"
	__dragon_copy_defaults JOB_COUNT
	__set_job_count_prefix_and_suffix_singular
	__dragon_finalize JOB_COUNT
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
	(( REAL_DRAGON__SSH_CONNECTION_COUNT_CONTENT == 0 )) && return

	__dragon_copy_defaults SSH_CONNECTION_COUNT
	__dragon_finalize SSH_CONNECTION_COUNT
}

__save_exit_code()
{
	local last_exit="$?"
	if [[ "$_DRAGON_CMD_RAN" == "true" ]]; then
		_DRAGON_EXIT_CODE="$last_exit"
	else
		_DRAGON_EXIT_CODE=0
	fi
	_DRAGON_CMD_RAN=false
}

dragon__set_exit_status()
{
	FINAL_DRAGON__EXIT_STATUS_CONTENT=""
	! "$DRAGON__ENABLE_EXIT_STATUS" && return
	(( _DRAGON_EXIT_CODE == 0 )) && return

	if "$DRAGON__ENABLE_FULL_EXIT_STATUS" && (( _DRAGON_EXIT_CODE > 128 )); then
		local sig_name
		sig_name="$(kill -l "$_DRAGON_EXIT_CODE" 2>/dev/null)"
		if [[ $? -eq 0 && -n "$sig_name" ]]; then
			REAL_DRAGON__EXIT_STATUS_CONTENT="SIG${sig_name}"
		else
			REAL_DRAGON__EXIT_STATUS_CONTENT="${_DRAGON_EXIT_CODE}"
		fi
	else
		REAL_DRAGON__EXIT_STATUS_CONTENT="${_DRAGON_EXIT_CODE}"
	fi
	__dragon_copy_defaults EXIT_STATUS
	__dragon_finalize EXIT_STATUS
}
