# dragon theme schema — pure data sourced by dragon-configure.zsh.
# Contains defaults, types, hints, and group definitions for every
# DRAGON__* variable. No side effects at top level.

_dragon_init_defaults() {
    typeset -gA _DRAGON_DEFAULTS=(
        # separators
        [LEFT_SEGMENT_SEPARATOR]=$'\uE0B0'
        [LEFT_SEGMENT_SEPARATOR_SAME_COLOR]=$'\uE0B1'
        [RIGHT_SEGMENT_SEPARATOR]=$'\uE0B2'
        [RIGHT_SEGMENT_SEPARATOR_SAME_COLOR]=$'\uE0B3'
        [USE_NERD_FONT]="true"
        # username
        [ENABLE_USERNAME]="true"
        [USERNAME_FOREGROUND_COLOR]="navy"
        [USERNAME_BACKGROUND_COLOR]=""
        [USERNAME_BOLD]="false"
        [USERNAME_UNDERLINE]="false"
        [USERNAME_PREFIX]=""
        [USERNAME_SUFFIX]=""
        [ENABLE_USERNAME_COLORING_VIA_SSH]="false"
        [USERNAME_VIA_SSH_FOREGROUND_COLOR]=""
        [USERNAME_VIA_SSH_BACKGROUND_COLOR]=""
        [USERNAME_VIA_SSH_BOLD]="false"
        [USERNAME_VIA_SSH_UNDERLINE]="false"
        # hostname
        [ENABLE_HOSTNAME]="true"
        [HOSTNAME_FOREGROUND_COLOR]="fuchsia"
        [HOSTNAME_BACKGROUND_COLOR]=""
        [HOSTNAME_BOLD]="false"
        [HOSTNAME_UNDERLINE]="false"
        [HOSTNAME_PREFIX]=""
        [HOSTNAME_SUFFIX]=""
        [ENABLE_HOSTNAME_COLORING_VIA_SSH]="true"
        [HOSTNAME_VIA_SSH_FOREGROUND_COLOR]="maroon"
        [HOSTNAME_VIA_SSH_BACKGROUND_COLOR]=""
        [HOSTNAME_VIA_SSH_BOLD]="false"
        [HOSTNAME_VIA_SSH_UNDERLINE]="false"
        # directory
        [ENABLE_DIRECTORY]="true"
        [DIRECTORY_FOREGROUND_COLOR]="olive"
        [DIRECTORY_BACKGROUND_COLOR]=""
        [DIRECTORY_BOLD]="false"
        [DIRECTORY_UNDERLINE]="false"
        [DIRECTORY_PREFIX]=""
        [DIRECTORY_SUFFIX]=" "
        [DIRECTORY_FORMAT]="regular"
        # prompt char
        [PROMPT_CHAR]="❯"
        [GIT_PROMPT_CHAR]="❯"
        [PROMPT_CHAR_DEFAULT_FOREGROUND_COLOR]="silver"
        [PROMPT_CHAR_DEFAULT_BACKGROUND_COLOR]=""
        [PROMPT_CHAR_DEFAULT_BOLD]="false"
        [PROMPT_CHAR_DEFAULT_UNDERLINE]="false"
        [PROMPT_CHAR_PREFIX]=""
        [PROMPT_CHAR_SUFFIX]=" "
        [ENABLE_EXIT_STATUS_PROMPT_COLORING]="true"
        [PROMPT_CHAR_SUCCESS_FOREGROUND_COLOR]="lime"
        [PROMPT_CHAR_SUCCESS_BACKGROUND_COLOR]=""
        [PROMPT_CHAR_SUCCESS_BOLD]="false"
        [PROMPT_CHAR_SUCCESS_UNDERLINE]="false"
        [PROMPT_CHAR_FAILURE_FOREGROUND_COLOR]="maroon"
        [PROMPT_CHAR_FAILURE_BACKGROUND_COLOR]=""
        [PROMPT_CHAR_FAILURE_BOLD]="false"
        [PROMPT_CHAR_FAILURE_UNDERLINE]="false"
        # transient prompt
        [ENABLE_TRANSIENT_PROMPT]="per-dir"
        [TRANSIENT_PROMPT_CHAR]=""
        [TRANSIENT_PROMPT_VERBOSE]="true"
        # ssh prefix
        [ENABLE_SSH_PREFIX]="true"
        [SSH_PREFIX]="via ssh:"
        [SSH_PREFIX_FOREGROUND_COLOR]="red"
        [SSH_PREFIX_BACKGROUND_COLOR]=""
        [SSH_PREFIX_BOLD]="false"
        [SSH_PREFIX_UNDERLINE]="false"
        # separators (user/host/dir)
        [PROMPT_SEPARATOR_FOREGROUND_COLOR]="white"
        [PROMPT_SEPARATOR_BACKGROUND_COLOR]=""
        [PROMPT_SEPARATOR_BOLD]="false"
        [PROMPT_SEPARATOR_UNDERLINE]="false"
        [USER_HOST_SEPARATOR]="@"
        [HOST_DIR_SEPARATOR]=":"
        # multiline
        [ENABLE_MULTILINE]="true"
        [FIRST_LINE_SEPARATOR_CHAR]=""
        [NEW_LINE_SEPARATOR_CHAR]=""
        [LAST_LINE_SEPARATOR_CHAR]=""
        # git status
        [ENABLE_GIT_STATUS]="true"
        [GIT_STATUS_ON_NEW_LINE]="auto"
        [GIT_STATUS_PREFIX]=" on "
        [GIT_STATUS_SUFFIX]=" "
        [GIT_BRANCH_PREFIX]=""
        [GIT_BRANCH_SUFFIX]=""
        # git decorations
        [ENABLE_GIT_STASH_COUNT]="false"
        [GIT_STASH_SYMBOL]="⚑"
        [ENABLE_GIT_REMOTE_STATE]="false"
        [GIT_REMOTE_AHEAD_SYMBOL]="↑"
        [GIT_REMOTE_BEHIND_SYMBOL]="↓"
        [GIT_REMOTE_SYNCED_SYMBOL]="≡"
        [GIT_CLEAN_SUFFIX]=""
        [GIT_CLEAN_FOREGROUND_COLOR]="black"
        [GIT_CLEAN_BACKGROUND_COLOR]="green"
        [GIT_CLEAN_BOLD]="false"
        [GIT_CLEAN_UNDERLINE]="false"
        [GIT_DIRTY_SUFFIX]="*"
        [GIT_DIRTY_FOREGROUND_COLOR]="black"
        [GIT_DIRTY_BACKGROUND_COLOR]="aqua"
        [GIT_DIRTY_BOLD]="false"
        [GIT_DIRTY_UNDERLINE]="false"
        # date/time
        [ENABLE_DATE_TIME]="true"
        [DATE_TIME_FORMAT]="%D{%H:%M:%S}"
        [DATE_TIME_FOREGROUND_COLOR]="white"
        [DATE_TIME_BACKGROUND_COLOR]=""
        [DATE_TIME_BOLD]="false"
        [DATE_TIME_UNDERLINE]="false"
        [DATE_TIME_PREFIX]=" "
        [DATE_TIME_SUFFIX]=""
        # exec timer
        [ENABLE_EXEC_TIMER]="true"
        [EXEC_TIMER_FOREGROUND_COLOR]="black"
        [EXEC_TIMER_BACKGROUND_COLOR]="olive"
        [EXEC_TIMER_BOLD]="false"
        [EXEC_TIMER_UNDERLINE]="false"
        [EXEC_TIMER_PREFIX]=" took "
        [EXEC_TIMER_SUFFIX]=" "
        [EXEC_TIMER_THRESHOLD]="2"
        # ssh connection count
        [ENABLE_SSH_CONNECTION_COUNT]="true"
        [SSH_CONNECTION_COUNT_FOREGROUND_COLOR]="black"
        [SSH_CONNECTION_COUNT_BACKGROUND_COLOR]="fuchsia"
        [SSH_CONNECTION_COUNT_BOLD]="false"
        [SSH_CONNECTION_COUNT_UNDERLINE]="false"
        [SSH_CONNECTION_COUNT_PREFIX]=" conn="
        [SSH_CONNECTION_COUNT_SUFFIX]=" "
        # job count
        [ENABLE_JOB_COUNT]="true"
        [JOB_COUNT_FOREGROUND_COLOR]="black"
        [JOB_COUNT_BACKGROUND_COLOR]="blue"
        [JOB_COUNT_BOLD]="false"
        [JOB_COUNT_UNDERLINE]="false"
        [JOB_COUNT_PREFIX]=" "
        [JOB_COUNT_SUFFIX]=" jobs "
        # exit status
        [ENABLE_EXIT_STATUS]="true"
        [ENABLE_FULL_EXIT_STATUS]="true"
        [EXIT_STATUS_FOREGROUND_COLOR]="black"
        [EXIT_STATUS_BACKGROUND_COLOR]="red"
        [EXIT_STATUS_BOLD]="false"
        [EXIT_STATUS_UNDERLINE]="false"
        [EXIT_STATUS_PREFIX]=" "
        [EXIT_STATUS_SUFFIX]=" "
    )
}

_dragon_init_types() {
    typeset -gA _DRAGON_TYPE=(
        [USE_NERD_FONT]="bool"
        [LEFT_SEGMENT_SEPARATOR]="string"
        [LEFT_SEGMENT_SEPARATOR_SAME_COLOR]="string"
        [RIGHT_SEGMENT_SEPARATOR]="string"
        [RIGHT_SEGMENT_SEPARATOR_SAME_COLOR]="string"
        [ENABLE_USERNAME]="bool"
        [USERNAME_FOREGROUND_COLOR]="color"
        [USERNAME_BACKGROUND_COLOR]="color"
        [USERNAME_BOLD]="bool"
        [USERNAME_UNDERLINE]="bool"
        [USERNAME_PREFIX]="string"
        [USERNAME_SUFFIX]="string"
        [ENABLE_USERNAME_COLORING_VIA_SSH]="bool"
        [USERNAME_VIA_SSH_FOREGROUND_COLOR]="color"
        [USERNAME_VIA_SSH_BACKGROUND_COLOR]="color"
        [USERNAME_VIA_SSH_BOLD]="bool"
        [USERNAME_VIA_SSH_UNDERLINE]="bool"
        [ENABLE_HOSTNAME]="bool"
        [HOSTNAME_FOREGROUND_COLOR]="color"
        [HOSTNAME_BACKGROUND_COLOR]="color"
        [HOSTNAME_BOLD]="bool"
        [HOSTNAME_UNDERLINE]="bool"
        [HOSTNAME_PREFIX]="string"
        [HOSTNAME_SUFFIX]="string"
        [ENABLE_HOSTNAME_COLORING_VIA_SSH]="bool"
        [HOSTNAME_VIA_SSH_FOREGROUND_COLOR]="color"
        [HOSTNAME_VIA_SSH_BACKGROUND_COLOR]="color"
        [HOSTNAME_VIA_SSH_BOLD]="bool"
        [HOSTNAME_VIA_SSH_UNDERLINE]="bool"
        [ENABLE_DIRECTORY]="bool"
        [DIRECTORY_FOREGROUND_COLOR]="color"
        [DIRECTORY_BACKGROUND_COLOR]="color"
        [DIRECTORY_BOLD]="bool"
        [DIRECTORY_UNDERLINE]="bool"
        [DIRECTORY_PREFIX]="string"
        [DIRECTORY_SUFFIX]="string"
        [DIRECTORY_FORMAT]="enum:regular|short|full"
        [PROMPT_CHAR]="string"
        [GIT_PROMPT_CHAR]="string"
        [PROMPT_CHAR_DEFAULT_FOREGROUND_COLOR]="color"
        [PROMPT_CHAR_DEFAULT_BACKGROUND_COLOR]="color"
        [PROMPT_CHAR_DEFAULT_BOLD]="bool"
        [PROMPT_CHAR_DEFAULT_UNDERLINE]="bool"
        [PROMPT_CHAR_PREFIX]="string"
        [PROMPT_CHAR_SUFFIX]="string"
        [ENABLE_EXIT_STATUS_PROMPT_COLORING]="bool"
        [PROMPT_CHAR_SUCCESS_FOREGROUND_COLOR]="color"
        [PROMPT_CHAR_SUCCESS_BACKGROUND_COLOR]="color"
        [PROMPT_CHAR_SUCCESS_BOLD]="bool"
        [PROMPT_CHAR_SUCCESS_UNDERLINE]="bool"
        [PROMPT_CHAR_FAILURE_FOREGROUND_COLOR]="color"
        [PROMPT_CHAR_FAILURE_BACKGROUND_COLOR]="color"
        [PROMPT_CHAR_FAILURE_BOLD]="bool"
        [PROMPT_CHAR_FAILURE_UNDERLINE]="bool"
        [ENABLE_TRANSIENT_PROMPT]="enum:true|false|per-dir"
        [TRANSIENT_PROMPT_CHAR]="string"
        [TRANSIENT_PROMPT_VERBOSE]="bool"
        [ENABLE_SSH_PREFIX]="bool"
        [SSH_PREFIX]="string"
        [SSH_PREFIX_FOREGROUND_COLOR]="color"
        [SSH_PREFIX_BACKGROUND_COLOR]="color"
        [SSH_PREFIX_BOLD]="bool"
        [SSH_PREFIX_UNDERLINE]="bool"
        [PROMPT_SEPARATOR_FOREGROUND_COLOR]="color"
        [PROMPT_SEPARATOR_BACKGROUND_COLOR]="color"
        [PROMPT_SEPARATOR_BOLD]="bool"
        [PROMPT_SEPARATOR_UNDERLINE]="bool"
        [USER_HOST_SEPARATOR]="string"
        [HOST_DIR_SEPARATOR]="string"
        [ENABLE_MULTILINE]="bool"
        [FIRST_LINE_SEPARATOR_CHAR]="string"
        [NEW_LINE_SEPARATOR_CHAR]="string"
        [LAST_LINE_SEPARATOR_CHAR]="string"
        [ENABLE_GIT_STATUS]="bool"
        [GIT_STATUS_ON_NEW_LINE]="enum:auto|never|always"
        [GIT_STATUS_PREFIX]="string"
        [GIT_STATUS_SUFFIX]="string"
        [GIT_BRANCH_PREFIX]="string"
        [GIT_BRANCH_SUFFIX]="string"
        [ENABLE_GIT_STASH_COUNT]="bool"
        [GIT_STASH_SYMBOL]="string"
        [ENABLE_GIT_REMOTE_STATE]="bool"
        [GIT_REMOTE_AHEAD_SYMBOL]="string"
        [GIT_REMOTE_BEHIND_SYMBOL]="string"
        [GIT_REMOTE_SYNCED_SYMBOL]="string"
        [GIT_CLEAN_SUFFIX]="string"
        [GIT_CLEAN_FOREGROUND_COLOR]="color"
        [GIT_CLEAN_BACKGROUND_COLOR]="color"
        [GIT_CLEAN_BOLD]="bool"
        [GIT_CLEAN_UNDERLINE]="bool"
        [GIT_DIRTY_SUFFIX]="string"
        [GIT_DIRTY_FOREGROUND_COLOR]="color"
        [GIT_DIRTY_BACKGROUND_COLOR]="color"
        [GIT_DIRTY_BOLD]="bool"
        [GIT_DIRTY_UNDERLINE]="bool"
        [ENABLE_DATE_TIME]="bool"
        [DATE_TIME_FORMAT]="string"
        [DATE_TIME_FOREGROUND_COLOR]="color"
        [DATE_TIME_BACKGROUND_COLOR]="color"
        [DATE_TIME_BOLD]="bool"
        [DATE_TIME_UNDERLINE]="bool"
        [DATE_TIME_PREFIX]="string"
        [DATE_TIME_SUFFIX]="string"
        [ENABLE_EXEC_TIMER]="bool"
        [EXEC_TIMER_FOREGROUND_COLOR]="color"
        [EXEC_TIMER_BACKGROUND_COLOR]="color"
        [EXEC_TIMER_BOLD]="bool"
        [EXEC_TIMER_UNDERLINE]="bool"
        [EXEC_TIMER_PREFIX]="string"
        [EXEC_TIMER_SUFFIX]="string"
        [EXEC_TIMER_THRESHOLD]="string"
        [ENABLE_SSH_CONNECTION_COUNT]="bool"
        [SSH_CONNECTION_COUNT_FOREGROUND_COLOR]="color"
        [SSH_CONNECTION_COUNT_BACKGROUND_COLOR]="color"
        [SSH_CONNECTION_COUNT_BOLD]="bool"
        [SSH_CONNECTION_COUNT_UNDERLINE]="bool"
        [SSH_CONNECTION_COUNT_PREFIX]="string"
        [SSH_CONNECTION_COUNT_SUFFIX]="string"
        [ENABLE_JOB_COUNT]="bool"
        [JOB_COUNT_FOREGROUND_COLOR]="color"
        [JOB_COUNT_BACKGROUND_COLOR]="color"
        [JOB_COUNT_BOLD]="bool"
        [JOB_COUNT_UNDERLINE]="bool"
        [JOB_COUNT_PREFIX]="string"
        [JOB_COUNT_SUFFIX]="string"
        [ENABLE_EXIT_STATUS]="bool"
        [ENABLE_FULL_EXIT_STATUS]="bool"
        [EXIT_STATUS_FOREGROUND_COLOR]="color"
        [EXIT_STATUS_BACKGROUND_COLOR]="color"
        [EXIT_STATUS_BOLD]="bool"
        [EXIT_STATUS_UNDERLINE]="bool"
        [EXIT_STATUS_PREFIX]="string"
        [EXIT_STATUS_SUFFIX]="string"
    )
}

_dragon_init_hints() {
    typeset -gA _DRAGON_HINT=(
        [DIRECTORY_FORMAT]="Values: 'regular' → ~/projects/foo  |  'short' → foo (last dir only)  |  'full' → /home/user/projects/foo"
        [DATE_TIME_FORMAT]="strftime format string, e.g. '%D{%H:%M:%S}' or '%D{%d/%m/%y | %H:%M}'"
        [GIT_STATUS_ON_NEW_LINE]="'auto': new line when prompt is too wide  |  'always'  |  'never': inline"
        [ENABLE_TRANSIENT_PROMPT]="'true': collapse after every command  |  'false': never collapse  |  'per-dir': like true, but keeps full prompt for the first command after cd"
        [TRANSIENT_PROMPT_CHAR]="Empty string = reuse PROMPT_CHAR"
        [TRANSIENT_PROMPT_VERBOSE]="When true, the collapsed prompt still shows the right-side info (exit code, timer, time). When false, rprompt is cleared too — just the char remains."
        [JOB_COUNT_SUFFIX]="Tip: if suffix contains the word 'jobs', '1 job' is shown instead of '1 jobs'"
        [EXEC_TIMER_THRESHOLD]="Integer seconds. Timer only shown when command took longer than this."
        [USE_NERD_FONT]="When false, powerline segment separators are hidden (works on any font)"
        [LEFT_SEGMENT_SEPARATOR]="Powerline glyph between background-colored segments (Nerd Font required)"
        [GIT_CLEAN_BACKGROUND_COLOR]="Set to '' (empty) for no background color on clean git status"
        [GIT_DIRTY_BACKGROUND_COLOR]="Set to '' (empty) for no background color on dirty git status"
    )
}

_dragon_init_groups() {
    typeset -ga _DRAGON_GROUPS=(
        nerd_font username username_ssh hostname hostname_ssh
        directory separators multiline
        prompt_char prompt_char_exit transient ssh_prefix
        git_status git_clean_dirty git_stash_remote
        datetime exec_timer ssh_conn_count job_count exit_status
    )

    typeset -gA _DRAGON_GROUP_TITLE=(
        [nerd_font]="Nerd Font & Segment Separators"
        [username]="Username"
        [username_ssh]="Username — SSH Override Colors"
        [hostname]="Hostname"
        [hostname_ssh]="Hostname — SSH Override Colors"
        [directory]="Directory"
        [separators]="Prompt Separators"
        [multiline]="Multiline Prompt"
        [prompt_char]="Prompt Character"
        [prompt_char_exit]="Prompt Character — Exit Status Colors"
        [transient]="Transient Prompt"
        [ssh_prefix]="SSH Prefix"
        [git_status]="Git Status"
        [git_clean_dirty]="Git Clean/Dirty Colors & Symbols"
        [git_stash_remote]="Git Stash & Remote State"
        [datetime]="Date & Time (rprompt)"
        [exec_timer]="Execution Timer (rprompt)"
        [ssh_conn_count]="SSH Connection Count (rprompt)"
        [job_count]="Background Jobs (rprompt)"
        [exit_status]="Exit Status (rprompt)"
    )

    typeset -gA _DRAGON_GROUP_DESC=(
        [nerd_font]="Powerline background-colored segments use Nerd Font glyphs as separators."
        [username]="Current user shown in the left prompt."
        [username_ssh]="Override username colors when connecting via SSH. Enable to see the SSH preview differ from normal."
        [hostname]="Machine hostname in the left prompt."
        [hostname_ssh]="Override hostname colors when connecting via SSH. Enable to see the SSH preview differ from normal."
        [directory]="Current working directory in the left prompt."
        [separators]="Characters placed between username, hostname, and directory segments."
        [multiline]="Split the prompt across two lines with optional decorative border chars."
        [prompt_char]="The character at the end of the left prompt (e.g. ❯ or \$)."
        [prompt_char_exit]="Prompt character colors when the last command succeeded or failed."
        [transient]="After a command runs, collapse the previous prompt to save screen space."
        [ssh_prefix]="Show a label (e.g. 'via ssh:') at the start of the prompt over SSH."
        [git_status]="Show git branch and dirty/clean status in the prompt."
        [git_clean_dirty]="Colors and suffix symbols for clean and dirty git working tree."
        [git_stash_remote]="Stash count indicator and ahead/behind/synced remote state symbols."
        [datetime]="Show current date/time on the right side of the prompt."
        [exec_timer]="Show how long the last command took to run."
        [ssh_conn_count]="Show count of other machines currently SSH-ed INTO this machine (shown in rprompt). Useful on servers to see who is connected."
        [job_count]="Show count of background jobs (&-suspended processes)."
        [exit_status]="Show the exit code when the last command failed."
    )

    typeset -gA _DRAGON_GROUP_VARS=(
        [nerd_font]="USE_NERD_FONT LEFT_SEGMENT_SEPARATOR LEFT_SEGMENT_SEPARATOR_SAME_COLOR RIGHT_SEGMENT_SEPARATOR RIGHT_SEGMENT_SEPARATOR_SAME_COLOR"
        [username]="ENABLE_USERNAME USERNAME_FOREGROUND_COLOR USERNAME_BACKGROUND_COLOR USERNAME_BOLD USERNAME_UNDERLINE USERNAME_PREFIX USERNAME_SUFFIX"
        [username_ssh]="ENABLE_USERNAME_COLORING_VIA_SSH USERNAME_VIA_SSH_FOREGROUND_COLOR USERNAME_VIA_SSH_BACKGROUND_COLOR USERNAME_VIA_SSH_BOLD USERNAME_VIA_SSH_UNDERLINE"
        [hostname]="ENABLE_HOSTNAME HOSTNAME_FOREGROUND_COLOR HOSTNAME_BACKGROUND_COLOR HOSTNAME_BOLD HOSTNAME_UNDERLINE HOSTNAME_PREFIX HOSTNAME_SUFFIX"
        [hostname_ssh]="ENABLE_HOSTNAME_COLORING_VIA_SSH HOSTNAME_VIA_SSH_FOREGROUND_COLOR HOSTNAME_VIA_SSH_BACKGROUND_COLOR HOSTNAME_VIA_SSH_BOLD HOSTNAME_VIA_SSH_UNDERLINE"
        [directory]="ENABLE_DIRECTORY DIRECTORY_FORMAT DIRECTORY_FOREGROUND_COLOR DIRECTORY_BACKGROUND_COLOR DIRECTORY_BOLD DIRECTORY_UNDERLINE DIRECTORY_PREFIX DIRECTORY_SUFFIX"
        [separators]="USER_HOST_SEPARATOR HOST_DIR_SEPARATOR PROMPT_SEPARATOR_FOREGROUND_COLOR PROMPT_SEPARATOR_BACKGROUND_COLOR PROMPT_SEPARATOR_BOLD PROMPT_SEPARATOR_UNDERLINE"
        [multiline]="ENABLE_MULTILINE FIRST_LINE_SEPARATOR_CHAR NEW_LINE_SEPARATOR_CHAR LAST_LINE_SEPARATOR_CHAR"
        [prompt_char]="PROMPT_CHAR GIT_PROMPT_CHAR PROMPT_CHAR_DEFAULT_FOREGROUND_COLOR PROMPT_CHAR_DEFAULT_BACKGROUND_COLOR PROMPT_CHAR_DEFAULT_BOLD PROMPT_CHAR_DEFAULT_UNDERLINE PROMPT_CHAR_PREFIX PROMPT_CHAR_SUFFIX"
        [prompt_char_exit]="ENABLE_EXIT_STATUS_PROMPT_COLORING PROMPT_CHAR_SUCCESS_FOREGROUND_COLOR PROMPT_CHAR_SUCCESS_BACKGROUND_COLOR PROMPT_CHAR_SUCCESS_BOLD PROMPT_CHAR_SUCCESS_UNDERLINE PROMPT_CHAR_FAILURE_FOREGROUND_COLOR PROMPT_CHAR_FAILURE_BACKGROUND_COLOR PROMPT_CHAR_FAILURE_BOLD PROMPT_CHAR_FAILURE_UNDERLINE"
        [transient]="ENABLE_TRANSIENT_PROMPT TRANSIENT_PROMPT_CHAR TRANSIENT_PROMPT_VERBOSE"
        [ssh_prefix]="ENABLE_SSH_PREFIX SSH_PREFIX SSH_PREFIX_FOREGROUND_COLOR SSH_PREFIX_BACKGROUND_COLOR SSH_PREFIX_BOLD SSH_PREFIX_UNDERLINE"
        [git_status]="ENABLE_GIT_STATUS GIT_STATUS_ON_NEW_LINE GIT_STATUS_PREFIX GIT_STATUS_SUFFIX GIT_BRANCH_PREFIX GIT_BRANCH_SUFFIX"
        [git_clean_dirty]="GIT_CLEAN_SUFFIX GIT_CLEAN_FOREGROUND_COLOR GIT_CLEAN_BACKGROUND_COLOR GIT_CLEAN_BOLD GIT_CLEAN_UNDERLINE GIT_DIRTY_SUFFIX GIT_DIRTY_FOREGROUND_COLOR GIT_DIRTY_BACKGROUND_COLOR GIT_DIRTY_BOLD GIT_DIRTY_UNDERLINE"
        [git_stash_remote]="ENABLE_GIT_STASH_COUNT GIT_STASH_SYMBOL ENABLE_GIT_REMOTE_STATE GIT_REMOTE_AHEAD_SYMBOL GIT_REMOTE_BEHIND_SYMBOL GIT_REMOTE_SYNCED_SYMBOL"
        [datetime]="ENABLE_DATE_TIME DATE_TIME_FORMAT DATE_TIME_FOREGROUND_COLOR DATE_TIME_BACKGROUND_COLOR DATE_TIME_BOLD DATE_TIME_UNDERLINE DATE_TIME_PREFIX DATE_TIME_SUFFIX"
        [exec_timer]="ENABLE_EXEC_TIMER EXEC_TIMER_THRESHOLD EXEC_TIMER_FOREGROUND_COLOR EXEC_TIMER_BACKGROUND_COLOR EXEC_TIMER_BOLD EXEC_TIMER_UNDERLINE EXEC_TIMER_PREFIX EXEC_TIMER_SUFFIX"
        [ssh_conn_count]="ENABLE_SSH_CONNECTION_COUNT SSH_CONNECTION_COUNT_FOREGROUND_COLOR SSH_CONNECTION_COUNT_BACKGROUND_COLOR SSH_CONNECTION_COUNT_BOLD SSH_CONNECTION_COUNT_UNDERLINE SSH_CONNECTION_COUNT_PREFIX SSH_CONNECTION_COUNT_SUFFIX"
        [job_count]="ENABLE_JOB_COUNT JOB_COUNT_FOREGROUND_COLOR JOB_COUNT_BACKGROUND_COLOR JOB_COUNT_BOLD JOB_COUNT_UNDERLINE JOB_COUNT_PREFIX JOB_COUNT_SUFFIX"
        [exit_status]="ENABLE_EXIT_STATUS ENABLE_FULL_EXIT_STATUS EXIT_STATUS_FOREGROUND_COLOR EXIT_STATUS_BACKGROUND_COLOR EXIT_STATUS_BOLD EXIT_STATUS_UNDERLINE EXIT_STATUS_PREFIX EXIT_STATUS_SUFFIX"
    )
}

# Presets — layout only. Add a new preset by:
#   1. Appending its name to _DRAGON_PRESET_NAMES
#   2. Adding _DRAGON_PRESET_DESC[<name>] and _DRAGON_PRESET_EXAMPLE[<name>]
#   3. Dropping a presets/<name>.conf.zsh file with export DRAGON__VAR='value' lines
# configure.zsh discovers all three by name; no changes needed there.
_dragon_init_presets() {
    typeset -ga _DRAGON_PRESET_NAMES=( short default verbose boxed blocks minimal corporate )
    typeset -gA _DRAGON_PRESET_DESC=(
        [short]='Minimal. hostname:~$ with git inline. No rprompt extras.'
        [default]='Balanced. username@hostname:dir ❯, git status, time & timer.'
        [verbose]='Maximum info. Multiline, full paths, timestamps, rich git.'
        [boxed]='Multiline ╭/│/╰╴ border, git on new line, ⏱ timer.'
        [blocks]='Colored BG segments, no text separators, single line.'
        [minimal]='No color, no glyphs. Plain ASCII, single line — works everywhere.'
        [corporate]='Muted & safe. ASCII prompt, minimal rprompt, no nerd glyphs.'
    )
    typeset -gA _DRAGON_PRESET_EXAMPLE=(
        [short]='hostname:~/projects ❯'
        [default]='user@myhost:~/projects on main ✔
              ❯'
        [verbose]='╭ user at myhost in /home/user/projects
              │  on ‹main› ✔
              ╰╴❯'
        [boxed]='╭ user at myhost in ~/projects
              │  on ‹main› ✔
              ╰╴❯'
        [blocks]=' user  myhost  ~/projects  main ✔  ❯'
        [minimal]='user@myhost:~/projects [main]
              $'
        [corporate]='user@myhost ~/projects (main)
              >'
    )
}

# Palettes — color vars only. Add a new palette by:
#   1. Appending its name to _DRAGON_PALETTE_NAMES
#   2. Adding _DRAGON_PALETTE_DESC[<name>]
#   3. Dropping a palettes/<name>.conf.zsh file with export DRAGON__*_COLOR lines
_dragon_init_palettes() {
    typeset -ga _DRAGON_PALETTE_NAMES=( default tokyonight dracula gruvbox nord )
    typeset -gA _DRAGON_PALETTE_DESC=(
        [default]='Schema defaults. Resets colors without changing layout.'
        [tokyonight]='Soft dark: sky-blue, purple, teal, salmon.'
        [dracula]='Purple BG segments, cyan dir, pink accents.'
        [gruvbox]='Warm earthy: amber, orange, olive, rust.'
        [nord]='Cool Arctic: steel-blue, frost, polar-teal, dusty-rose.'
    )
}
