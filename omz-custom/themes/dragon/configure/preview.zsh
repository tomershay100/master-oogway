# configure/preview.zsh — key reader + prompt preview renderers

# Read a single keypress without echoing it to the terminal.
# Uses stty to disable echo at the TTY driver level (more reliable than read -s).
_dragon_read_key() {
	local _dragon_stty
	_dragon_stty=$(stty -g 2>/dev/null)
	{
		stty -echo -icanon -isig min 1 time 0 2>/dev/null
		read -k1 "$1"
	} always {
		stty "$_dragon_stty" 2>/dev/null
	}
}

_dragon_render_preview() {
	# Run entirely in a subshell so all exports (DRAGON__*, SSH_TTY, VCS_STATUS_*)
	# are automatically discarded on exit — including Ctrl+C.
	(
		# Flags: --ssh, --fail, --transient, --group=<name>
		local ssh_mode=false fail_mode=false transient_mode=false group="" _dragon_flag
		for _dragon_flag in "$@"; do
			[[ "$_dragon_flag" == "--ssh"       ]] && ssh_mode=true
			[[ "$_dragon_flag" == "--fail"      ]] && fail_mode=true
			[[ "$_dragon_flag" == "--transient" ]] && transient_mode=true
			[[ "$_dragon_flag" == --group=*     ]] && group="${_dragon_flag#--group=}"
		done

		# Export all current DRAGON__ vars so the nested zsh -c inherits them.
		# The theme's set_if_unset only sets vars that are NOT already set,
		# so pre-exported vars act as overrides.
		local var val
		for var val in "${(@kv)_DRAGON_CURRENT}"; do
			export "DRAGON__${var}=${val}"
		done

		local preview_exit_code=0
		$ssh_mode  && export SSH_TTY=/dev/pts/0
		$fail_mode && preview_exit_code=1

		# Export group-specific fake data via env vars honoured by the theme segments.
		case "$group" in
			exec_timer)   export DRAGON__PREVIEW_FAKE_EXEC_TIME="1m 5s" ;;
			job_count)    export DRAGON__PREVIEW_FAKE_JOB_COUNT=2 ;;
			ssh_conn_count) export DRAGON__PREVIEW_FAKE_SSH_CONN_COUNT=2 ;;
			git_stash_remote)
				export VCS_STATUS_STASHES=2
				export VCS_STATUS_COMMITS_AHEAD=3
				export VCS_STATUS_COMMITS_BEHIND=1 ;;
			git_clean_dirty) export VCS_STATUS_HAS_UNSTAGED=1 ;;
		esac

		local preview
		preview=$(zsh -c "
			zle()             { :; }
			gitstatus_start() { :; }
			gitstatus_query() { :; }
			gitstatus_stop()  { :; }
			add-zsh-hook()    { :; }
			[[ '${ssh_mode}' != true ]] && unset SSH_TTY SSH_CONNECTION SSH_CLIENT
			HOME='${HOME}'
			PWD='/home/${USER}/projects/myapp/src/components'
			VCS_STATUS_RESULT='ok-sync'
			VCS_STATUS_LOCAL_BRANCH='main'
			VCS_STATUS_HAS_UNSTAGED=\${VCS_STATUS_HAS_UNSTAGED:-0}
			VCS_STATUS_HAS_STAGED=0
			VCS_STATUS_HAS_UNTRACKED=0
			VCS_STATUS_COMMITS_AHEAD=\${VCS_STATUS_COMMITS_AHEAD:-0}
			VCS_STATUS_COMMITS_BEHIND=\${VCS_STATUS_COMMITS_BEHIND:-0}
			VCS_STATUS_STASHES=\${VCS_STATUS_STASHES:-0}
			VCS_STATUS_REMOTE_NAME='origin'
			source '${_DRAGON_THEMES_DIR}/dragon.zsh' 2>/dev/null
			_DRAGON_EXIT_CODE=${preview_exit_code}
			__LAST_EXIT_CODE=${preview_exit_code}
			dragon__update_zsh_prompt 2>/dev/null
			if [[ '${transient_mode}' == true ]]; then
				__dragon_zle_line_finish 2>/dev/null
			fi
			print -rP -- \"\${PROMPT}\"
			[[ -n \"\${RPROMPT}\" ]] && printf 'RPROMPT: ' && print -rP -- \"\${RPROMPT}\"
		" 2>/dev/null)

		local label=""
		$ssh_mode       && label=" %F{245}(SSH)%f"
		$fail_mode      && label=" %F{245}(exit: 1)%f"
		$transient_mode && label=" %F{245}(after command — collapsed)%f"

		if [[ -n "$preview" ]]; then
			print -P "%F{245}  ┌────────────────────────────────────────────────────────%f${label}"
			while IFS= read -r pline; do
				# \033[m hard-resets color after each line so prompt color sequences
				# (e.g. green branch) don't bleed into the │ prefix on the next line.
				printf "  │ %s\033[m\n" "${pline}"
			done <<< "$preview"
			print -P "%F{245}  └────────────────────────────────────────────────────────%f"
		else
			print -P "  %F{245}(preview unavailable — theme file not found or error)%f"
		fi
	)
}

# Walk every registered preset, swap _DRAGON_CURRENT to its values, and print
# a banner + framed preview. Mutates _DRAGON_CURRENT — caller should _cleanup
# afterwards (or not care, e.g. one-shot --gallery flag).
_dragon_render_gallery() {
	local preset desc
	for preset in "${_DRAGON_PRESET_NAMES[@]}"; do
		desc="${_DRAGON_PRESET_DESC[$preset]:-}"
		_dragon_apply_preset "$preset"
		print ""
		print -P "%B%F{cyan}── ${preset} ──%f%b  %F{245}${desc}%f"
		_dragon_render_preview
	done
}
