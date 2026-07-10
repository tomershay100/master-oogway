dragon__update_zsh_prompt()
{
	dragon__set_lprompt
	dragon__set_rprompt
}

__refresh_prompt()
{
	dragon__set_lprompt
	# zle -F callbacks run inside ZLE; zle (no args) may return false here
	# even though we are in a ZLE context, so call reset-prompt unconditionally.
	zle reset-prompt 2>/dev/null
}

__update_prompt()
{
	_DRAGON_SSH_COUNT_CACHE=-1  # new prompt → recount SSH sessions once
	$DRAGON__ENABLE_GIT_STATUS && __update_gitstatusd
	dragon__update_zsh_prompt
}
