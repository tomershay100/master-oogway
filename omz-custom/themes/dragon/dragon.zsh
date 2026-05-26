# dragon.zsh — dragon prompt theme (master-oogway)
#
# Loads schema-driven defaults, sources prompt logic from parts/, and
# registers zsh hooks. All segment/render code lives in parts/*.zsh.
# Sourced by themes/dragon.zsh-theme (the OMZ entry point shim).

set_if_unset()
{
	local var_name="$1"
	local default="$2"
	if [[ ! -v "$var_name" ]]; then
		export "$var_name=$default"
	fi
}

__is_via_ssh()
{
	[[ -n "$SSH_CLIENT" || -n "$SSH_CONNECTION" || -n "$SSH_TTY" ]] || return 1
	return 0
}

TERMINAL_BACKGROUND_COLOR="black"
RESET_FORMAT="%f%k%b%u"
typeset -g _DRAGON_EXIT_CODE=0   # set by __save_exit_code; zero-initialized to avoid stale reads

# Load defaults from schema and apply them via set_if_unset.
# set_if_unset only sets vars not already exported — SSH-forwarded vars win.
# USE_NERD_FONT is handled separately: its default depends on SSH context.
source "${0:a:h}/schema.zsh"
_dragon_init_defaults
if __is_via_ssh; then
	set_if_unset DRAGON__USE_NERD_FONT false
else
	set_if_unset DRAGON__USE_NERD_FONT true
fi
typeset _dragon_k _dragon_v
for _dragon_k _dragon_v in "${(@kv)_DRAGON_DEFAULTS}"; do
	[[ "$_dragon_k" == "USE_NERD_FONT" ]] && continue
	set_if_unset "DRAGON__${_dragon_k}" "$_dragon_v"
done
unset _dragon_k _dragon_v

source "${0:a:h}/../../lib/colors.zsh"

# ── Source prompt parts ───────────────────────────────────────────────────────
# Order matters where one part calls helpers from another. The bottom of this
# file calls __update_prompt at load time, so all parts must be sourced first.

source "${0:a:h}/parts/helpers.zsh"          # color/style helpers, __dragon__show
source "${0:a:h}/parts/segments_left.zsh"    # username, hostname, directory, prompt_char, ssh_prefix
source "${0:a:h}/parts/separators.zsh"       # segment separators, multiline prompts
source "${0:a:h}/parts/git.zsh"              # git segment rendering
source "${0:a:h}/parts/gitstatus.zsh"        # gitstatus daemon lifecycle + availability guard
source "${0:a:h}/parts/segments_right.zsh"   # date, exec_timer, ssh_conn, jobs, exit_status
source "${0:a:h}/parts/prompt.zsh"           # __calc_prompt_length, lprompt + rprompt builders
source "${0:a:h}/parts/lifecycle.zsh"        # __update_prompt, __refresh_prompt, dragon__update_zsh_prompt
source "${0:a:h}/parts/transient.zsh"        # zle hooks, transient prompt collapse

# ── Initial render + hook registration ────────────────────────────────────────

__update_prompt

autoload -U add-zsh-hook

add-zsh-hook preexec __set_timer
add-zsh-hook preexec __mark_cmd_ran
add-zsh-hook precmd  __save_exit_code
# precmd alone covers cd: zsh fires precmd before every prompt, including
# after a directory change. A chpwd-triggered __update_prompt would just be
# overwritten by the precmd one moments later (and double the gitstatus work).
add-zsh-hook precmd  __update_prompt
# __reset_timer is intentionally NOT registered here. timer is reset by
# __set_timer in preexec (timer=$SECONDS overwrites it). Keeping timer set
# through precmd + async gitstatus callback means __refresh_prompt sees the
# correct exec time and doesn't blank it out after gitstatus returns.
add-zsh-hook chpwd   __dragon_track_chpwd

zle -N zle-line-finish __dragon_zle_line_finish
