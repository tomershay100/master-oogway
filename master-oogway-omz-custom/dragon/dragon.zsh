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
typeset -g exit_code=0   # set by __save_exit_code; zero-initialized to avoid stale reads

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
local _dragon_k _dragon_v
for _dragon_k _dragon_v in "${(@kv)_DRAGON_DEFAULTS}"; do
	[[ "$_dragon_k" == "USE_NERD_FONT" ]] && continue
	set_if_unset "DRAGON__${_dragon_k}" "$_dragon_v"
done
unset _dragon_k _dragon_v

typeset -A COLORS=(
	[black]=000 [red]=001 [green]=002 [yellow]=003
	[blue]=004 [magenta]=005 [cyan]=006 [white]=007
	[gray]=008 [grey]=008 [maroon]=009 [lime]=010 [olive]=011
	[navy]=012 [fuchsia]=013 [aqua]=014 [silver]=015
)

# ── Source prompt parts ───────────────────────────────────────────────────────
# Order matters where one part calls helpers from another. The bottom of this
# file calls __update_prompt at load time, so all parts must be sourced first.

source "${0:a:h}/parts/helpers.zsh"          # color/style helpers, __dragon__show
source "${0:a:h}/parts/segments_left.zsh"    # username, hostname, directory, prompt_char, ssh_prefix
source "${0:a:h}/parts/separators.zsh"       # segment separators, multiline prompts
source "${0:a:h}/parts/git.zsh"              # git segment + gitstatus integration
source "${0:a:h}/parts/segments_right.zsh"   # date, exec_timer, ssh_conn, jobs, exit_status
source "${0:a:h}/parts/prompt.zsh"           # __calc_prompt_length, lprompt + rprompt builders
source "${0:a:h}/parts/transient.zsh"        # zle hooks, gitstatus glue, prompt refresh

# ── Initial render + hook registration ────────────────────────────────────────

__update_prompt

autoload -U add-zsh-hook

if (( ! ${preexec_functions[(Ie)__set_timer]} )); then
	add-zsh-hook preexec __set_timer
fi

add-zsh-hook preexec __mark_cmd_ran
add-zsh-hook precmd  __save_exit_code
add-zsh-hook precmd  __update_prompt
add-zsh-hook precmd  __reset_timer
add-zsh-hook chpwd   __update_prompt
add-zsh-hook chpwd   __dragon_track_chpwd

zle -N zle-line-finish __dragon_zle_line_finish
