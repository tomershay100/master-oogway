##########################################
#### Theme configuration: appa-fino #####
##########################################

function set_if_unset {
	local varname="$1"
	local default="$2"
	if [[ ! -v "$varname" ]]; then
		export "$varname=$default"
	fi
}

## Most of the following variables groups has the same convention:
##
## APPA_FINO__ENABLE_{feature-name}
## APPA_FINO__{feature-name}_FOREGROUND_COLOR
## APPA_FINO__{feature-name}_BACKGROUND_COLOR
## APPA_FINO__{feature-name}_BOLD
## APPA_FINO__{feature-name}_UNDERLINE 
## APPA_FINO__{feature-name}_PREFIX ""
## APPA_FINO__{feature-name}_SUFFIX ""
##
## While each has its own settings:
## `ENABLE`- boolean: can get `true` or `false` values
## `FOREGROUND_COLOR`- string: can get `color-name` or `color-value`
## `BACKGROUND_COLOR`- string: can get `color-name` or `color-value`
## `BOLD`- boolean: can get `true` or `false` values
## `UNDERLINE`- boolean: can get `true` or `false` values
## `PREFIX`- string: can get any string
## `SUFFIX`- string: can get any string
##
## Colors can be `color-value`, that is a string contains value between "000" to "255"
## And, could also be `color-name`, that is a string contains the color name.
## 
## To see all the colors (256-colors), run:
##   for i in {0..255}; do print -Pn "%K{$i}  %k%F{$i}${(l:3::0:)i}%f " ${${(M)$((i%6)):#3}:+$'\n'}; done
##
## To see all 16 color names, run:
## 	print -Pn "%K{000} %k%F{000}black 000\t%K{001} %k%F{001}red 001\t%K{002} %k%F{002}green 002\t%K{003} %k%F{003}yellow 003\n%K{004} %k%F{004}blue 004\t%K{005} %k%F{005}magenta 005\t%K{006} %k%F{006}cyan 006\t%K{007} %k%F{007}white 007\n%K{008} %k%F{008}grey 008\t%K{009} %k%F{009}maroon 009\t%K{010} %k%F{010}lime 010\t%K{011} %k%F{011}olive 011\n%K{012} %k%F{012}navy 012\t%K{013} %k%F{013}fuchsia 013\t%K{014} %k%F{014}aqua 014\t%K{015} %k%F{015}silver 015\n"
##	
## 16-color names output:
## 	black 000	red 001		green 002	yellow 003
##	blue 004	magenta 005	cyan 006	white 007
##	grey 008	maroon 009	lime 010	olive 011
##	navy 012	fuchsia 013	aqua 014	silver 015

# ## background color segments separators
# ## these are Nerd Font icons. For removing background segments separators - set these to empty string.
# set_if_unset APPA_FINO__LEFT_SEGMENT_SEPARATOR "\uE0B0"
# set_if_unset APPA_FINO__LEFT_SEGMENT_SEPARATOR_SAME_COLOR "\uE0B1"
# set_if_unset APPA_FINO__RIGHT_SEGMENT_SEPARATOR "\uE0B2"
# set_if_unset APPA_FINO__RIGHT_SEGMENT_SEPARATOR_SAME_COLOR "\uE0B3"

# ## username in lprompt
# set_if_unset APPA_FINO__ENABLE_USERNAME true
# set_if_unset APPA_FINO__USERNAME_FOREGROUND_COLOR "navy"
# set_if_unset APPA_FINO__USERNAME_BACKGROUND_COLOR ""
# set_if_unset APPA_FINO__USERNAME_BOLD false
# set_if_unset APPA_FINO__USERNAME_UNDERLINE false
# set_if_unset APPA_FINO__USERNAME_PREFIX ""
# set_if_unset APPA_FINO__USERNAME_SUFFIX ""
# set_if_unset APPA_FINO__ENABLE_USERNAME_COLORING_VIA_SSH false
# set_if_unset APPA_FINO__USERNAME_VIA_SSH_FOREGROUND_COLOR ""
# set_if_unset APPA_FINO__USERNAME_VIA_SSH_BACKGROUND_COLOR ""
# set_if_unset APPA_FINO__USERNAME_VIA_SSH_BOLD false
# set_if_unset APPA_FINO__USERNAME_VIA_SSH_UNDERLINE false

# ## hostname in lprompt
# set_if_unset APPA_FINO__ENABLE_HOSTNAME true
# set_if_unset APPA_FINO__HOSTNAME_FOREGROUND_COLOR "fuchsia"
# set_if_unset APPA_FINO__HOSTNAME_BACKGROUND_COLOR ""
# set_if_unset APPA_FINO__HOSTNAME_BOLD false
# set_if_unset APPA_FINO__HOSTNAME_UNDERLINE false
# set_if_unset APPA_FINO__HOSTNAME_PREFIX ""
# set_if_unset APPA_FINO__HOSTNAME_SUFFIX ""
# set_if_unset APPA_FINO__ENABLE_HOSTNAME_COLORING_VIA_SSH true
# set_if_unset APPA_FINO__HOSTNAME_VIA_SSH_FOREGROUND_COLOR "maroon"
# set_if_unset APPA_FINO__HOSTNAME_VIA_SSH_BACKGROUND_COLOR ""
# set_if_unset APPA_FINO__HOSTNAME_VIA_SSH_BOLD false
# set_if_unset APPA_FINO__HOSTNAME_VIA_SSH_UNDERLINE false

# ## directory in lprompt
# set_if_unset APPA_FINO__ENABLE_DIRECTORY true
# set_if_unset APPA_FINO__DIRECTORY_FOREGROUND_COLOR "olive"
# set_if_unset APPA_FINO__DIRECTORY_BACKGROUND_COLOR ""
# set_if_unset APPA_FINO__DIRECTORY_BOLD false
# set_if_unset APPA_FINO__DIRECTORY_UNDERLINE false
# set_if_unset APPA_FINO__DIRECTORY_PREFIX ""
# set_if_unset APPA_FINO__DIRECTORY_SUFFIX " "
# set_if_unset APPA_FINO__DIRECTORY_FORMAT "regular" # can be `regular` (default) `short` or `full`

# ## prompt character settings 
# set_if_unset APPA_FINO__PROMPT_CHAR "❯"
# set_if_unset APPA_FINO__GIT_PROMPT_CHAR "❯"
# set_if_unset APPA_FINO__PROMPT_CHAR_DEFAULT_FOREGROUND_COLOR "silver"
# set_if_unset APPA_FINO__PROMPT_CHAR_DEFAULT_BACKGROUND_COLOR ""
# set_if_unset APPA_FINO__PROMPT_CHAR_DEFAULT_BOLD false
# set_if_unset APPA_FINO__PROMPT_CHAR_DEFAULT_UNDERLINE false
# set_if_unset APPA_FINO__PROMPT_CHAR_PREFIX ""
# set_if_unset APPA_FINO__PROMPT_CHAR_SUFFIX " "

# set_if_unset APPA_FINO__ENABLE_EXIT_STATUS_PROMPT_COLORING true
# set_if_unset APPA_FINO__PROMPT_CHAR_SUCCESS_FOREGROUND_COLOR "lime"
# set_if_unset APPA_FINO__PROMPT_CHAR_SUCCESS_BACKGROUND_COLOR ""
# set_if_unset APPA_FINO__PROMPT_CHAR_SUCCESS_BOLD false
# set_if_unset APPA_FINO__PROMPT_CHAR_SUCCESS_UNDERLINE false
# set_if_unset APPA_FINO__PROMPT_CHAR_FAILURE_FOREGROUND_COLOR "maroon"
# set_if_unset APPA_FINO__PROMPT_CHAR_FAILURE_BACKGROUND_COLOR ""
# set_if_unset APPA_FINO__PROMPT_CHAR_FAILURE_BOLD false
# set_if_unset APPA_FINO__PROMPT_CHAR_FAILURE_UNDERLINE false

# ## transient prompt — collapse previous prompt to a single char after execution
# ## values: true (always), false (never), per-dir (only within the same directory)
# set_if_unset APPA_FINO__ENABLE_TRANSIENT_PROMPT true
# set_if_unset APPA_FINO__TRANSIENT_PROMPT_CHAR "" # empty = use APPA_FINO__PROMPT_CHAR
# ## verbose transient — keep rprompt (exit code, jobs, timer, time) on collapsed lines
# set_if_unset APPA_FINO__TRANSIENT_PROMPT_VERBOSE true

# ## lprompt prefix when ssh
# set_if_unset APPA_FINO__ENABLE_SSH_PREFIX true
# set_if_unset APPA_FINO__SSH_PREFIX "via ssh:"
# set_if_unset APPA_FINO__SSH_PREFIX_FOREGROUND_COLOR "red"
# set_if_unset APPA_FINO__SSH_PREFIX_BACKGROUND_COLOR ""
# set_if_unset APPA_FINO__SSH_PREFIX_BOLD false
# set_if_unset APPA_FINO__SSH_PREFIX_UNDERLINE false

# ## prompt separators color
# set_if_unset APPA_FINO__PROMPT_SEPARATOR_FOREGROUND_COLOR "white"
# set_if_unset APPA_FINO__PROMPT_SEPARATOR_BACKGROUND_COLOR ""
# set_if_unset APPA_FINO__PROMPT_SEPARATOR_BOLD false
# set_if_unset APPA_FINO__PROMPT_SEPARATOR_UNDERLINE false
# set_if_unset APPA_FINO__USER_HOST_SEPARATOR "@"
# set_if_unset APPA_FINO__HOST_DIR_SEPARATOR ":"

# set_if_unset APPA_FINO__ENABLE_MULTILINE true
# # set_if_unset APPA_FINO__FIRST_LINE_SEPARATOR_CHAR "╭ "
# # set_if_unset APPA_FINO__NEW_LINE_SEPARATOR_CHAR "│"
# # set_if_unset APPA_FINO__LAST_LINE_SEPARATOR_CHAR "╰╴"

# ## git status in lprompt
# set_if_unset APPA_FINO__ENABLE_GIT_STATUS true
# set_if_unset APPA_FINO__GIT_STATUS_ON_NEW_LINE "auto" # can be `auto` (default), `never` or `always`
# set_if_unset APPA_FINO__GIT_STATUS_PREFIX " on "
# set_if_unset APPA_FINO__GIT_STATUS_SUFFIX " "
# set_if_unset APPA_FINO__GIT_BRANCH_PREFIX ""
# set_if_unset APPA_FINO__GIT_BRANCH_SUFFIX ""

# ## git stash count — set ENABLE to false to hide
# set_if_unset APPA_FINO__ENABLE_GIT_STASH_COUNT true
# set_if_unset APPA_FINO__GIT_STASH_SYMBOL "⚑"

# ## git remote tracking state (ahead/behind/synced) — set ENABLE to false to hide
# set_if_unset APPA_FINO__ENABLE_GIT_REMOTE_STATE true
# set_if_unset APPA_FINO__GIT_REMOTE_AHEAD_SYMBOL "↑"
# set_if_unset APPA_FINO__GIT_REMOTE_BEHIND_SYMBOL "↓"
# set_if_unset APPA_FINO__GIT_REMOTE_SYNCED_SYMBOL "≡"

# set_if_unset APPA_FINO__GIT_CLEAN_SUFFIX ""
# set_if_unset APPA_FINO__GIT_CLEAN_FOREGROUND_COLOR "black"
# set_if_unset APPA_FINO__GIT_CLEAN_BACKGROUND_COLOR "green"
# set_if_unset APPA_FINO__GIT_CLEAN_BOLD false
# set_if_unset APPA_FINO__GIT_CLEAN_UNDERLINE false

# set_if_unset APPA_FINO__GIT_DIRTY_SUFFIX "*"
# set_if_unset APPA_FINO__GIT_DIRTY_FOREGROUND_COLOR "black"
# set_if_unset APPA_FINO__GIT_DIRTY_BACKGROUND_COLOR "aqua"
# set_if_unset APPA_FINO__GIT_DIRTY_BOLD false
# set_if_unset APPA_FINO__GIT_DIRTY_UNDERLINE false

# ## date and time in rprompt
# set_if_unset APPA_FINO__ENABLE_DATE_TIME true
# set_if_unset APPA_FINO__DATE_TIME_FORMAT "%D{%H:%M:%S}" # see strftime
# set_if_unset APPA_FINO__DATE_TIME_FOREGROUND_COLOR "white"
# set_if_unset APPA_FINO__DATE_TIME_BACKGROUND_COLOR ""
# set_if_unset APPA_FINO__DATE_TIME_BOLD false
# set_if_unset APPA_FINO__DATE_TIME_UNDERLINE false
# set_if_unset APPA_FINO__DATE_TIME_PREFIX " "
# set_if_unset APPA_FINO__DATE_TIME_SUFFIX ""

# ## execution timer in rprompt
# set_if_unset APPA_FINO__ENABLE_EXEC_TIMER true
# set_if_unset APPA_FINO__EXEC_TIMER_FOREGROUND_COLOR "black"
# set_if_unset APPA_FINO__EXEC_TIMER_BACKGROUND_COLOR "olive"
# set_if_unset APPA_FINO__EXEC_TIMER_BOLD false
# set_if_unset APPA_FINO__EXEC_TIMER_UNDERLINE false
# set_if_unset APPA_FINO__EXEC_TIMER_PREFIX " took "
# set_if_unset APPA_FINO__EXEC_TIMER_SUFFIX " "
# set_if_unset APPA_FINO__EXEC_TIMER_THRESHOLD 2

# ## background jobs count in rprompt
#set_if_unset APPA_FINO__ENABLE_JOB_COUNT false
# set_if_unset APPA_FINO__JOB_COUNT_FOREGROUND_COLOR "black"
# set_if_unset APPA_FINO__JOB_COUNT_BACKGROUND_COLOR "blue"
# set_if_unset APPA_FINO__JOB_COUNT_BOLD false
# set_if_unset APPA_FINO__JOB_COUNT_UNDERLINE false
# set_if_unset APPA_FINO__JOB_COUNT_PREFIX " "
# set_if_unset APPA_FINO__JOB_COUNT_SUFFIX " jobs " # Great Feature: using "jobs" in prefix or suffix makes one job to be seen as `1 job`

# ## exit status in rprompt
# set_if_unset APPA_FINO__ENABLE_EXIT_STATUS true
# set_if_unset APPA_FINO__ENABLE_FULL_EXIT_STATUS true
# set_if_unset APPA_FINO__EXIT_STATUS_FOREGROUND_COLOR "black"
# set_if_unset APPA_FINO__EXIT_STATUS_BACKGROUND_COLOR "red"
# set_if_unset APPA_FINO__EXIT_STATUS_BOLD false
# set_if_unset APPA_FINO__EXIT_STATUS_UNDERLINE false
# set_if_unset APPA_FINO__EXIT_STATUS_PREFIX " "
# set_if_unset APPA_FINO__EXIT_STATUS_SUFFIX " "

########################################################
#             Ultra Informative Settings               #
########################################################
# set_if_unset APPA_FINO__DIRECTORY_FORMAT "full"
# set_if_unset APPA_FINO__USER_HOST_SEPARATOR " at "
# set_if_unset APPA_FINO__HOST_DIR_SEPARATOR " in "
# set_if_unset APPA_FINO__FIRST_LINE_SEPARATOR_CHAR "╭ "
# set_if_unset APPA_FINO__NEW_LINE_SEPARATOR_CHAR "│"
# set_if_unset APPA_FINO__LAST_LINE_SEPARATOR_CHAR "╰╴"
# set_if_unset APPA_FINO__GIT_STATUS_ON_NEW_LINE "always"
# set_if_unset APPA_FINO__GIT_STATUS_PREFIX " on "
# set_if_unset APPA_FINO__GIT_BRANCH_PREFIX "‹"
# set_if_unset APPA_FINO__GIT_BRANCH_SUFFIX "›"
# set_if_unset APPA_FINO__GIT_CLEAN_SUFFIX "✔"
# set_if_unset APPA_FINO__GIT_DIRTY_SUFFIX "✘"
# set_if_unset APPA_FINO__DATE_TIME_FORMAT "%D{%d/%m/%y | %H:%M:%S}" # see strftime
# set_if_unset APPA_FINO__DATE_TIME_PREFIX " at "
# set_if_unset APPA_FINO__EXEC_TIMER_PREFIX " took "
# set_if_unset APPA_FINO__EXEC_TIMER_THRESHOLD 2
# set_if_unset APPA_FINO__JOB_COUNT_SUFFIX " jobs "
# set_if_unset APPA_FINO__EXIT_STATUS_PREFIX " code:"

##########################################################
#             Short Recommanded Settings                 #
##########################################################
# set_if_unset APPA_FINO__LEFT_SEGMENT_SEPARATOR ""
# set_if_unset APPA_FINO__LEFT_SEGMENT_SEPARATOR_SAME_COLOR ""
# set_if_unset APPA_FINO__RIGHT_SEGMENT_SEPARATOR ""
# set_if_unset APPA_FINO__RIGHT_SEGMENT_SEPARATOR_SAME_COLOR ""
# set_if_unset APPA_FINO__ENABLE_USERNAME false
# set_if_unset APPA_FINO__ENABLE_HOSTNAME true
# set_if_unset APPA_FINO__ENABLE_HOSTNAME_COLORING_VIA_SSH true
# set_if_unset APPA_FINO__ENABLE_DIRECTORY true
# set_if_unset APPA_FINO__DIRECTORY_BOLD false
# set_if_unset APPA_FINO__DIRECTORY_FORMAT "short"
# set_if_unset APPA_FINO__PROMPT_CHAR "$"
# set_if_unset APPA_FINO__GIT_PROMPT_CHAR "$"
# set_if_unset APPA_FINO__ENABLE_EXIT_STATUS_PROMPT_COLORING true
# set_if_unset APPA_FINO__ENABLE_SSH_PREFIX false
# set_if_unset APPA_FINO__USER_HOST_SEPARATOR ""
# set_if_unset APPA_FINO__HOST_DIR_SEPARATOR ":"
# set_if_unset APPA_FINO__ENABLE_MULTILINE false
# set_if_unset APPA_FINO__ENABLE_GIT_STATUS true
# set_if_unset APPA_FINO__GIT_STATUS_ON_NEW_LINE "never"
# set_if_unset APPA_FINO__GIT_STATUS_PREFIX ""
# set_if_unset APPA_FINO__GIT_STATUS_SUFFIX " "
# set_if_unset APPA_FINO__GIT_BRANCH_PREFIX ""
# set_if_unset APPA_FINO__GIT_BRANCH_SUFFIX ""
# set_if_unset APPA_FINO__GIT_CLEAN_SUFFIX ""
# set_if_unset APPA_FINO__GIT_CLEAN_FOREGROUND_COLOR "navy"
# set_if_unset APPA_FINO__GIT_CLEAN_BACKGROUND_COLOR ""
# set_if_unset APPA_FINO__GIT_DIRTY_SUFFIX "*"
# set_if_unset APPA_FINO__GIT_DIRTY_FOREGROUND_COLOR "navy"
# set_if_unset APPA_FINO__GIT_DIRTY_BACKGROUND_COLOR ""
# set_if_unset APPA_FINO__ENABLE_DATE_TIME false
# set_if_unset APPA_FINO__ENABLE_EXEC_TIMER false
# set_if_unset APPA_FINO__ENABLE_JOB_COUNT false
# set_if_unset APPA_FINO__ENABLE_EXIT_STATUS false
