# dragon.zsh-theme

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

## background color segments separators
set_if_unset APPA_FINO__LEFT_SEGMENT_SEPARATOR $'\uE0B0'
set_if_unset APPA_FINO__LEFT_SEGMENT_SEPARATOR_SAME_COLOR $'\uE0B1'

set_if_unset APPA_FINO__RIGHT_SEGMENT_SEPARATOR $'\uE0B2'
set_if_unset APPA_FINO__RIGHT_SEGMENT_SEPARATOR_SAME_COLOR $'\uE0B3'

if __is_via_ssh; then
	set_if_unset APPA_FINO__USE_NERD_FONT false
else
	set_if_unset APPA_FINO__USE_NERD_FONT true
fi

## username in lprompt
set_if_unset APPA_FINO__ENABLE_USERNAME true
set_if_unset APPA_FINO__USERNAME_FOREGROUND_COLOR "navy"
set_if_unset APPA_FINO__USERNAME_BACKGROUND_COLOR ""
set_if_unset APPA_FINO__USERNAME_BOLD false
set_if_unset APPA_FINO__USERNAME_UNDERLINE false
set_if_unset APPA_FINO__USERNAME_PREFIX ""
set_if_unset APPA_FINO__USERNAME_SUFFIX ""
set_if_unset APPA_FINO__ENABLE_USERNAME_COLORING_VIA_SSH false
set_if_unset APPA_FINO__USERNAME_VIA_SSH_FOREGROUND_COLOR ""
set_if_unset APPA_FINO__USERNAME_VIA_SSH_BACKGROUND_COLOR ""
set_if_unset APPA_FINO__USERNAME_VIA_SSH_BOLD false
set_if_unset APPA_FINO__USERNAME_VIA_SSH_UNDERLINE false

## hostname in lprompt
set_if_unset APPA_FINO__ENABLE_HOSTNAME true
set_if_unset APPA_FINO__HOSTNAME_FOREGROUND_COLOR "fuchsia"
set_if_unset APPA_FINO__HOSTNAME_BACKGROUND_COLOR ""
set_if_unset APPA_FINO__HOSTNAME_BOLD false
set_if_unset APPA_FINO__HOSTNAME_UNDERLINE false
set_if_unset APPA_FINO__HOSTNAME_PREFIX ""
set_if_unset APPA_FINO__HOSTNAME_SUFFIX ""
set_if_unset APPA_FINO__ENABLE_HOSTNAME_COLORING_VIA_SSH true
set_if_unset APPA_FINO__HOSTNAME_VIA_SSH_FOREGROUND_COLOR "maroon"
set_if_unset APPA_FINO__HOSTNAME_VIA_SSH_BACKGROUND_COLOR ""
set_if_unset APPA_FINO__HOSTNAME_VIA_SSH_BOLD false
set_if_unset APPA_FINO__HOSTNAME_VIA_SSH_UNDERLINE false

## directory in lprompt
set_if_unset APPA_FINO__ENABLE_DIRECTORY true
set_if_unset APPA_FINO__DIRECTORY_FOREGROUND_COLOR "olive"
set_if_unset APPA_FINO__DIRECTORY_BACKGROUND_COLOR ""
set_if_unset APPA_FINO__DIRECTORY_BOLD false
set_if_unset APPA_FINO__DIRECTORY_UNDERLINE false
set_if_unset APPA_FINO__DIRECTORY_PREFIX ""
set_if_unset APPA_FINO__DIRECTORY_SUFFIX " "
set_if_unset APPA_FINO__DIRECTORY_FORMAT "regular"

## prompt character settings 
set_if_unset APPA_FINO__PROMPT_CHAR "❯"
set_if_unset APPA_FINO__GIT_PROMPT_CHAR "❯"
set_if_unset APPA_FINO__PROMPT_CHAR_DEFAULT_FOREGROUND_COLOR "silver"
set_if_unset APPA_FINO__PROMPT_CHAR_DEFAULT_BACKGROUND_COLOR ""
set_if_unset APPA_FINO__PROMPT_CHAR_DEFAULT_BOLD false
set_if_unset APPA_FINO__PROMPT_CHAR_DEFAULT_UNDERLINE false
set_if_unset APPA_FINO__PROMPT_CHAR_PREFIX ""
set_if_unset APPA_FINO__PROMPT_CHAR_SUFFIX " "

set_if_unset APPA_FINO__ENABLE_EXIT_STATUS_PROMPT_COLORING true
set_if_unset APPA_FINO__PROMPT_CHAR_SUCCESS_FOREGROUND_COLOR "lime"
set_if_unset APPA_FINO__PROMPT_CHAR_SUCCESS_BACKGROUND_COLOR ""
set_if_unset APPA_FINO__PROMPT_CHAR_SUCCESS_BOLD false
set_if_unset APPA_FINO__PROMPT_CHAR_SUCCESS_UNDERLINE false
set_if_unset APPA_FINO__PROMPT_CHAR_FAILURE_FOREGROUND_COLOR "maroon"
set_if_unset APPA_FINO__PROMPT_CHAR_FAILURE_BACKGROUND_COLOR ""
set_if_unset APPA_FINO__PROMPT_CHAR_FAILURE_BOLD false
set_if_unset APPA_FINO__PROMPT_CHAR_FAILURE_UNDERLINE false

## transient prompt — collapse previous prompt to a single char after execution
## values: true (always), false (never), per-dir (only within the same directory)
set_if_unset APPA_FINO__ENABLE_TRANSIENT_PROMPT "per-dir"
set_if_unset APPA_FINO__TRANSIENT_PROMPT_CHAR ""  # empty = use APPA_FINO__PROMPT_CHAR
## verbose transient — when true, keeps rprompt (exit code, jobs, timer, time) on collapsed lines
set_if_unset APPA_FINO__TRANSIENT_PROMPT_VERBOSE true

## lprompt prefix when ssh
set_if_unset APPA_FINO__ENABLE_SSH_PREFIX true
set_if_unset APPA_FINO__SSH_PREFIX "via ssh:"
set_if_unset APPA_FINO__SSH_PREFIX_FOREGROUND_COLOR "red"
set_if_unset APPA_FINO__SSH_PREFIX_BACKGROUND_COLOR ""
set_if_unset APPA_FINO__SSH_PREFIX_BOLD false
set_if_unset APPA_FINO__SSH_PREFIX_UNDERLINE false

## git status in lprompt
set_if_unset APPA_FINO__ENABLE_GIT_STATUS true
set_if_unset APPA_FINO__GIT_STATUS_ON_NEW_LINE "auto"
set_if_unset APPA_FINO__GIT_STATUS_PREFIX " on "
set_if_unset APPA_FINO__GIT_STATUS_SUFFIX " "
set_if_unset APPA_FINO__GIT_BRANCH_PREFIX ""
set_if_unset APPA_FINO__GIT_BRANCH_SUFFIX ""

## git stash count
set_if_unset APPA_FINO__ENABLE_GIT_STASH_COUNT false
set_if_unset APPA_FINO__GIT_STASH_SYMBOL "⚑"

## git remote tracking state (ahead/behind/synced)
set_if_unset APPA_FINO__ENABLE_GIT_REMOTE_STATE false
set_if_unset APPA_FINO__GIT_REMOTE_AHEAD_SYMBOL "↑"
set_if_unset APPA_FINO__GIT_REMOTE_BEHIND_SYMBOL "↓"
set_if_unset APPA_FINO__GIT_REMOTE_SYNCED_SYMBOL "≡"

set_if_unset APPA_FINO__GIT_CLEAN_SUFFIX ""
set_if_unset APPA_FINO__GIT_CLEAN_FOREGROUND_COLOR "black"
set_if_unset APPA_FINO__GIT_CLEAN_BACKGROUND_COLOR "green"
set_if_unset APPA_FINO__GIT_CLEAN_BOLD false
set_if_unset APPA_FINO__GIT_CLEAN_UNDERLINE false

set_if_unset APPA_FINO__GIT_DIRTY_SUFFIX "*"
set_if_unset APPA_FINO__GIT_DIRTY_FOREGROUND_COLOR "black"
set_if_unset APPA_FINO__GIT_DIRTY_BACKGROUND_COLOR "aqua"
set_if_unset APPA_FINO__GIT_DIRTY_BOLD false
set_if_unset APPA_FINO__GIT_DIRTY_UNDERLINE false

## prompt separators color
set_if_unset APPA_FINO__PROMPT_SEPARATOR_FOREGROUND_COLOR "white"
set_if_unset APPA_FINO__PROMPT_SEPARATOR_BACKGROUND_COLOR ""
set_if_unset APPA_FINO__PROMPT_SEPARATOR_BOLD false
set_if_unset APPA_FINO__PROMPT_SEPARATOR_UNDERLINE false
set_if_unset APPA_FINO__USER_HOST_SEPARATOR "@"
set_if_unset APPA_FINO__HOST_DIR_SEPARATOR ":"

set_if_unset APPA_FINO__ENABLE_MULTILINE true
set_if_unset APPA_FINO__FIRST_LINE_SEPARATOR_CHAR ""
set_if_unset APPA_FINO__NEW_LINE_SEPARATOR_CHAR ""
set_if_unset APPA_FINO__LAST_LINE_SEPARATOR_CHAR ""

## date and time in rprompt
set_if_unset APPA_FINO__ENABLE_DATE_TIME true
set_if_unset APPA_FINO__DATE_TIME_FORMAT "%D{%H:%M:%S}"
set_if_unset APPA_FINO__DATE_TIME_FOREGROUND_COLOR "white"
set_if_unset APPA_FINO__DATE_TIME_BACKGROUND_COLOR ""
set_if_unset APPA_FINO__DATE_TIME_BOLD false
set_if_unset APPA_FINO__DATE_TIME_UNDERLINE false
set_if_unset APPA_FINO__DATE_TIME_PREFIX " "
set_if_unset APPA_FINO__DATE_TIME_SUFFIX ""

## execution timer in rprompt
set_if_unset APPA_FINO__ENABLE_EXEC_TIMER true
set_if_unset APPA_FINO__EXEC_TIMER_FOREGROUND_COLOR "black"
set_if_unset APPA_FINO__EXEC_TIMER_BACKGROUND_COLOR "olive"
set_if_unset APPA_FINO__EXEC_TIMER_BOLD false
set_if_unset APPA_FINO__EXEC_TIMER_UNDERLINE false
set_if_unset APPA_FINO__EXEC_TIMER_PREFIX " took "
set_if_unset APPA_FINO__EXEC_TIMER_SUFFIX " "
set_if_unset APPA_FINO__EXEC_TIMER_THRESHOLD 2

## incoming SSH connection count in rprompt
set_if_unset APPA_FINO__ENABLE_SSH_CONNECTION_COUNT true
set_if_unset APPA_FINO__SSH_CONNECTION_COUNT_FOREGROUND_COLOR "black"
set_if_unset APPA_FINO__SSH_CONNECTION_COUNT_BACKGROUND_COLOR "fuchsia"
set_if_unset APPA_FINO__SSH_CONNECTION_COUNT_BOLD false
set_if_unset APPA_FINO__SSH_CONNECTION_COUNT_UNDERLINE false
set_if_unset APPA_FINO__SSH_CONNECTION_COUNT_PREFIX " conn="
set_if_unset APPA_FINO__SSH_CONNECTION_COUNT_SUFFIX " "

## background jobs count in rprompt
set_if_unset APPA_FINO__ENABLE_JOB_COUNT true
set_if_unset APPA_FINO__JOB_COUNT_FOREGROUND_COLOR "black"
set_if_unset APPA_FINO__JOB_COUNT_BACKGROUND_COLOR "blue"
set_if_unset APPA_FINO__JOB_COUNT_BOLD false
set_if_unset APPA_FINO__JOB_COUNT_UNDERLINE false
set_if_unset APPA_FINO__JOB_COUNT_PREFIX " "
set_if_unset APPA_FINO__JOB_COUNT_SUFFIX " jobs "

## exit status in rprompt
set_if_unset APPA_FINO__ENABLE_EXIT_STATUS true
set_if_unset APPA_FINO__ENABLE_FULL_EXIT_STATUS true
set_if_unset APPA_FINO__EXIT_STATUS_FOREGROUND_COLOR "black"
set_if_unset APPA_FINO__EXIT_STATUS_BACKGROUND_COLOR "red"
set_if_unset APPA_FINO__EXIT_STATUS_BOLD false
set_if_unset APPA_FINO__EXIT_STATUS_UNDERLINE false
set_if_unset APPA_FINO__EXIT_STATUS_PREFIX " "
set_if_unset APPA_FINO__EXIT_STATUS_SUFFIX " "

declare -A COLORS=(
	[black]=000 [red]=001 [green]=002 [yellow]=003
	[blue]=004 [magenta]=005 [cyan]=006 [white]=007
	[gray]=008 [grey]=008 [maroon]=009 [lime]=010 [olive]=011
	[navy]=012 [fuchsia]=013 [aqua]=014 [silver]=015
)

__get_xterm_color_by_name()
{
	XTERM_COLOR=""
	local color_name="$1"

	if [[ $color_name =~ ^[0-9]+$ && 10#$color_name -le 255 ]]; then # check for 256-colors
		XTERM_COLOR="$color_name"
		return
	fi

	local fg_code="${COLORS[${(L)color_name}]}"
	if [[ -n "$fg_code" ]]; then
		XTERM_COLOR="$fg_code"
	fi
}

__get_xterm_style_format()
{
	local fg_color="$1"
	local bg_color="$2"
	local is_bold="$3"
	local is_underline="$4"

	STYLE_FORMAT=""
	[[ "$is_bold" == "true" ]] && STYLE_FORMAT+="%B" || STYLE_FORMAT+="%b"
	[[ "$is_underline" == "true" ]] && STYLE_FORMAT+="%U" || STYLE_FORMAT+="%u"

	__get_xterm_color_by_name "$fg_color"
	local fg_code="$XTERM_COLOR"
	if [[ -n "$fg_code" ]]; then
		STYLE_FORMAT+="%F{$fg_code}"
	else
		STYLE_FORMAT+="%f"
	fi

	__get_xterm_color_by_name "$bg_color"
	local bg_code="$XTERM_COLOR"
	if [[ -n "$bg_code" ]]; then
		STYLE_FORMAT+="%K{$bg_code}"
	else
		STYLE_FORMAT+="%k"
	fi
}

__dragon__show()
{
	local name="$1"

	local var_content="REAL_APPA_FINO__${name}_CONTENT"
	local var_prefix="REAL_APPA_FINO__${name}_PREFIX"
	local var_suffix="REAL_APPA_FINO__${name}_SUFFIX"

	local var_fg_color="REAL_APPA_FINO__${name}_FOREGROUND_COLOR"
	local var_bg_color="REAL_APPA_FINO__${name}_BACKGROUND_COLOR"
	local var_is_bold="REAL_APPA_FINO__${name}_BOLD"
	local var_is_underline="REAL_APPA_FINO__${name}_UNDERLINE"

	local curr_content="${(P)var_content}"
	local curr_prefix="${${(P)var_prefix}//\%/%%}"
	local curr_suffix="${${(P)var_suffix}//\%/%%}"

	local curr_fg_color="${(P)var_fg_color}"
	local curr_bg_color="${(P)var_bg_color}"
	local curr_is_bold="${(P)var_is_bold}"
	local curr_is_underline="${(P)var_is_underline}"
	
	__get_xterm_style_format "$curr_fg_color" "$curr_bg_color" "$curr_is_bold" "$curr_is_underline"

	SHOW_RESULT="$RESET_FORMAT$STYLE_FORMAT$curr_prefix$curr_content$curr_suffix$RESET_FORMAT"
}

__set_username_color()
{
	REAL_APPA_FINO__USERNAME_FOREGROUND_COLOR="$APPA_FINO__USERNAME_FOREGROUND_COLOR"
	REAL_APPA_FINO__USERNAME_BACKGROUND_COLOR="$APPA_FINO__USERNAME_BACKGROUND_COLOR"
	REAL_APPA_FINO__USERNAME_BOLD="$APPA_FINO__USERNAME_BOLD"
	REAL_APPA_FINO__USERNAME_UNDERLINE="$APPA_FINO__USERNAME_UNDERLINE"
	if $APPA_FINO__ENABLE_USERNAME_COLORING_VIA_SSH && __is_via_ssh; then
		REAL_APPA_FINO__USERNAME_FOREGROUND_COLOR="$APPA_FINO__USERNAME_VIA_SSH_FOREGROUND_COLOR"
		REAL_APPA_FINO__USERNAME_BACKGROUND_COLOR="$APPA_FINO__USERNAME_VIA_SSH_BACKGROUND_COLOR"
		REAL_APPA_FINO__USERNAME_BOLD="$APPA_FINO__USERNAME_VIA_SSH_BOLD"
		REAL_APPA_FINO__USERNAME_UNDERLINE="$APPA_FINO__USERNAME_VIA_SSH_UNDERLINE"
	fi
}

dragon__set_username()
{
	FINAL_APPA_FINO__USERNAME_CONTENT=""
	! $APPA_FINO__ENABLE_USERNAME && return

	REAL_APPA_FINO__USERNAME_CONTENT="%n"

	REAL_APPA_FINO__USERNAME_PREFIX="$APPA_FINO__USERNAME_PREFIX"
	REAL_APPA_FINO__USERNAME_SUFFIX="$APPA_FINO__USERNAME_SUFFIX"

	__set_username_color

	__dragon__show "USERNAME"
	FINAL_APPA_FINO__USERNAME_CONTENT="$SHOW_RESULT"
}

__set_hostname_color()
{
	REAL_APPA_FINO__HOSTNAME_FOREGROUND_COLOR="$APPA_FINO__HOSTNAME_FOREGROUND_COLOR"
	REAL_APPA_FINO__HOSTNAME_BACKGROUND_COLOR="$APPA_FINO__HOSTNAME_BACKGROUND_COLOR"
	REAL_APPA_FINO__HOSTNAME_BOLD="$APPA_FINO__HOSTNAME_BOLD"
	REAL_APPA_FINO__HOSTNAME_UNDERLINE="$APPA_FINO__HOSTNAME_UNDERLINE"
	if $APPA_FINO__ENABLE_HOSTNAME_COLORING_VIA_SSH && __is_via_ssh; then
		REAL_APPA_FINO__HOSTNAME_FOREGROUND_COLOR="$APPA_FINO__HOSTNAME_VIA_SSH_FOREGROUND_COLOR"
		REAL_APPA_FINO__HOSTNAME_BACKGROUND_COLOR="$APPA_FINO__HOSTNAME_VIA_SSH_BACKGROUND_COLOR"
		REAL_APPA_FINO__HOSTNAME_BOLD="$APPA_FINO__HOSTNAME_VIA_SSH_BOLD"
		REAL_APPA_FINO__HOSTNAME_UNDERLINE="$APPA_FINO__HOSTNAME_VIA_SSH_UNDERLINE"
	fi
}

dragon__set_hostname()
{
	FINAL_APPA_FINO__HOSTNAME_CONTENT=""
	! $APPA_FINO__ENABLE_HOSTNAME && return

	REAL_APPA_FINO__HOSTNAME_CONTENT="%m"

	REAL_APPA_FINO__HOSTNAME_PREFIX="$APPA_FINO__HOSTNAME_PREFIX"
	REAL_APPA_FINO__HOSTNAME_SUFFIX="$APPA_FINO__HOSTNAME_SUFFIX"

	__set_hostname_color

	__dragon__show "HOSTNAME"
	FINAL_APPA_FINO__HOSTNAME_CONTENT="$SHOW_RESULT"
}

__set_directory_content()
{
	REAL_APPA_FINO__DIRECTORY_CONTENT="%~"
	if [[ $APPA_FINO__DIRECTORY_FORMAT == "short" ]]; then
		REAL_APPA_FINO__DIRECTORY_CONTENT="%1~"
	elif [[ $APPA_FINO__DIRECTORY_FORMAT == "full" ]]; then
		REAL_APPA_FINO__DIRECTORY_CONTENT="%d"
	fi
}

dragon__set_directory()
{
	FINAL_APPA_FINO__DIRECTORY_CONTENT=""
	! $APPA_FINO__ENABLE_DIRECTORY && return

	__set_directory_content

	REAL_APPA_FINO__DIRECTORY_PREFIX="$APPA_FINO__DIRECTORY_PREFIX"
	REAL_APPA_FINO__DIRECTORY_SUFFIX="$APPA_FINO__DIRECTORY_SUFFIX"

	REAL_APPA_FINO__DIRECTORY_FOREGROUND_COLOR="$APPA_FINO__DIRECTORY_FOREGROUND_COLOR"
	REAL_APPA_FINO__DIRECTORY_BACKGROUND_COLOR="$APPA_FINO__DIRECTORY_BACKGROUND_COLOR"
	REAL_APPA_FINO__DIRECTORY_BOLD="$APPA_FINO__DIRECTORY_BOLD"
	REAL_APPA_FINO__DIRECTORY_UNDERLINE="$APPA_FINO__DIRECTORY_UNDERLINE"

	__dragon__show "DIRECTORY"
	FINAL_APPA_FINO__DIRECTORY_CONTENT="$SHOW_RESULT"
}

__set_prompt_char_content()
{
	REAL_APPA_FINO__PROMPT_CHAR_CONTENT="$APPA_FINO__PROMPT_CHAR"
	if [[ $VCS_STATUS_RESULT == "ok-sync" ]]; then
		[[ -z $APPA_FINO__GIT_PROMPT_CHAR ]] && return
		REAL_APPA_FINO__PROMPT_CHAR_CONTENT="$APPA_FINO__GIT_PROMPT_CHAR"
	fi
}

__set_prompt_char_color()
{
	REAL_APPA_FINO__PROMPT_CHAR_FOREGROUND_COLOR="$APPA_FINO__PROMPT_CHAR_DEFAULT_FOREGROUND_COLOR"
	REAL_APPA_FINO__PROMPT_CHAR_BACKGROUND_COLOR="$APPA_FINO__PROMPT_CHAR_DEFAULT_BACKGROUND_COLOR"
	REAL_APPA_FINO__PROMPT_CHAR_BOLD="$APPA_FINO__PROMPT_CHAR_DEFAULT_BOLD"
	REAL_APPA_FINO__PROMPT_CHAR_UNDERLINE="$APPA_FINO__PROMPT_CHAR_DEFAULT_UNDERLINE"

	if $APPA_FINO__ENABLE_EXIT_STATUS_PROMPT_COLORING; then
		if [[ "$exit_code" -eq 0 ]]; then
			REAL_APPA_FINO__PROMPT_CHAR_FOREGROUND_COLOR="$APPA_FINO__PROMPT_CHAR_SUCCESS_FOREGROUND_COLOR"
			REAL_APPA_FINO__PROMPT_CHAR_BACKGROUND_COLOR="$APPA_FINO__PROMPT_CHAR_SUCCESS_BACKGROUND_COLOR"
			REAL_APPA_FINO__PROMPT_CHAR_BOLD="$APPA_FINO__PROMPT_CHAR_SUCCESS_BOLD"
			REAL_APPA_FINO__PROMPT_CHAR_UNDERLINE="$APPA_FINO__PROMPT_CHAR_SUCCESS_UNDERLINE"
		else
			REAL_APPA_FINO__PROMPT_CHAR_FOREGROUND_COLOR="$APPA_FINO__PROMPT_CHAR_FAILURE_FOREGROUND_COLOR"
			REAL_APPA_FINO__PROMPT_CHAR_BACKGROUND_COLOR="$APPA_FINO__PROMPT_CHAR_FAILURE_BACKGROUND_COLOR"
			REAL_APPA_FINO__PROMPT_CHAR_BOLD="$APPA_FINO__PROMPT_CHAR_FAILURE_BOLD"
			REAL_APPA_FINO__PROMPT_CHAR_UNDERLINE="$APPA_FINO__PROMPT_CHAR_FAILURE_UNDERLINE"
		fi
	fi
}

dragon__set_prompt_char()
{
	FINAL_PROMPT_CHAR_CONTENT=""
	[[ -z $APPA_FINO__PROMPT_CHAR ]] && return

	__set_prompt_char_content

	REAL_APPA_FINO__PROMPT_CHAR_PREFIX="$APPA_FINO__PROMPT_CHAR_PREFIX"
	REAL_APPA_FINO__PROMPT_CHAR_SUFFIX="$APPA_FINO__PROMPT_CHAR_SUFFIX"

	__set_prompt_char_color

	__dragon__show "PROMPT_CHAR"
	FINAL_PROMPT_CHAR_CONTENT="$SHOW_RESULT"
}

dragon__set_ssh_prefix()
{
	FINAL_APPA_FINO__SSH_PREFIX_CONTENT=""
	! $APPA_FINO__ENABLE_SSH_PREFIX && return
	[[ -z $APPA_FINO__SSH_PREFIX ]] && return
	__is_via_ssh || return

	REAL_APPA_FINO__SSH_PREFIX_CONTENT="$APPA_FINO__SSH_PREFIX"

	REAL_APPA_FINO__SSH_PREFIX_PREFIX=""
	REAL_APPA_FINO__SSH_PREFIX_SUFFIX=""

	REAL_APPA_FINO__SSH_PREFIX_FOREGROUND_COLOR="$APPA_FINO__SSH_PREFIX_FOREGROUND_COLOR"
	REAL_APPA_FINO__SSH_PREFIX_BACKGROUND_COLOR="$APPA_FINO__SSH_PREFIX_BACKGROUND_COLOR"
	REAL_APPA_FINO__SSH_PREFIX_BOLD="$APPA_FINO__SSH_PREFIX_BOLD"
	REAL_APPA_FINO__SSH_PREFIX_UNDERLINE="$APPA_FINO__SSH_PREFIX_UNDERLINE"

	__dragon__show "SSH_PREFIX"
	FINAL_APPA_FINO__SSH_PREFIX_CONTENT="$SHOW_RESULT"
}

__set_separator_parameters()
{
	REAL_APPA_FINO__PROMPT_SEPARATOR_PREFIX=""
	REAL_APPA_FINO__PROMPT_SEPARATOR_SUFFIX=""
	REAL_APPA_FINO__PROMPT_SEPARATOR_FOREGROUND_COLOR="$APPA_FINO__PROMPT_SEPARATOR_FOREGROUND_COLOR"
	REAL_APPA_FINO__PROMPT_SEPARATOR_BACKGROUND_COLOR="$APPA_FINO__PROMPT_SEPARATOR_BACKGROUND_COLOR"
	REAL_APPA_FINO__PROMPT_SEPARATOR_BOLD="$APPA_FINO__PROMPT_SEPARATOR_BOLD"
	REAL_APPA_FINO__PROMPT_SEPARATOR_UNDERLINE="$APPA_FINO__PROMPT_SEPARATOR_UNDERLINE"
}

dragon__set_user_host_separator()
{
	FINAL_APPA_FINO__USER_HOST_SEPARATOR_CONTENT=""
	[[ -z $APPA_FINO__USER_HOST_SEPARATOR ]] && return

	REAL_APPA_FINO__PROMPT_SEPARATOR_CONTENT="$APPA_FINO__USER_HOST_SEPARATOR"
	__set_separator_parameters

	__dragon__show "PROMPT_SEPARATOR"
	FINAL_APPA_FINO__USER_HOST_SEPARATOR_CONTENT="$SHOW_RESULT"
}

dragon__set_host_dir_separator()
{
	FINAL_APPA_FINO__HOST_DIR_SEPARATOR_CONTENT=""
	[[ -z $APPA_FINO__HOST_DIR_SEPARATOR ]] && return

	REAL_APPA_FINO__PROMPT_SEPARATOR_CONTENT="$APPA_FINO__HOST_DIR_SEPARATOR"
	__set_separator_parameters

	__dragon__show "PROMPT_SEPARATOR"
	FINAL_APPA_FINO__HOST_DIR_SEPARATOR_CONTENT="$SHOW_RESULT"
}

dragon__set_multiline_first_line_prompt()
{
	FINAL_APPA_FINO__MULTILINE_FIRST_LINE_SEPARATOR_CONTENT=""
	[[ -z $APPA_FINO__FIRST_LINE_SEPARATOR_CHAR ]] && return

	REAL_APPA_FINO__PROMPT_SEPARATOR_CONTENT="$APPA_FINO__FIRST_LINE_SEPARATOR_CHAR"
	__set_separator_parameters

	__dragon__show "PROMPT_SEPARATOR"
	FINAL_APPA_FINO__MULTILINE_FIRST_LINE_SEPARATOR_CONTENT="$SHOW_RESULT"
}

dragon__set_multiline_new_line_prompt()
{
	FINAL_APPA_FINO__MULTILINE_NEW_LINE_SEPARATOR_CONTENT=""
	[[ -z $APPA_FINO__NEW_LINE_SEPARATOR_CHAR ]] && return

	REAL_APPA_FINO__PROMPT_SEPARATOR_CONTENT="$APPA_FINO__NEW_LINE_SEPARATOR_CHAR"
	__set_separator_parameters

	__dragon__show "PROMPT_SEPARATOR"
	FINAL_APPA_FINO__MULTILINE_NEW_LINE_SEPARATOR_CONTENT="$SHOW_RESULT"
}

dragon__set_multiline_last_line_prompt()
{
	FINAL_APPA_FINO__MULTILINE_LAST_LINE_SEPARATOR_CONTENT=""
	[[ -z $APPA_FINO__LAST_LINE_SEPARATOR_CHAR ]] && return

	REAL_APPA_FINO__PROMPT_SEPARATOR_CONTENT="$APPA_FINO__LAST_LINE_SEPARATOR_CHAR"
	__set_separator_parameters

	__dragon__show "PROMPT_SEPARATOR"
	FINAL_APPA_FINO__MULTILINE_LAST_LINE_SEPARATOR_CONTENT="$SHOW_RESULT"
}

__add_separator_between_left_segments()
{
	# adds right separator to the `left_prompt` variable, by the color of the bg of the left segment and the bg of the right segment
	! $APPA_FINO__USE_NERD_FONT && return

	local segment_content="$1"
	local left_segment_left_bg_color="$2"

	[[ -z $segment_content ]] && return

	__get_xterm_color_by_name "$left_segment_left_bg_color"
	if [[ -z "$XTERM_COLOR" ]]; then
		left_segment_left_bg_color="$TERMINAL_BACKGROUND_COLOR"
	fi

	if [[ "$left_segment_left_bg_color" == "$left_segment_right_bg_color" && "$left_segment_left_bg_color" == "$TERMINAL_BACKGROUND_COLOR" ]]; then
		return
	fi
	
	if [[ "$left_segment_left_bg_color" == "$left_segment_right_bg_color" ]]; then
		__get_xterm_style_format "$TERMINAL_BACKGROUND_COLOR" "$left_segment_right_bg_color" "false" "false"
		left_prompt+="$STYLE_FORMAT$APPA_FINO__LEFT_SEGMENT_SEPARATOR_SAME_COLOR"
	else
		__get_xterm_style_format "$left_segment_right_bg_color" "$left_segment_left_bg_color" "false" "false"
		left_prompt+="$STYLE_FORMAT$APPA_FINO__LEFT_SEGMENT_SEPARATOR"
		left_segment_right_bg_color="$left_segment_left_bg_color"
	fi
}

__add_separator_between_right_segments()
{
	# adds left separator to the `right_prompt` variable, by the color of the bg of the right segment and the bg of the left segment
	! $APPA_FINO__USE_NERD_FONT && return

	local segment_content="$1"
	local right_segment_right_bg_color="$2"

	[[ -z $segment_content ]] && return

	__get_xterm_color_by_name "$right_segment_right_bg_color"
	if [[ -z "$XTERM_COLOR" ]]; then
		right_segment_right_bg_color="$TERMINAL_BACKGROUND_COLOR"
	fi

	if [[ "$right_segment_right_bg_color" == "$right_segment_left_bg_color" && "$right_segment_right_bg_color" == "$TERMINAL_BACKGROUND_COLOR" ]]; then
		return
	fi
	
	if [[ "$right_segment_right_bg_color" == "$right_segment_left_bg_color" ]]; then
		__get_xterm_style_format "$TERMINAL_BACKGROUND_COLOR" "$right_segment_left_bg_color" "false" "false"
		right_prompt+="$STYLE_FORMAT$APPA_FINO__RIGHT_SEGMENT_SEPARATOR_SAME_COLOR"
	else
		__get_xterm_style_format "$right_segment_right_bg_color" "$right_segment_left_bg_color" "false" "false"
		right_prompt+="$STYLE_FORMAT$APPA_FINO__RIGHT_SEGMENT_SEPARATOR"
		right_segment_left_bg_color="$right_segment_right_bg_color"
	fi
}

__calc_prompt_length()
{
	local rendered_zsh_prompt=$(print -P "$PROMPT" | sed -E 's/\x1b\[[0-9;]*m//g')
	local zsh_prompt_length=${#rendered_zsh_prompt}

	local rendered_git_prompt=$(print -P "$FINAL_GIT_STATUS_CONTENT" | sed -E 's/\x1b\[[0-9;]*m//g')
	local git_prompt_length=${#rendered_git_prompt}

	FINAL_ONE_LINE_LPROMPT_LEN=$(((zsh_prompt_length+git_prompt_length)*1.1)) # plus 10% for invisible characters
}

__set_git_status_content()
{
	REAL_APPA_FINO__GIT_STATUS_CONTENT=${${VCS_STATUS_LOCAL_BRANCH:-@${VCS_STATUS_COMMIT}}//\%/%%}
}

__set_git_status_color()
{
	if [[ $VCS_STATUS_HAS_UNSTAGED -eq 1 || $VCS_STATUS_HAS_STAGED -eq 1 ]]; then
		REAL_APPA_FINO__GIT_STATUS_FOREGROUND_COLOR="$APPA_FINO__GIT_DIRTY_FOREGROUND_COLOR"
		REAL_APPA_FINO__GIT_STATUS_BACKGROUND_COLOR="$APPA_FINO__GIT_DIRTY_BACKGROUND_COLOR"
		REAL_APPA_FINO__GIT_STATUS_BOLD="$APPA_FINO__GIT_DIRTY_BOLD"
		REAL_APPA_FINO__GIT_STATUS_UNDERLINE="$APPA_FINO__GIT_DIRTY_UNDERLINE"
	else
		REAL_APPA_FINO__GIT_STATUS_FOREGROUND_COLOR="$APPA_FINO__GIT_CLEAN_FOREGROUND_COLOR"
		REAL_APPA_FINO__GIT_STATUS_BACKGROUND_COLOR="$APPA_FINO__GIT_CLEAN_BACKGROUND_COLOR"
		REAL_APPA_FINO__GIT_STATUS_BOLD="$APPA_FINO__GIT_CLEAN_BOLD"
		REAL_APPA_FINO__GIT_STATUS_UNDERLINE="$APPA_FINO__GIT_CLEAN_UNDERLINE"
	fi
}

__get_git_stash_count()
{
	GIT_STASH_STR=""
	! $APPA_FINO__ENABLE_GIT_STASH_COUNT && return
	(( VCS_STATUS_STASHES > 0 )) && GIT_STASH_STR="$APPA_FINO__GIT_STASH_SYMBOL$VCS_STATUS_STASHES"
}

__get_git_remote_state()
{
	GIT_REMOTE_STATE_STR=""
	! $APPA_FINO__ENABLE_GIT_REMOTE_STATE && return
	[[ -z $VCS_STATUS_REMOTE_NAME ]] && return  # no tracking branch

	local ahead="$VCS_STATUS_COMMITS_AHEAD"
	local behind="$VCS_STATUS_COMMITS_BEHIND"

	if (( ahead == 0 && behind == 0 )); then
		GIT_REMOTE_STATE_STR="$APPA_FINO__GIT_REMOTE_SYNCED_SYMBOL"
	else
		(( ahead  > 0 )) && GIT_REMOTE_STATE_STR+="$APPA_FINO__GIT_REMOTE_AHEAD_SYMBOL$ahead"
		(( behind > 0 )) && GIT_REMOTE_STATE_STR+="$APPA_FINO__GIT_REMOTE_BEHIND_SYMBOL$behind"
	fi
}

__set_git_status_prefix_and_suffix()
{
	__get_git_remote_state
	__get_git_stash_count
	REAL_APPA_FINO__GIT_STATUS_PREFIX="$APPA_FINO__GIT_STATUS_PREFIX$APPA_FINO__GIT_BRANCH_PREFIX"
	if [[ $VCS_STATUS_HAS_UNSTAGED -eq 1 || $VCS_STATUS_HAS_STAGED -eq 1 ]]; then
		REAL_APPA_FINO__GIT_STATUS_SUFFIX="$APPA_FINO__GIT_BRANCH_SUFFIX$GIT_REMOTE_STATE_STR$GIT_STASH_STR$APPA_FINO__GIT_DIRTY_SUFFIX$APPA_FINO__GIT_STATUS_SUFFIX"
	else
		REAL_APPA_FINO__GIT_STATUS_SUFFIX="$APPA_FINO__GIT_BRANCH_SUFFIX$GIT_REMOTE_STATE_STR$GIT_STASH_STR$APPA_FINO__GIT_CLEAN_SUFFIX$APPA_FINO__GIT_STATUS_SUFFIX"
	fi
}

dragon__set_git_prompt()
{
	FINAL_GIT_STATUS_CONTENT=""
	! $APPA_FINO__ENABLE_GIT_STATUS && return
	[[ $VCS_STATUS_RESULT != "ok-sync" ]] && return

	__set_git_status_content
	__set_git_status_color
	__set_git_status_prefix_and_suffix

	__dragon__show "GIT_STATUS"
	FINAL_GIT_STATUS_CONTENT="$SHOW_RESULT"

	if [[ $APPA_FINO__GIT_STATUS_ON_NEW_LINE == "never" ]] || ! $APPA_FINO__ENABLE_MULTILINE; then
		GIT_SHOULD_BE_ON_NEW_LINE=false
	elif [[ $APPA_FINO__GIT_STATUS_ON_NEW_LINE == "always" ]]; then
		GIT_SHOULD_BE_ON_NEW_LINE=true
	else # "auto"
		__calc_prompt_length
		if (( COLUMNS >= $FINAL_ONE_LINE_LPROMPT_LEN )); then
			GIT_SHOULD_BE_ON_NEW_LINE=false
		else
			GIT_SHOULD_BE_ON_NEW_LINE=true
		fi
	fi
}

dragon__set_lprompt()
{
	typeset -g left_segment_right_bg_color="$TERMINAL_BACKGROUND_COLOR" # static variable that 'remembers' the previous color
	GIT_SHOULD_BE_ON_NEW_LINE=false
	left_prompt=""
	local curr_content

	if $APPA_FINO__ENABLE_MULTILINE; then
		dragon__set_multiline_first_line_prompt
		__add_separator_between_left_segments "$FINAL_APPA_FINO__MULTILINE_FIRST_LINE_SEPARATOR_CONTENT" "$APPA_FINO__PROMPT_SEPARATOR_BACKGROUND_COLOR"
		left_prompt+="$FINAL_APPA_FINO__MULTILINE_FIRST_LINE_SEPARATOR_CONTENT"
	fi

	dragon__set_ssh_prefix
	__add_separator_between_left_segments "$FINAL_APPA_FINO__SSH_PREFIX_CONTENT" "$APPA_FINO__SSH_PREFIX_BACKGROUND_COLOR"
	left_prompt+="$FINAL_APPA_FINO__SSH_PREFIX_CONTENT"

	dragon__set_username
	__add_separator_between_left_segments "$FINAL_APPA_FINO__USERNAME_CONTENT" "$APPA_FINO__USERNAME_BACKGROUND_COLOR"
	left_prompt+="$FINAL_APPA_FINO__USERNAME_CONTENT"

	dragon__set_user_host_separator
	__add_separator_between_left_segments "$FINAL_APPA_FINO__USER_HOST_SEPARATOR_CONTENT" "$APPA_FINO__PROMPT_SEPARATOR_BACKGROUND_COLOR"
	left_prompt+="$FINAL_APPA_FINO__USER_HOST_SEPARATOR_CONTENT"

	dragon__set_hostname
	__add_separator_between_left_segments "$FINAL_APPA_FINO__HOSTNAME_CONTENT" "$APPA_FINO__HOSTNAME_BACKGROUND_COLOR"
	left_prompt+="$FINAL_APPA_FINO__HOSTNAME_CONTENT"

	dragon__set_host_dir_separator
	__add_separator_between_left_segments "$FINAL_APPA_FINO__HOST_DIR_SEPARATOR_CONTENT" "$APPA_FINO__PROMPT_SEPARATOR_BACKGROUND_COLOR"
	left_prompt+="$FINAL_APPA_FINO__HOST_DIR_SEPARATOR_CONTENT"

	dragon__set_directory
	__add_separator_between_left_segments "$FINAL_APPA_FINO__DIRECTORY_CONTENT" "$APPA_FINO__DIRECTORY_BACKGROUND_COLOR"
	left_prompt+="$FINAL_APPA_FINO__DIRECTORY_CONTENT"

	PROMPT="$left_prompt"
	left_prompt=""

	dragon__set_git_prompt

	if [[ -n $FINAL_GIT_STATUS_CONTENT ]] && $APPA_FINO__ENABLE_MULTILINE && $GIT_SHOULD_BE_ON_NEW_LINE; then
		dragon__set_multiline_new_line_prompt
		curr_content="$FINAL_APPA_FINO__MULTILINE_NEW_LINE_SEPARATOR_CONTENT"
		if [[ -n $curr_content ]]; then
			__add_separator_between_left_segments " " "$TERMINAL_BACKGROUND_COLOR"
			PROMPT+="$left_prompt"
			left_prompt=""
			__add_separator_between_left_segments "$curr_content" "$APPA_FINO__PROMPT_SEPARATOR_BACKGROUND_COLOR"
			PROMPT+="
$left_prompt$curr_content"
			left_prompt=""
		else
			__add_separator_between_left_segments " " "$TERMINAL_BACKGROUND_COLOR"
			PROMPT+="$left_prompt
"
			left_prompt=""
		fi
	fi

	__add_separator_between_left_segments "$FINAL_GIT_STATUS_CONTENT" "$REAL_APPA_FINO__GIT_STATUS_BACKGROUND_COLOR"
	PROMPT+="$left_prompt$FINAL_GIT_STATUS_CONTENT"
	left_prompt=""
	
	if $APPA_FINO__ENABLE_MULTILINE; then
		dragon__set_multiline_last_line_prompt
		curr_content="$FINAL_APPA_FINO__MULTILINE_LAST_LINE_SEPARATOR_CONTENT"
		if [[ -n $curr_content ]]; then
			__add_separator_between_left_segments " " "$TERMINAL_BACKGROUND_COLOR"
			PROMPT+="$left_prompt"
			left_prompt=""
			__add_separator_between_left_segments "$curr_content" "$APPA_FINO__PROMPT_SEPARATOR_BACKGROUND_COLOR"
			PROMPT+="
$left_prompt$curr_content"
			left_prompt=""
		else
			__add_separator_between_left_segments " " "$TERMINAL_BACKGROUND_COLOR"
			PROMPT+="$left_prompt
"
			left_prompt=""
		fi
	fi

	dragon__set_prompt_char
	__add_separator_between_left_segments "$FINAL_PROMPT_CHAR_CONTENT" "$REAL_APPA_FINO__PROMPT_CHAR_BACKGROUND_COLOR"
	left_prompt+="$FINAL_PROMPT_CHAR_CONTENT"

	__add_separator_between_left_segments " " "$TERMINAL_BACKGROUND_COLOR"

	PROMPT+="$left_prompt"
	left_prompt=""
}

dragon__set_date_time()
{
	FINAL_APPA_FINO__DATE_TIME_CONTENT=""
	! $APPA_FINO__ENABLE_DATE_TIME && return
	[[ -z $APPA_FINO__DATE_TIME_FORMAT ]] && return

	REAL_APPA_FINO__DATE_TIME_CONTENT="$APPA_FINO__DATE_TIME_FORMAT"

	REAL_APPA_FINO__DATE_TIME_PREFIX="$APPA_FINO__DATE_TIME_PREFIX"
	REAL_APPA_FINO__DATE_TIME_SUFFIX="$APPA_FINO__DATE_TIME_SUFFIX"

	REAL_APPA_FINO__DATE_TIME_FOREGROUND_COLOR="$APPA_FINO__DATE_TIME_FOREGROUND_COLOR"
	REAL_APPA_FINO__DATE_TIME_BACKGROUND_COLOR="$APPA_FINO__DATE_TIME_BACKGROUND_COLOR"
	REAL_APPA_FINO__DATE_TIME_BOLD="$APPA_FINO__DATE_TIME_BOLD"
	REAL_APPA_FINO__DATE_TIME_UNDERLINE="$APPA_FINO__DATE_TIME_UNDERLINE"

	__dragon__show "DATE_TIME"
	FINAL_APPA_FINO__DATE_TIME_CONTENT="$SHOW_RESULT"
}

_APPA_FINO_CMD_RAN=false
timer=-1

__set_timer()
{
	timer=$SECONDS
}

__mark_cmd_ran()
{
	_APPA_FINO_CMD_RAN=true
}

__reset_timer()
{
	timer=-1
}

__get_readable_time()
{
	local seconds=$1
	local days=$((seconds/86400))
	local hours=$((seconds%86400/3600))
	local minutes=$((seconds%3600/60))
	local seconds=$((seconds%60))

	(( days > 0 )) && echo -n "${days}d "
	(( hours > 0 )) && echo -n "${hours}h "
	(( minutes > 0 )) && echo -n "${minutes}m "
	echo -n "${seconds}s"
}

dragon__set_execution_time()
{
	FINAL_APPA_FINO__EXEC_TIMER_CONTENT=""
	! $APPA_FINO__ENABLE_EXEC_TIMER && return

	if ((timer == -1 || SECONDS - timer < $APPA_FINO__EXEC_TIMER_THRESHOLD)); then
		return
	fi

	REAL_APPA_FINO__EXEC_TIMER_CONTENT="$(__get_readable_time $((SECONDS - timer)))"

	REAL_APPA_FINO__EXEC_TIMER_PREFIX="$APPA_FINO__EXEC_TIMER_PREFIX"
	REAL_APPA_FINO__EXEC_TIMER_SUFFIX="$APPA_FINO__EXEC_TIMER_SUFFIX"

	REAL_APPA_FINO__EXEC_TIMER_FOREGROUND_COLOR="$APPA_FINO__EXEC_TIMER_FOREGROUND_COLOR"
	REAL_APPA_FINO__EXEC_TIMER_BACKGROUND_COLOR="$APPA_FINO__EXEC_TIMER_BACKGROUND_COLOR"
	REAL_APPA_FINO__EXEC_TIMER_BOLD="$APPA_FINO__EXEC_TIMER_BOLD"
	REAL_APPA_FINO__EXEC_TIMER_UNDERLINE="$APPA_FINO__EXEC_TIMER_UNDERLINE"

	__dragon__show "EXEC_TIMER"
	FINAL_APPA_FINO__EXEC_TIMER_CONTENT="$SHOW_RESULT"
}

__set_job_count_prefix_and_suffix()
{
	REAL_APPA_FINO__JOB_COUNT_PREFIX="$APPA_FINO__JOB_COUNT_PREFIX"
	REAL_APPA_FINO__JOB_COUNT_SUFFIX="$APPA_FINO__JOB_COUNT_SUFFIX"
	if [[ "$jobs_count" -eq 1 ]]; then
		REAL_APPA_FINO__JOB_COUNT_PREFIX="${APPA_FINO__JOB_COUNT_PREFIX/jobs/job}"
		REAL_APPA_FINO__JOB_COUNT_SUFFIX="${APPA_FINO__JOB_COUNT_SUFFIX/jobs/job}"
	fi
}

dragon__set_job_count()
{
	FINAL_APPA_FINO__JOB_COUNT_CONTENT=""
	! $APPA_FINO__ENABLE_JOB_COUNT && return

	local jobs_count=${#jobstates[@]}
	[[ "$jobs_count" -eq 0 ]] && return

	REAL_APPA_FINO__JOB_COUNT_CONTENT="%j"

	__set_job_count_prefix_and_suffix

	REAL_APPA_FINO__JOB_COUNT_FOREGROUND_COLOR="$APPA_FINO__JOB_COUNT_FOREGROUND_COLOR"
	REAL_APPA_FINO__JOB_COUNT_BACKGROUND_COLOR="$APPA_FINO__JOB_COUNT_BACKGROUND_COLOR"
	REAL_APPA_FINO__JOB_COUNT_BOLD="$APPA_FINO__JOB_COUNT_BOLD"
	REAL_APPA_FINO__JOB_COUNT_UNDERLINE="$APPA_FINO__JOB_COUNT_UNDERLINE"

	__dragon__show "JOB_COUNT"
	FINAL_APPA_FINO__JOB_COUNT_CONTENT="$SHOW_RESULT"
}

__set_ssh_connection_count_content()
{
	local current_ssh_connections
	current_ssh_connections="$(who | grep pts | grep -v "127.0.0.1" | awk '{ print $5 }' | grep -E '^\([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\)$')"

	local connection_count
	if __is_via_ssh; then
		local current_connection_ip
		current_connection_ip="$(awk '{ print $1 }' <<< "$SSH_CLIENT")"
		connection_count="$(grep -v "$current_connection_ip" <<< "$current_ssh_connections" | grep -c .)"
	else
		connection_count="$(grep -c . <<< "$current_ssh_connections")"
	fi

	REAL_APPA_FINO__SSH_CONNECTION_COUNT_CONTENT="$connection_count"
}

dragon__set_ssh_connection_count()
{
	FINAL_APPA_FINO__SSH_CONNECTION_COUNT_CONTENT=""
	! $APPA_FINO__ENABLE_SSH_CONNECTION_COUNT && return

	__set_ssh_connection_count_content
	[[ "$REAL_APPA_FINO__SSH_CONNECTION_COUNT_CONTENT" -eq 0 ]] && return

	REAL_APPA_FINO__SSH_CONNECTION_COUNT_PREFIX="$APPA_FINO__SSH_CONNECTION_COUNT_PREFIX"
	REAL_APPA_FINO__SSH_CONNECTION_COUNT_SUFFIX="$APPA_FINO__SSH_CONNECTION_COUNT_SUFFIX"
	REAL_APPA_FINO__SSH_CONNECTION_COUNT_FOREGROUND_COLOR="$APPA_FINO__SSH_CONNECTION_COUNT_FOREGROUND_COLOR"
	REAL_APPA_FINO__SSH_CONNECTION_COUNT_BACKGROUND_COLOR="$APPA_FINO__SSH_CONNECTION_COUNT_BACKGROUND_COLOR"
	REAL_APPA_FINO__SSH_CONNECTION_COUNT_BOLD="$APPA_FINO__SSH_CONNECTION_COUNT_BOLD"
	REAL_APPA_FINO__SSH_CONNECTION_COUNT_UNDERLINE="$APPA_FINO__SSH_CONNECTION_COUNT_UNDERLINE"

	__dragon__show "SSH_CONNECTION_COUNT"
	FINAL_APPA_FINO__SSH_CONNECTION_COUNT_CONTENT="$SHOW_RESULT"
}

__save_exit_code()
{
	local last_exit="$?"
	if [[ "$_APPA_FINO_CMD_RAN" == "true" ]]; then
		exit_code="$last_exit"
	else
		exit_code=0
	fi
	_APPA_FINO_CMD_RAN=false
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
	if "$APPA_FINO__ENABLE_FULL_EXIT_STATUS"; then
		__get_full_exit_code
	else
		echo "$exit_code"
	fi
}

dragon__set_exit_status()
{
	FINAL_APPA_FINO__EXIT_STATUS_CONTENT=""
	! "$APPA_FINO__ENABLE_EXIT_STATUS" && return
	[[ "$exit_code" -eq 0 ]] && return

	REAL_APPA_FINO__EXIT_STATUS_CONTENT="$(__get_exit_status_content)"

	REAL_APPA_FINO__EXIT_STATUS_PREFIX="$APPA_FINO__EXIT_STATUS_PREFIX"
	REAL_APPA_FINO__EXIT_STATUS_SUFFIX="$APPA_FINO__EXIT_STATUS_SUFFIX"

	REAL_APPA_FINO__EXIT_STATUS_FOREGROUND_COLOR="$APPA_FINO__EXIT_STATUS_FOREGROUND_COLOR"
	REAL_APPA_FINO__EXIT_STATUS_BACKGROUND_COLOR="$APPA_FINO__EXIT_STATUS_BACKGROUND_COLOR"
	REAL_APPA_FINO__EXIT_STATUS_BOLD="$APPA_FINO__EXIT_STATUS_BOLD"
	REAL_APPA_FINO__EXIT_STATUS_UNDERLINE="$APPA_FINO__EXIT_STATUS_UNDERLINE"

	__dragon__show "EXIT_STATUS"
	FINAL_APPA_FINO__EXIT_STATUS_CONTENT="$SHOW_RESULT"
}

dragon__set_rprompt()
{
	typeset -g right_segment_left_bg_color="$TERMINAL_BACKGROUND_COLOR" # static variable that 'remembers' the previous color
	right_prompt=""

	dragon__set_exit_status
	__add_separator_between_right_segments "$FINAL_APPA_FINO__EXIT_STATUS_CONTENT" "$APPA_FINO__EXIT_STATUS_BACKGROUND_COLOR"
	right_prompt+="$FINAL_APPA_FINO__EXIT_STATUS_CONTENT"

	dragon__set_ssh_connection_count
	__add_separator_between_right_segments "$FINAL_APPA_FINO__SSH_CONNECTION_COUNT_CONTENT" "$APPA_FINO__SSH_CONNECTION_COUNT_BACKGROUND_COLOR"
	right_prompt+="$FINAL_APPA_FINO__SSH_CONNECTION_COUNT_CONTENT"

	dragon__set_job_count
	__add_separator_between_right_segments "$FINAL_APPA_FINO__JOB_COUNT_CONTENT" "$APPA_FINO__JOB_COUNT_BACKGROUND_COLOR"
	right_prompt+="$FINAL_APPA_FINO__JOB_COUNT_CONTENT"

	dragon__set_execution_time
	__add_separator_between_right_segments "$FINAL_APPA_FINO__EXEC_TIMER_CONTENT" "$APPA_FINO__EXEC_TIMER_BACKGROUND_COLOR"
	right_prompt+="$FINAL_APPA_FINO__EXEC_TIMER_CONTENT"

	dragon__set_date_time
	__add_separator_between_right_segments "$FINAL_APPA_FINO__DATE_TIME_CONTENT" "$APPA_FINO__DATE_TIME_BACKGROUND_COLOR"
	right_prompt+="$FINAL_APPA_FINO__DATE_TIME_CONTENT"

	RPROMPT="$right_prompt"
	_APPA_FINO_SAVED_RPROMPT="$right_prompt"  # saved for verbose transient reuse
}

_APPA_FINO_JUST_CHANGED_DIR=false

__dragon_track_chpwd()
{
	_APPA_FINO_JUST_CHANGED_DIR=true
}

__dragon_zle_line_finish()
{
	local mode="$APPA_FINO__ENABLE_TRANSIENT_PROMPT"
	[[ "$mode" == "false" ]] && return

	if [[ "$mode" == "per-dir" ]]; then
		if [[ "$_APPA_FINO_JUST_CHANGED_DIR" == "true" ]]; then
			# First command after a directory change — keep the full prompt visible
			_APPA_FINO_JUST_CHANGED_DIR=false
			return
		fi
	fi

	local char="${APPA_FINO__TRANSIENT_PROMPT_CHAR:-$APPA_FINO__PROMPT_CHAR}"
	[[ -z "$char" ]] && return

	# exit_code is set by __save_exit_code in the previous precmd cycle — it holds
	# the exit code of the last command, which is the same value the current full
	# prompt is already colored with. So we get the correct green/red here.
	local fg bg bold underline
	if $APPA_FINO__ENABLE_EXIT_STATUS_PROMPT_COLORING && [[ "$exit_code" -eq 0 ]]; then
		fg="$APPA_FINO__PROMPT_CHAR_SUCCESS_FOREGROUND_COLOR"
		bg="$APPA_FINO__PROMPT_CHAR_SUCCESS_BACKGROUND_COLOR"
		bold="$APPA_FINO__PROMPT_CHAR_SUCCESS_BOLD"
		underline="$APPA_FINO__PROMPT_CHAR_SUCCESS_UNDERLINE"
	elif $APPA_FINO__ENABLE_EXIT_STATUS_PROMPT_COLORING; then
		fg="$APPA_FINO__PROMPT_CHAR_FAILURE_FOREGROUND_COLOR"
		bg="$APPA_FINO__PROMPT_CHAR_FAILURE_BACKGROUND_COLOR"
		bold="$APPA_FINO__PROMPT_CHAR_FAILURE_BOLD"
		underline="$APPA_FINO__PROMPT_CHAR_FAILURE_UNDERLINE"
	else
		fg="$APPA_FINO__PROMPT_CHAR_DEFAULT_FOREGROUND_COLOR"
		bg="$APPA_FINO__PROMPT_CHAR_DEFAULT_BACKGROUND_COLOR"
		bold="$APPA_FINO__PROMPT_CHAR_DEFAULT_BOLD"
		underline="$APPA_FINO__PROMPT_CHAR_DEFAULT_UNDERLINE"
	fi
	__get_xterm_style_format "$fg" "$bg" "$bold" "$underline"

	PROMPT="$RESET_FORMAT$STYLE_FORMAT$char$APPA_FINO__PROMPT_CHAR_SUFFIX$RESET_FORMAT"

	if $APPA_FINO__TRANSIENT_PROMPT_VERBOSE; then
		# Reuse the rprompt computed during precmd — timer is already reset by this
		# point so recomputing would lose the exec time; the saved value is accurate.
		RPROMPT="$_APPA_FINO_SAVED_RPROMPT"
	else
		RPROMPT=""
	fi

	zle reset-prompt
}

dragon__update_zsh_prompt()
{
	dragon__set_lprompt
	dragon__set_rprompt
}

_GITSTATUS_NEEDS_REFRESH=false
__refresh_prompt()
{
	_GITSTATUS_NEEDS_REFRESH=true
	kill -WINCH "$$"
}

_IS_GITSTATUS_RUNNING=false
_GITSTATUS_NAME="MY_GIT"
__start_gitstatus_once()
{
	$_IS_GITSTATUS_RUNNING && return
	gitstatus_start -s -1 -u -1 -c -1 -d -1 "$_GITSTATUS_NAME"
	_IS_GITSTATUS_RUNNING=true
}

__update_gitstatusd()
{
	__start_gitstatus_once
	gitstatus_query -d "$PWD" -c __refresh_prompt -t 0.03 "$_GITSTATUS_NAME"
}

__update_prompt()
{
	$APPA_FINO__ENABLE_GIT_STATUS && __update_gitstatusd
	dragon__update_zsh_prompt
}

__reset_prompt()
{
	dragon__set_lprompt
	if [[ -o zle ]] && $_GITSTATUS_NEEDS_REFRESH; then
		_GITSTATUS_NEEDS_REFRESH=false
		zle reset-prompt 2> /dev/null
	fi
}

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

trap '__reset_prompt' WINCH

zle -N zle-line-finish __dragon_zle_line_finish
