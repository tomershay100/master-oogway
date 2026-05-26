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
	# Skip silently when the gitstatus plugin was not sourced (submodule missing).
	# VCS_STATUS_RESULT is left unset so dragon__set_git_prompt renders nothing.
	$_DRAGON_GITSTATUS_AVAILABLE || return 0
	__start_gitstatus_once
	gitstatus_query -d "$PWD" -c __refresh_prompt -t 0 "$_GITSTATUS_NAME"
}
