# ─────────────────────────────────────────────────────────────────────────────
# appa-fino-configure.zsh
# Provides `appa-fino-configure [--new-only]` — interactive theme wizard.
# Sourced by oh-my-zsh via ZSH_CUSTOM; no side effects at top level.
# ─────────────────────────────────────────────────────────────────────────────

# ── File-level constants ──────────────────────────────────────────────────────

typeset -g _AF_CONF_FILE="${HOME}/.config/appa-fino/conf.zsh"
typeset -g _AF_THEME_FILE="${HOME}/.appa-fino/zsh-custom.d/themes/appa-fino.zsh"
typeset -g _AF_STATE_DIR="${HOME}/.config/appa-fino"
typeset -g _AF_STATE_FILE="${_AF_STATE_DIR}/state"

# ─────────────────────────────────────────────────────────────────────────────
# State management
# ─────────────────────────────────────────────────────────────────────────────

_af_vars_hash() {
    grep -o 'APPA_FINO__[A-Z_]*' "${_AF_THEME_FILE}" 2>/dev/null \
        | sort -u | md5sum | cut -d' ' -f1
}

_af_read_state() {
    typeset -gA _AF_STATE=()
    [[ -f "${_AF_STATE_FILE}" ]] || return
    while IFS='=' read -r key val; do
        [[ "$key" == '#'* || -z "$key" ]] && continue
        _AF_STATE[$key]="$val"
    done < "${_AF_STATE_FILE}"
}

_af_write_state() {
    local preset="${1:-default}"
    local hash
    hash=$(_af_vars_hash)
    mkdir -p "${_AF_STATE_DIR}"
    {
        echo "configured=true"
        echo "preset=${preset}"
        echo "vars_hash=${hash}"
    } > "${_AF_STATE_FILE}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Data: defaults, types, groups, hints
# ─────────────────────────────────────────────────────────────────────────────

_af_init_defaults() {
    typeset -gA _AF_DEFAULTS=(
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

_af_init_types() {
    typeset -gA _AF_TYPE=(
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

_af_init_hints() {
    typeset -gA _AF_HINT=(
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

_af_init_groups() {
    typeset -ga _AF_GROUPS=(
        nerd_font username username_ssh hostname hostname_ssh
        directory separators multiline
        prompt_char prompt_char_exit transient ssh_prefix
        git_status git_clean_dirty git_stash_remote
        datetime exec_timer ssh_conn_count job_count exit_status
    )

    typeset -gA _AF_GROUP_TITLE=(
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

    typeset -gA _AF_GROUP_DESC=(
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

    typeset -gA _AF_GROUP_VARS=(
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

# ─────────────────────────────────────────────────────────────────────────────
# Conf file loader — fills _AF_CURRENT from existing conf
# ─────────────────────────────────────────────────────────────────────────────

_af_load_current_conf() {
    # Start from defaults
    typeset -gA _AF_CURRENT=()
    local var
    for var in "${(@k)_AF_DEFAULTS}"; do
        _AF_CURRENT[$var]="${_AF_DEFAULTS[$var]}"
    done

    [[ -f "${_AF_CONF_FILE}" ]] || return

    # Override with any active (uncommented) settings from the conf file
    local line
    while IFS= read -r line; do
        [[ "$line" == '#'* || "$line" =~ ^[[:space:]]*$ ]] && continue
        if [[ "$line" =~ ^[[:space:]]*'export APPA_FINO__'([A-Z_]+)'="'(.*) ]]; then
            local varname="${match[1]}"
            local raw="${match[2]%%\" #*}"  # strip closing " and trailing comment
            raw="${raw//\\\"/\"}"           # unescape \" → "
            raw="${raw//\\\\/\\}"           # unescape \\ → \
            _AF_CURRENT[$varname]="$raw"
        fi
    done < "${_AF_CONF_FILE}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Presets
# ─────────────────────────────────────────────────────────────────────────────

_af_apply_preset() {
    local preset="$1"
    # Reset to pure defaults first
    local var
    for var in "${(@k)_AF_DEFAULTS}"; do
        _AF_CURRENT[$var]="${_AF_DEFAULTS[$var]}"
    done

    case "$preset" in
        short)
            _AF_CURRENT[LEFT_SEGMENT_SEPARATOR]=""
            _AF_CURRENT[LEFT_SEGMENT_SEPARATOR_SAME_COLOR]=""
            _AF_CURRENT[RIGHT_SEGMENT_SEPARATOR]=""
            _AF_CURRENT[RIGHT_SEGMENT_SEPARATOR_SAME_COLOR]=""
            _AF_CURRENT[ENABLE_USERNAME]="false"
            _AF_CURRENT[DIRECTORY_FORMAT]="short"
            _AF_CURRENT[PROMPT_CHAR]='$'
            _AF_CURRENT[GIT_PROMPT_CHAR]='$'
            _AF_CURRENT[ENABLE_SSH_PREFIX]="false"
            _AF_CURRENT[USER_HOST_SEPARATOR]=""
            _AF_CURRENT[HOST_DIR_SEPARATOR]=":"
            _AF_CURRENT[ENABLE_MULTILINE]="false"
            _AF_CURRENT[GIT_STATUS_ON_NEW_LINE]="never"
            _AF_CURRENT[GIT_STATUS_PREFIX]=""
            _AF_CURRENT[GIT_STATUS_SUFFIX]=" "
            _AF_CURRENT[GIT_BRANCH_PREFIX]=""
            _AF_CURRENT[GIT_BRANCH_SUFFIX]=""
            _AF_CURRENT[GIT_CLEAN_SUFFIX]=""
            _AF_CURRENT[GIT_CLEAN_FOREGROUND_COLOR]="navy"
            _AF_CURRENT[GIT_CLEAN_BACKGROUND_COLOR]=""
            _AF_CURRENT[GIT_DIRTY_SUFFIX]="*"
            _AF_CURRENT[GIT_DIRTY_FOREGROUND_COLOR]="navy"
            _AF_CURRENT[GIT_DIRTY_BACKGROUND_COLOR]=""
            _AF_CURRENT[ENABLE_DATE_TIME]="false"
            _AF_CURRENT[ENABLE_EXEC_TIMER]="false"
            _AF_CURRENT[ENABLE_JOB_COUNT]="false"
            _AF_CURRENT[ENABLE_EXIT_STATUS]="false"
            ;;
        verbose)
            _AF_CURRENT[DIRECTORY_FORMAT]="full"
            _AF_CURRENT[USER_HOST_SEPARATOR]=" at "
            _AF_CURRENT[HOST_DIR_SEPARATOR]=" in "
            _AF_CURRENT[FIRST_LINE_SEPARATOR_CHAR]="╭ "
            _AF_CURRENT[NEW_LINE_SEPARATOR_CHAR]="│"
            _AF_CURRENT[LAST_LINE_SEPARATOR_CHAR]="╰╴"
            _AF_CURRENT[ENABLE_MULTILINE]="true"
            _AF_CURRENT[GIT_STATUS_ON_NEW_LINE]="always"
            _AF_CURRENT[GIT_STATUS_PREFIX]=" on "
            _AF_CURRENT[GIT_BRANCH_PREFIX]="‹"
            _AF_CURRENT[GIT_BRANCH_SUFFIX]="›"
            _AF_CURRENT[GIT_CLEAN_SUFFIX]="✔"
            _AF_CURRENT[GIT_DIRTY_SUFFIX]="✘"
            _AF_CURRENT[ENABLE_DATE_TIME]="true"
            _AF_CURRENT[DATE_TIME_FORMAT]='%D{%d/%m/%y | %H:%M:%S}'
            _AF_CURRENT[DATE_TIME_PREFIX]=" at "
            _AF_CURRENT[ENABLE_EXEC_TIMER]="true"
            _AF_CURRENT[EXEC_TIMER_PREFIX]=" took "
            _AF_CURRENT[EXEC_TIMER_THRESHOLD]="2"
            _AF_CURRENT[ENABLE_JOB_COUNT]="true"
            _AF_CURRENT[JOB_COUNT_SUFFIX]=" jobs "
            _AF_CURRENT[ENABLE_EXIT_STATUS]="true"
            _AF_CURRENT[EXIT_STATUS_PREFIX]=" code:"
            ;;
        # default: nothing extra — all set to _AF_DEFAULTS above
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Live preview renderer
# ─────────────────────────────────────────────────────────────────────────────

# Read a single keypress without echoing it to the terminal.
# Uses stty to disable echo at the TTY driver level (more reliable than read -s).
_af_read_key() {
    local _af_stty
    _af_stty=$(stty -g 2>/dev/null)
    stty -echo -icanon min 1 time 0 2>/dev/null
    read -rk1 "$1"
    stty "$_af_stty" 2>/dev/null
}

_af_render_preview() {
    # Flags: --ssh, --fail, --transient, --group=<name>
    local ssh_mode=false fail_mode=false transient_mode=false group="" _af_flag
    for _af_flag in "$@"; do
        [[ "$_af_flag" == "--ssh"       ]] && ssh_mode=true
        [[ "$_af_flag" == "--fail"      ]] && fail_mode=true
        [[ "$_af_flag" == "--transient" ]] && transient_mode=true
        [[ "$_af_flag" == --group=*     ]] && group="${_af_flag#--group=}"
    done

    # Export all current APPA_FINO__ vars so the subshell inherits them.
    # The theme's set_if_unset only sets vars that are NOT already set,
    # so pre-exported vars act as overrides.
    local var val
    for var val in "${(@kv)_AF_CURRENT}"; do
        export "APPA_FINO__${var}=${val}"
    done

    local ssh_inject="" preview_exit_code=0
    $ssh_mode  && ssh_inject="SSH_TTY=/dev/pts/0"
    $fail_mode && preview_exit_code=1

    # Build group-specific fake data so rprompt segments are visible in preview.
    local group_inject=""
    case "$group" in
        exec_timer)
            # timer=-65: subshell SECONDS≈0, so SECONDS-timer≈65 >= threshold → shows "1m 5s"
            group_inject="timer=-65" ;;
        job_count)
            # Override job count function to inject 2 fake background jobs.
            group_inject="appa_fino__set_job_count() {
                FINAL_APPA_FINO__JOB_COUNT_CONTENT=''
                ! \$APPA_FINO__ENABLE_JOB_COUNT && return
                local jobs_count=2
                REAL_APPA_FINO__JOB_COUNT_CONTENT=2
                __set_job_count_prefix_and_suffix
                REAL_APPA_FINO__JOB_COUNT_FOREGROUND_COLOR=\"\$APPA_FINO__JOB_COUNT_FOREGROUND_COLOR\"
                REAL_APPA_FINO__JOB_COUNT_BACKGROUND_COLOR=\"\$APPA_FINO__JOB_COUNT_BACKGROUND_COLOR\"
                REAL_APPA_FINO__JOB_COUNT_BOLD=\"\$APPA_FINO__JOB_COUNT_BOLD\"
                REAL_APPA_FINO__JOB_COUNT_UNDERLINE=\"\$APPA_FINO__JOB_COUNT_UNDERLINE\"
                __appa_fino__show JOB_COUNT
                FINAL_APPA_FINO__JOB_COUNT_CONTENT=\"\$SHOW_RESULT\"
            }" ;;
        ssh_conn_count)
            # Fake 2 incoming SSH connections (SSH_TTY not needed here — this is about
            # connections TO this machine, not whether we ourselves are on SSH).
            group_inject="__set_ssh_connection_count_content() {
                REAL_APPA_FINO__SSH_CONNECTION_COUNT_CONTENT=2
            }" ;;
        exit_status)
            # The --fail flag already sets exit_code=1; nothing extra needed.
            : ;;
        git_stash_remote)
            group_inject="VCS_STATUS_STASHES=2
            VCS_STATUS_COMMITS_AHEAD=3
            VCS_STATUS_COMMITS_BEHIND=1" ;;
        git_clean_dirty)
            group_inject="VCS_STATUS_HAS_UNSTAGED=1" ;;
    esac

    local preview
    preview=$(zsh -c "
        ${ssh_inject}
        zle()             { :; }
        gitstatus_start() { :; }
        gitstatus_query() { :; }
        gitstatus_stop()  { :; }
        add-zsh-hook()    { :; }
        trap '' WINCH
        HOME='${HOME}'
        PWD='/home/${USER}/projects/myapp/src/components'
        VCS_STATUS_RESULT='ok-sync'
        VCS_STATUS_LOCAL_BRANCH='main'
        VCS_STATUS_HAS_UNSTAGED=0
        VCS_STATUS_HAS_STAGED=0
        VCS_STATUS_HAS_UNTRACKED=0
        VCS_STATUS_COMMITS_AHEAD=0
        VCS_STATUS_COMMITS_BEHIND=0
        VCS_STATUS_STASHES=0
        VCS_STATUS_REMOTE_NAME='origin'
        exit_code=${preview_exit_code}
        __LAST_EXIT_CODE=${preview_exit_code}
        source '${_AF_THEME_FILE}' 2>/dev/null
        ${group_inject}
        appa_fino__update_zsh_prompt 2>/dev/null
        if [[ '${transient_mode}' == true ]]; then
            __appa_fino_zle_line_finish 2>/dev/null
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
            print "  │ ${pline}"
        done <<< "$preview"
        print -P "%F{245}  └────────────────────────────────────────────────────────%f"
    else
        print -P "  %F{245}(preview unavailable — theme file not found or error)%f"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Variable editor
# ─────────────────────────────────────────────────────────────────────────────

_af_edit_var() {
    local var="$1"
    local type="${_AF_TYPE[$var]:-string}"
    local current="${_AF_CURRENT[$var]}"
    local default="${_AF_DEFAULTS[$var]:-}"
    local hint="${_AF_HINT[$var]:-}"
    local current_display="${current:-(empty string)}"

    print ""
    print -P "  %BEditing%b: APPA_FINO__${var}"
    [[ -n "$hint" ]] && print -P "  %F{245}${hint}%f"
    print -P "  %F{yellow}Current value%f: ${current_display}"
    print -P "  %F{245}Default%f: ${default:-(empty string)}"
    print ""

    case "$type" in
        bool)
            print -P "  [t] true   [f] false   [d] reset to default   [c] cancel"
            local key
            while true; do
                printf "  > "
                _af_read_key key
                case "$key" in
                    t|T) _AF_CURRENT[$var]="true";     return ;;
                    f|F) _AF_CURRENT[$var]="false";    return ;;
                    d|D) _AF_CURRENT[$var]="$default"; return ;;
                    c|C|$'\e'|$'\n') return ;;
                esac
            done
            ;;
        enum:*)
            local options
            options=( ${(s:|:)${type#enum:}} )
            local i=1
            for opt in "${options[@]}"; do
                local marker=""
                [[ "$opt" == "$current" ]] && marker=" %B← current%b"
                print -P "  [${i}] ${opt}${marker}"
                (( i++ ))
            done
            print -P "  [d] reset to default (${default})   [c] cancel"
            printf "  > "
            local key
            _af_read_key key
            case "$key" in
                [1-9])
                    local idx=$(( key ))
                    (( idx >= 1 && idx <= ${#options} )) && _AF_CURRENT[$var]="${options[$idx]}"
                    ;;
                d|D) _AF_CURRENT[$var]="$default" ;;
            esac
            ;;
        color)
            print -P "  %F{245}Color names: black red green yellow blue magenta cyan white%f"
            print -P "  %F{245}             grey maroon lime olive navy fuchsia aqua silver%f"
            print -P "  %F{245}Or 0–255 for extended 256 colors. Leave empty for no color.%f"
            print -P "  %F{245}To browse all 256 colors, run:%f"
            print "  for i in {0..255}; do print -Pn \"%K{\$i}  %k%F{\$i}\${(l:3::0:)i}%f \" \${(M)\$((i%6)):#3}:+\$'\\n'}; done"
            print ""
            if [[ -n "$current" ]]; then
                print -P "  %F{245}[e] erase → empty   [Enter] keep current   or type new value%f"
            else
                print -P "  %F{245}[Enter] keep empty   or type new value%f"
            fi
            printf "  New value (Enter = keep '%s'): " "${current:-(empty)}"
            local val
            read -r val
            if [[ "$val" == e || "$val" == E ]]; then
                _AF_CURRENT[$var]=""
            elif [[ -n "$val" ]]; then
                _AF_CURRENT[$var]="$val"
            fi
            ;;
        string)
            if [[ -n "$current" ]]; then
                print -P "  %F{245}[e] erase → empty   [Enter] keep current   or type new value%f"
            else
                print -P "  %F{245}[Enter] keep empty   or type new value%f"
            fi
            printf "  New value (Enter = keep '%s'): " "${current:-(empty)}"
            local val
            read -r val
            if [[ "$val" == e || "$val" == E ]]; then
                _AF_CURRENT[$var]=""
            elif [[ -n "$val" ]]; then
                _AF_CURRENT[$var]="$val"
            fi
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Step renderer — returns 0=next, 1=back, 2=quit+save
# ─────────────────────────────────────────────────────────────────────────────

_af_run_step() {
    local group="$1"
    local step_num="$2"
    local total="$3"
    local vars
    vars=( ${(z)_AF_GROUP_VARS[$group]} )

    while true; do
        clear

        # ── Header
        local title="${_AF_GROUP_TITLE[$group]}"
        local pad_len=$(( 72 - 4 - ${#title} - 1 ))
        (( pad_len < 2 )) && pad_len=2
        local dashes="${(r:$pad_len::─:):-}"
        print -P "%B%F{cyan}── Step ${step_num}/${total}: ${title} ${dashes}%f%b"
        print -P "   %F{245}${_AF_GROUP_DESC[$group]}%f"
        print ""

        # ── Preview
        print -P "  %BPrompt preview%b (git: main ✔  exit: 0):"
        _af_render_preview --group="${group}"
        # Show a second contextual preview where relevant.
        case "$group" in
            username_ssh|hostname_ssh|ssh_prefix)
                _af_render_preview --ssh --group="${group}" ;;
            prompt_char_exit|exit_status)
                _af_render_preview --fail --group="${group}" ;;
            transient)
                _af_render_preview --transient --group="${group}" ;;
        esac
        print ""

        # ── Variable list
        print -P "  %BVariables:%b"
        local i=1
        for var in "${vars[@]}"; do
            local val="${_AF_CURRENT[$var]}"
            local default="${_AF_DEFAULTS[$var]:-}"
            # Show quoted form for values with leading/trailing whitespace so they're visible.
            local val_trimmed="${${val#"${val%%[! ]*}"}%"${val##*[! ]}"}"
            local val_display="${val:-(empty)}"
            [[ -n "$val" && "$val" != "$val_trimmed" ]] && val_display="\"${val}\""
            local marker=""
            if [[ "$val" != "$default" ]]; then
                marker=" %B%F{yellow}★%f%b"
            fi
            local type_hint=""
            local vtype="${_AF_TYPE[$var]:-string}"
            [[ "$vtype" == enum:* ]] && type_hint=" %F{245}[${vtype#enum:}]%f"
            printf "  %3d. %-52s" "$i" "APPA_FINO__${var}"
            print -P "%F{yellow}${val_display}%f${marker}${type_hint}"
            (( i++ ))
        done
        print ""

        # ── Navigation
        print -P "  %F{245}[number] edit var   [b] back   [Enter/n] next   [q] save & quit   [d] reset group to defaults%f"
        printf "  > "
        local key
        _af_read_key key

        case "$key" in
            ''|$'\n'|n|N) return 0 ;;
            b|B)           return 1 ;;
            q|Q)           return 2 ;;
            d|D)
                for var in "${vars[@]}"; do
                    _AF_CURRENT[$var]="${_AF_DEFAULTS[$var]:-}"
                done
                ;;
            [1-9])
                local idx=$(( key ))
                if (( idx >= 1 && idx <= ${#vars} )); then
                    _af_edit_var "${vars[$idx]}"
                fi
                ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# Preset selector
# ─────────────────────────────────────────────────────────────────────────────

_af_select_preset() {
    clear
    print -P "%B%F{cyan}── appa-fino Theme Configurator ────────────────────────────────────────%f%b"
    print ""
    print -P "  Welcome! Choose a %Bstarting point%b for your prompt:"
    print ""
    print -P "  %B[1] short%b   — Minimal. hostname:~\$ with git inline. No rprompt extras."
    print -P "               hostname:~/projects ❯"
    print ""
    print -P "  %B[2] default%b — Balanced. username@hostname:dir ❯, git status, time & timer."
    print -P "               user@myhost:~/projects on main ✔"
    print -P "               ❯"
    print ""
    print -P "  %B[3] verbose%b — Maximum info. Multiline, full paths, timestamps, rich git."
    print -P "               ╭ user at myhost in /home/user/projects"
    print -P "               │  on ‹main› ✔"
    print -P "               ╰╴❯"
    print ""
    print -P "  %F{245}You will step through each feature group and can change anything.%f"
    print -P "  %F{245}Defaults are pre-applied; you only need to change what you want.%f"
    print ""
    printf "  Choice [1/2/3, default=2]: "

    local key
    _af_read_key key

    local chosen_preset
    case "$key" in
        1) chosen_preset="short";   print -P "\n  %F{green}✓ Starting from short preset%f"   ;;
        3) chosen_preset="verbose"; print -P "\n  %F{green}✓ Starting from verbose preset%f" ;;
        *) chosen_preset="default"; print -P "\n  %F{green}✓ Starting from default preset%f" ;;
    esac

    _AF_CHOSEN_PRESET="$chosen_preset"
    _af_apply_preset "$chosen_preset"
    sleep 0.6
}

# ─────────────────────────────────────────────────────────────────────────────
# Conf file writer
# ─────────────────────────────────────────────────────────────────────────────

_af_write_conf() {
    local tmp_file="${_AF_CONF_FILE}.wizard.tmp"

    {
        cat <<'HEADER'
##########################################
#### Theme configuration: appa-fino #####
##########################################
# Generated by appa-fino-configure. Edit freely, or re-run it to reconfigure.
# Uncommented lines (export ...) override theme defaults.
# Commented-out lines (# export ...) show all available options at their defaults.
#
# SSH forwarding: add 'SendEnv APPA_FINO__*' to ~/.ssh/config to carry your
# theme to remote machines running appa-fino. The guard below ensures forwarded
# values are never overwritten by the remote's copy of this file.
[[ -v APPA_FINO__ENABLE_USERNAME ]] && return
#
# Variable naming convention:
#   APPA_FINO__ENABLE_{FEATURE}           — bool: true / false
#   APPA_FINO__{FEATURE}_FOREGROUND_COLOR — color name or 0-255
#   APPA_FINO__{FEATURE}_BACKGROUND_COLOR — color name or 0-255, empty = no color
#   APPA_FINO__{FEATURE}_BOLD             — bool
#   APPA_FINO__{FEATURE}_UNDERLINE        — bool
#   APPA_FINO__{FEATURE}_PREFIX           — string prepended before the segment
#   APPA_FINO__{FEATURE}_SUFFIX           — string appended after the segment
#
# Color values: name (black red green yellow blue magenta cyan white
#   grey maroon lime olive navy fuchsia aqua silver) or numeric 0-255.
# To browse 256-color palette, run:
#   for i in {0..255}; do print -Pn "%K{$i}  %k%F{$i}${(l:3::0:)i}%f " ${${(M)$((i%6)):#3}:+$'\n'}; done

HEADER

        # Write each group
        for group in "${_AF_GROUPS[@]}"; do
            local title="${_AF_GROUP_TITLE[$group]}"
            local pad_len=$(( 76 - 4 - ${#title} - 1 ))
            (( pad_len < 2 )) && pad_len=2
            local dashes="${(r:$pad_len::─:):-}"
            printf '# ── %s %s\n' "$title" "$dashes"
            printf '# %s\n' "${_AF_GROUP_DESC[$group]}"

            local vars
            vars=( ${(z)_AF_GROUP_VARS[$group]} )
            for var in "${vars[@]}"; do
                local val="${_AF_CURRENT[$var]}"
                local default="${_AF_DEFAULTS[$var]:-}"
                local hint="${_AF_HINT[$var]:-}"
                local vtype="${_AF_TYPE[$var]:-string}"
                local safe_val="${val//\\/\\\\}"
                safe_val="${safe_val//\"/\\\"}"

                # Emit type hint for special vars
                if [[ -n "$hint" ]]; then
                    printf '# %s\n' "$hint"
                elif [[ "$vtype" == enum:* ]]; then
                    printf '# Values: %s\n' "${vtype#enum:}"
                fi

                if [[ "$val" == "$default" ]]; then
                    printf '# export APPA_FINO__%s="%s"  # default\n' "$var" "$safe_val"
                else
                    printf 'export APPA_FINO__%s="%s"\n' "$var" "$safe_val"
                fi
            done
            printf '\n'
        done
    } > "$tmp_file"

    mv "$tmp_file" "${_AF_CONF_FILE}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Start menu — shown when conf file already exists
# ─────────────────────────────────────────────────────────────────────────────

_af_filter_changed_groups() {
    local -a changed=()
    local group var
    for group in "${_AF_GROUPS[@]}"; do
        local vars=( ${(z)_AF_GROUP_VARS[$group]} )
        for var in "${vars[@]}"; do
            if [[ "${_AF_CURRENT[$var]}" != "${_AF_DEFAULTS[$var]:-}" ]]; then
                changed+=("$group")
                break
            fi
        done
    done
    _AF_GROUPS=("${changed[@]}")
}

_af_show_start_menu() {
    clear
    print -P "%B%F{cyan}── appa-fino Theme Configurator ────────────────────────────────────────%f%b"
    print ""
    print -P "  Config found at %B${_AF_CONF_FILE}%b"
    print ""
    print -P "  %B[1]%b Edit current config  — step through your non-default settings only"
    print -P "  %B[2]%b Full wizard          — step through all variable groups"
    print -P "  %B[3]%b Reset to preset      — discard current config, start fresh"
    print -P "  %B[4]%b Open in \$EDITOR      — edit the file directly (${EDITOR:-nano})"
    print ""
    printf "  Choice [1/2/3/4, default=1]: "

    local key
    _af_read_key key
    print ""

    case "$key" in
        2)
            print -P "  %F{green}✓ Full wizard%f"
            sleep 0.4
            _af_select_preset
            ;;
        3)
            print -P "  %F{green}✓ Reset to preset%f"
            sleep 0.4
            _af_select_preset
            ;;
        4)
            print -P "  %F{green}✓ Opening in ${EDITOR:-nano}...%f"
            sleep 0.4
            ${EDITOR:-nano} "${_AF_CONF_FILE}"
            _af_cleanup
            return 1  # signal caller to exit without running wizard
            ;;
        *)
            # 1 or Enter — edit current (changed groups only)
            print -P "  %F{green}✓ Editing current config%f"
            sleep 0.4
            _af_filter_changed_groups
            if (( ${#_AF_GROUPS} == 0 )); then
                clear
                print -P "  %F{245}All settings are at their defaults — nothing to edit.%f"
                print -P "  Run with %B[2]%b Full wizard to review everything."
                print ""
                printf "  Press any key to exit... "
                _af_read_key _af_any
                _af_cleanup
                return 1
            fi
            _AF_CHOSEN_PRESET="${_AF_STATE[preset]:-default}"
            ;;
    esac
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Main function
# ─────────────────────────────────────────────────────────────────────────────

appa-fino-configure() {
    local new_only=false
    [[ "${1-}" == "--new-only" ]] && new_only=true

    # Init all data
    _af_init_defaults
    _af_init_types
    _af_init_hints
    _af_init_groups
    typeset -g _AF_CHOSEN_PRESET="default"
    typeset -gA _AF_STATE=()

    # Load existing conf (sets _AF_CURRENT from defaults + active conf values)
    _af_load_current_conf

    # ── New-only mode: check for new vars
    if $new_only; then
        _af_read_state
        local stored_hash="${_AF_STATE[vars_hash]:-}"
        local current_hash
        current_hash=$(_af_vars_hash)
        if [[ "$stored_hash" == "$current_hash" ]]; then
            print -P "%F{green}✓ No new appa-fino theme variables detected.%f"
            print -P "  Run %Bappa-fino-configure%b (without --new-only) to reconfigure everything."
            _af_cleanup
            return 0
        fi
        clear
        print -P "%B%F{cyan}── appa-fino: New Theme Features ───────────────────────────────────────%f%b"
        print ""
        print -P "  New theme variables have been added since you last configured."
        print -P "  Default values have been applied for them."
        print -P "  Stepping through all groups — your existing settings are preserved."
        print ""
        print -P "  %F{245}Press any key to start...%f"
        _af_read_key _af_any
        _AF_CHOSEN_PRESET="${_AF_STATE[preset]:-default}"
    elif [[ -f "${_AF_CONF_FILE}" ]]; then
        _af_read_state
        _af_show_start_menu || return 0
    else
        # No conf yet — preset selection
        _af_select_preset
    fi

    # ── Step through all groups
    local step=0
    local total=${#_AF_GROUPS}
    while (( step < total )); do
        _af_run_step "${_AF_GROUPS[$((step + 1))]}" $((step + 1)) $total
        local rc=$?
        case $rc in
            0) (( step++ )) ;;
            1) (( step > 0 )) && (( step-- )) ;;
            2) break ;;
        esac
    done

    # ── Final preview
    clear
    print -P "%B%F{cyan}── Final Result ─────────────────────────────────────────────────────────%f%b"
    print ""
    print -P "  Your configured prompt:"
    _af_render_preview
    print ""
    printf "  Save configuration? [Y/n]: "
    local confirm
    read -r confirm
    if [[ "$confirm" == n* || "$confirm" == N* ]]; then
        print -P "  %F{yellow}Discarded. No changes were saved.%f"
        _af_cleanup
        return 0
    fi

    # ── Write conf and state
    _af_write_conf
    _af_write_state "${_AF_CHOSEN_PRESET}"

    # Apply directly to the current shell — export every chosen value so the
    # already-set APPA_FINO__ vars are overwritten (set_if_unset won't help here).
    local var val
    for var val in "${(@kv)_AF_CURRENT}"; do
        export "APPA_FINO__${var}=${val}"
    done
    appa_fino__update_zsh_prompt 2>/dev/null

    print ""
    print -P "  %F{green}✓ Saved to %B${_AF_CONF_FILE}%b%F{green} — prompt updated immediately.%f"
    print -P "  %F{245}Edit that file directly to change individual settings without re-running the wizard.%f"
    print ""

    _af_cleanup
}

_af_cleanup() {
    unset _AF_DEFAULTS _AF_CURRENT _AF_TYPE _AF_HINT _AF_STATE _AF_CHOSEN_PRESET
    unset _AF_GROUP_TITLE _AF_GROUP_DESC _AF_GROUP_VARS _AF_GROUPS
}
