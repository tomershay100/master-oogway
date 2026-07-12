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
_DRAGON_TIMER_ACTIVE=false
_DRAGON_TIMER=-1

__set_timer()
{
	_DRAGON_TIMER=$SECONDS
	_DRAGON_TIMER_ACTIVE=true
	FINAL_DRAGON__EXEC_TIMER_CONTENT=""
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
	! $DRAGON__ENABLE_EXEC_TIMER && { FINAL_DRAGON__EXEC_TIMER_CONTENT=""; return; }

	if ! $_DRAGON_TIMER_ACTIVE; then
		# No command ran (bare Enter) or already consumed — preserve the last
		# rendered value so the async gitstatus repaint doesn't blank it out.
		return
	elif ((_DRAGON_TIMER == -1 || SECONDS - _DRAGON_TIMER < $DRAGON__EXEC_TIMER_THRESHOLD)); then
		FINAL_DRAGON__EXEC_TIMER_CONTENT=""
		_DRAGON_TIMER_ACTIVE=false
		return
	else
		# Call without $() to avoid a subshell — result written to _DRAGON_READABLE_TIME
		__get_readable_time $((SECONDS - _DRAGON_TIMER))
		REAL_DRAGON__EXEC_TIMER_CONTENT="${_DRAGON_READABLE_TIME}"
		unset _DRAGON_READABLE_TIME
	fi

	__dragon_copy_defaults EXEC_TIMER
	__dragon_finalize EXEC_TIMER
	# Mark consumed after a successful render. The async gitstatus repaint
	# fires in the same precmd cycle and will hit the early return above,
	# preserving FINAL_DRAGON__EXEC_TIMER_CONTENT from this render.
	_DRAGON_TIMER_ACTIVE=false
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

	local jobs_count="${#jobstates[@]}"
	(( jobs_count == 0 )) && return

	REAL_DRAGON__JOB_COUNT_CONTENT="%j"
	__dragon_copy_defaults JOB_COUNT
	__set_job_count_prefix_and_suffix_singular
	__dragon_finalize JOB_COUNT
}

# Per-prompt cache: -1 = stale. Reset in __update_prompt (precmd) so each new
# prompt recounts, while the async gitstatus repaint of the SAME prompt reuses
# the cached value instead of forking `who` again.
typeset -g _DRAGON_SSH_COUNT_CACHE=-1

__set_ssh_connection_count_content()
{
	if (( _DRAGON_SSH_COUNT_CACHE >= 0 )); then
		REAL_DRAGON__SSH_CONNECTION_COUNT_CONTENT="$_DRAGON_SSH_COUNT_CACHE"
		return
	fi

	# Count remote pts sessions: any who line with a pts tty and a parenthesized
	# address field — covers IPv4, IPv6 literals, and hostname-based sessions.
	local -a remote_addrs=()
	local line
	while IFS= read -r line; do
		[[ "$line" == *pts* ]] || continue
		local addr="${line##* }"
		[[ "$addr" == \(* && "$addr" == *\) ]] && remote_addrs+=( "$addr" )
	done < <(who)

	local connection_count=${#remote_addrs}
	if __is_via_ssh && [[ -n "$SSH_CLIENT" ]]; then
		local current_addr="(${SSH_CLIENT%% *})"
		local -a other_addrs=( "${remote_addrs[@]:#$current_addr}" )
		connection_count=${#other_addrs}
	fi

	_DRAGON_SSH_COUNT_CACHE=$connection_count
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
		# No command ran (bare Enter) — clear the exec timer so it doesn't
		# persist from the previous command across blank prompts.
		FINAL_DRAGON__EXEC_TIMER_CONTENT=""
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
