_IS_GITSTATUS_RUNNING=false
_GITSTATUS_NAME="MY_GIT"
# Set once at source time: true only when the gitstatus plugin was sourced
# successfully and its functions are available.
(( $+functions[gitstatus_query] )) && _DRAGON_GITSTATUS_AVAILABLE=true || _DRAGON_GITSTATUS_AVAILABLE=false

__start_gitstatus_once()
{
	$_IS_GITSTATUS_RUNNING && return
	# Only mark running on success — a failed start (missing binary, cgroup
	# error) must not suppress all future retries by setting the flag early.
	if gitstatus_start -s -1 -u -1 -c -1 -d -1 "$_GITSTATUS_NAME" 2>/dev/null; then
		_IS_GITSTATUS_RUNNING=true
	fi
}

__update_gitstatusd()
{
	# Skip when the gitstatus plugin was not sourced (submodule missing).
	# Unset stale VCS_STATUS_* so dragon__set_git_prompt renders nothing.
	if ! $_DRAGON_GITSTATUS_AVAILABLE; then
		unset VCS_STATUS_RESULT VCS_STATUS_WORKDIR VCS_STATUS_LOCAL_BRANCH \
		      VCS_STATUS_REMOTE_NAME VCS_STATUS_COMMIT VCS_STATUS_COMMITS_AHEAD \
		      VCS_STATUS_COMMITS_BEHIND VCS_STATUS_HAS_STAGED VCS_STATUS_HAS_UNSTAGED \
		      VCS_STATUS_STASHES
		return 0
	fi
	__start_gitstatus_once
	gitstatus_query -d "$PWD" -c __refresh_prompt -t 0 "$_GITSTATUS_NAME"
}
