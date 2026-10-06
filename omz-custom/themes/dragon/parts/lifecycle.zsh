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

# Terminal resize: recompute the lprompt (git-on-new-line depends on COLUMNS)
# and repaint. TRAPWINCH can fire anytime SIGWINCH arrives, including mid-
# command or between commands with no ZLE context — the 2>/dev/null on
# reset-prompt is what makes those cases a no-op, not any property of the
# trap itself. zsh allows only one TRAPWINCH definition; save and delegate
# to whatever was already registered (tmux integrations, other plugins) so
# this doesn't clobber it.
#
# Install once per shell. `soursh` re-sources this file, and on the second pass
# TRAPWINCH is already ours — saving it would make _dragon_prev_trapwinch a copy
# of a body that calls _dragon_prev_trapwinch, i.e. self-recursion until
# FUNCNEST, and would drop the real foreign handler saved on the first pass.
if [[ -z ${_DRAGON_TRAPWINCH_INSTALLED-} ]]; then
	typeset -g _DRAGON_TRAPWINCH_INSTALLED=1
	if (( ${+functions[TRAPWINCH]} )); then
		functions[_dragon_prev_trapwinch]="${functions[TRAPWINCH]}"
	fi
fi
TRAPWINCH()
{
	dragon__set_lprompt
	zle reset-prompt 2>/dev/null
	(( ${+functions[_dragon_prev_trapwinch]} )) && _dragon_prev_trapwinch "$@"
}
