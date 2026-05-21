# ─────────────────────────────────────────────────────────────────────────────
# configure.zsh
# Provides `dragon-configure [--new-only]` — interactive theme wizard.
# Sourced by dragon.zsh (not OMZ directly); no side effects at top level.
# ─────────────────────────────────────────────────────────────────────────────

# ── File-level constants ──────────────────────────────────────────────────────

typeset -g _DRAGON_CONF_FILE="${HOME}/.config/master-oogway/conf.zsh"
typeset -g _DRAGON_THEMES_DIR="${0:a:h}"   # .../dragon/ — derived from script location
typeset -g _DRAGON_STATE_DIR="${HOME}/.config/master-oogway"
typeset -g _DRAGON_STATE_FILE="${_DRAGON_STATE_DIR}/state"

# ── Schema (defaults, types, hints, groups) ──────────────────────────────────

source "${0:a:h}/schema.zsh"

# ─────────────────────────────────────────────────────────────────────────────
# State management
# ─────────────────────────────────────────────────────────────────────────────

_dragon_vars_hash() {
    # Hash the sorted list of _DRAGON_DEFAULTS keys — the authoritative schema
    # source of truth. Immune to grep over-matching comments/docs.
    # Must match notifier.zsh and install.sh — change all three together.
    printf '%s\n' "${(@k)_DRAGON_DEFAULTS}" | sort | md5sum | cut -d' ' -f1
}

_dragon_read_state() {
    typeset -gA _DRAGON_STATE=()
    [[ -f "${_DRAGON_STATE_FILE}" ]] || return
    while IFS= read -r line; do
        [[ "$line" == '#'* || -z "$line" ]] && continue
        # %%=* strips up to the first = for the key (keys are DRAGON__[A-Z_]+ — no = possible).
        # #*=  strips only the first = and keeps everything after, so values like "foo=bar" survive.
        local key="${line%%=*}" val="${line#*=}"
        _DRAGON_STATE[$key]="$val"
    done < "${_DRAGON_STATE_FILE}"
}

_dragon_write_state() {
    local preset="${1:-default}"
    local hash mtime
    hash=$(_dragon_vars_hash)
    mtime=$(stat -c '%Y' "${_DRAGON_THEMES_DIR}/schema.zsh" 2>/dev/null)
    _dragon_read_state   # load current state so we can preserve dismissed_hash
    mkdir -p "${_DRAGON_STATE_DIR}"
    {
        echo "configured=true"
        echo "preset=${preset}"
        echo "vars_hash=${hash}"
        echo "themes_mtime=${mtime}"
        # Preserve dismissed_hash across configure runs so --dismiss stays effective
        [[ -n "${_DRAGON_STATE[dismissed_hash]:-}" ]] \
            && echo "dismissed_hash=${_DRAGON_STATE[dismissed_hash]}"
    } > "${_DRAGON_STATE_FILE}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Conf file loader — fills _DRAGON_CURRENT from existing conf
# ─────────────────────────────────────────────────────────────────────────────

_dragon_load_current_conf() {
    # Start from defaults
    typeset -gA _DRAGON_CURRENT=()
    local var
    for var in "${(@k)_DRAGON_DEFAULTS}"; do
        _DRAGON_CURRENT[$var]="${_DRAGON_DEFAULTS[$var]}"
    done

    [[ -f "${_DRAGON_CONF_FILE}" ]] || return

    # Override with any active (uncommented) settings from the conf file
    local line
    while IFS= read -r line; do
        [[ "$line" == '#'* || "$line" =~ ^[[:space:]]*$ ]] && continue

        # Current format (single-quoted, since 2026-05-16): immune to shell
        # expansion of $, `, and \ in user-provided values. The greedy (.*)
        # captures up to the LAST ' before optional trailing whitespace +
        # comment, so values containing the escape sequence '\'' round-trip
        # cleanly.
        if [[ "$line" =~ "^[[:space:]]*export DRAGON__([A-Z_]+)='(.*)'[[:space:]]*(#.*)?$" ]]; then
            local varname="${match[1]}"
            local raw="${match[2]}"
            local q=\'
            raw="${raw//$q\\$q$q/$q}"       # unescape '\'' → '
            _DRAGON_CURRENT[$varname]="$raw"
        # Legacy format (double-quoted, pre-2026-05-16): read-only — we no
        # longer emit it, but existing users' conf.zsh files still parse.
        # Greedy (.*)" matches up to LAST " before optional comment, so this
        # also fixes the old reader's '" #'-substring truncation bug.
        elif [[ "$line" =~ "^[[:space:]]*export DRAGON__([A-Z_]+)=\"(.*)\"[[:space:]]*(#.*)?$" ]]; then
            local varname="${match[1]}"
            local raw="${match[2]}"
            raw="${raw//\\\"/\"}"           # unescape \" → "
            raw="${raw//\\\\/\\}"           # unescape \\ → \
            _DRAGON_CURRENT[$varname]="$raw"
        fi
    done < "${_DRAGON_CONF_FILE}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Presets
# ─────────────────────────────────────────────────────────────────────────────

# Reset _DRAGON_CURRENT to defaults, then dispatch to the preset's
# _dragon_preset_<name> function (registered in schema.zsh).
_dragon_apply_preset() {
    local preset="$1"
    local var
    for var in "${(@k)_DRAGON_DEFAULTS}"; do
        _DRAGON_CURRENT[$var]="${_DRAGON_DEFAULTS[$var]}"
    done
    local fn="_dragon_preset_${preset}"
    (( $+functions[$fn] )) && $fn
}

# ─────────────────────────────────────────────────────────────────────────────
# Live preview renderer
# ─────────────────────────────────────────────────────────────────────────────

# Read a single keypress without echoing it to the terminal.
# Uses stty to disable echo at the TTY driver level (more reliable than read -s).
_dragon_read_key() {
    local _dragon_stty
    _dragon_stty=$(stty -g 2>/dev/null)
    {
        stty -echo -icanon min 1 time 0 2>/dev/null
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
                print "  │ ${pline}"
            done <<< "$preview"
            print -P "%F{245}  └────────────────────────────────────────────────────────%f"
        else
            print -P "  %F{245}(preview unavailable — theme file not found or error)%f"
        fi
    )
}

# ─────────────────────────────────────────────────────────────────────────────
# Variable editor
# ─────────────────────────────────────────────────────────────────────────────

_dragon_edit_var() {
    local var="$1"
    local type="${_DRAGON_TYPE[$var]:-string}"
    local current="${_DRAGON_CURRENT[$var]}"
    local default="${_DRAGON_DEFAULTS[$var]:-}"
    local hint="${_DRAGON_HINT[$var]:-}"
    local current_display="${current:-(empty string)}"

    print ""
    print -P "  %BEditing%b: DRAGON__${var}"
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
                _dragon_read_key key
                case "$key" in
                    t|T) _DRAGON_CURRENT[$var]="true";     return ;;
                    f|F) _DRAGON_CURRENT[$var]="false";    return ;;
                    d|D) _DRAGON_CURRENT[$var]="$default"; return ;;
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
            _dragon_read_key key
            case "$key" in
                [1-9])
                    local idx=$(( key ))
                    (( idx >= 1 && idx <= ${#options} )) && _DRAGON_CURRENT[$var]="${options[$idx]}"
                    ;;
                d|D) _DRAGON_CURRENT[$var]="$default" ;;
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
            local val
            while true; do
                printf "  New value (Enter = keep '%s'): " "${current:-(empty)}"
                read -r val
                if [[ "$val" == e || "$val" == E ]]; then
                    _DRAGON_CURRENT[$var]=""; break
                elif [[ -z "$val" ]]; then
                    break  # keep current
                elif [[ "$val" =~ '^[0-9]+$' && 10#$val -le 255 ]]; then
                    _DRAGON_CURRENT[$var]="$val"; break
                elif [[ -n "${COLORS[${(L)val}]:-}" ]]; then
                    _DRAGON_CURRENT[$var]="${(L)val}"; break
                else
                    print -P "  %F{red}Invalid color '%F{white}${val}%F{red}' — enter a name or 0-255.%f"
                fi
            done
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
                _DRAGON_CURRENT[$var]=""
            elif [[ -n "$val" ]]; then
                _DRAGON_CURRENT[$var]="$val"
            fi
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Step renderer — returns 0=next, 1=back, 2=quit+save
# ─────────────────────────────────────────────────────────────────────────────

_dragon_run_step() {
    local group="$1"
    local step_num="$2"
    local total="$3"
    local vars
    vars=( ${(z)_DRAGON_GROUP_VARS[$group]} )

    while true; do
        clear

        # ── Header
        local title="${_DRAGON_GROUP_TITLE[$group]}"
        local pad_len=$(( 72 - 4 - ${#title} - 1 ))
        (( pad_len < 2 )) && pad_len=2
        local dashes="${(r:$pad_len::─:):-}"
        print -P "%B%F{cyan}── Step ${step_num}/${total}: ${title} ${dashes}%f%b"
        print -P "   %F{245}${_DRAGON_GROUP_DESC[$group]}%f"
        print ""

        # ── Preview
        print -P "  %BPrompt preview%b (git: main ✔  exit: 0):"
        _dragon_render_preview --group="${group}"
        # Show a second contextual preview where relevant.
        case "$group" in
            username_ssh|hostname_ssh|ssh_prefix)
                _dragon_render_preview --ssh --group="${group}" ;;
            prompt_char_exit|exit_status)
                _dragon_render_preview --fail --group="${group}" ;;
            transient)
                _dragon_render_preview --transient --group="${group}" ;;
        esac
        print ""

        # ── Variable list
        print -P "  %BVariables:%b"
        local i=1
        for var in "${vars[@]}"; do
            local val="${_DRAGON_CURRENT[$var]}"
            local default="${_DRAGON_DEFAULTS[$var]:-}"
            # Show quoted form for values with leading/trailing whitespace so they're visible.
            local val_trimmed="${${val#"${val%%[! ]*}"}%"${val##*[! ]}"}"
            local val_display="${val:-(empty)}"
            [[ -n "$val" && "$val" != "$val_trimmed" ]] && val_display="\"${val}\""
            local marker=""
            if [[ "$val" != "$default" ]]; then
                marker=" %B%F{yellow}★%f%b"
            fi
            local type_hint=""
            local vtype="${_DRAGON_TYPE[$var]:-string}"
            [[ "$vtype" == enum:* ]] && type_hint=" %F{245}[${vtype#enum:}]%f"
            printf "  %3d. %-52s" "$i" "DRAGON__${var}"
            print -P "%F{yellow}${val_display}%f${marker}${type_hint}"
            (( i++ ))
        done
        print ""

        # ── Navigation
        print -P "  %F{245}[number] edit var   [b] back   [Enter/n] next   [q] save & quit   [d] reset group to defaults%f"
        printf "  > "
        local key
        _dragon_read_key key

        case "$key" in
            ''|$'\n'|n|N) return 0 ;;
            b|B)           return 1 ;;
            q|Q)           return 2 ;;
            d|D)
                for var in "${vars[@]}"; do
                    _DRAGON_CURRENT[$var]="${_DRAGON_DEFAULTS[$var]:-}"
                done
                ;;
            [0-9])
                local idx="$key"
                if (( ${#vars} > 9 )); then
                    local key2 _stty2
                    _stty2=$(stty -g 2>/dev/null)
                    stty -echo -icanon min 0 time 5 2>/dev/null
                    IFS= read -k1 key2 2>/dev/null || key2=""
                    stty "$_stty2" 2>/dev/null
                    [[ "$key2" == [0-9] ]] && idx="${key}${key2}"
                fi
                idx=$(( idx ))
                if (( idx >= 1 && idx <= ${#vars} )); then
                    _dragon_edit_var "${vars[$idx]}"
                fi
                ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# First-run guided tour
# ─────────────────────────────────────────────────────────────────────────────

_dragon_guided_tour() {
    clear
    print -P "%B%F{cyan}── Welcome to dragon ────────────────────────────────────────────────%f%b"
    print ""
    print -P "  Here is what your prompt will look like and what each part means."
    print ""
    print -P "  %B%F{green}Left prompt%f%b"
    print ""
    print -P "    %F{green}user%f%F{245}@%f%F{cyan}hostname%f%F{245}:%f%F{yellow}~/projects%f %F{magenta}on main ✔%f"
    print -P "    %F{green}❯%f"
    print ""
    print -P "    %F{245}user@hostname%f   — who and where you are (hidden when not needed)"
    print -P "    %F{245}~/projects%f      — current directory (short, regular, or full path)"
    print -P "    %F{245}main ✔%f          — git branch + clean/dirty indicator"
    print -P "    %F{245}❯%f               — prompt character (green = last command succeeded,"
    print -P "                         red = it failed)"
    print ""
    print -P "  %B%F{blue}Right prompt%f%b"
    print ""
    print -P "    %F{245}1m 5s  2j  14:32:01%f"
    print ""
    print -P "    %F{245}1m 5s%f       — how long the last command took"
    print -P "    %F{245}2j%f          — number of background jobs"
    print -P "    %F{245}14:32:01%f    — current time"
    print -P "    %F{red}✘ 1%f         — exit code of the last command (hidden on success)"
    print ""
    print -P "  %B%F{245}Git status indicators%f%b"
    print ""
    print -P "    %F{green}≡%f  in sync with remote    %F{yellow}↑3%f  3 commits ahead"
    print -P "    %F{red}↓2%f  2 commits behind       %F{yellow}*%f   uncommitted changes"
    print ""
    print -P "  Everything is configurable — the next screen lets you choose a starting"
    print -P "  preset (minimal, balanced, or verbose), then steps through every feature."
    print ""
    print -P "  %B%F{245}Font check%f%b"
    print ""
    print -P "  dragon uses special characters for a richer look."
    print -P "  Powerline arrow:  "
    print -P "  Nerd Font icon:   "
    print ""
    printf "  Do both characters render as a solid arrow and a folder icon? [y/N] "
    local _nf_key
    _dragon_read_key _nf_key
    print ""
    if [[ "$_nf_key" == y || "$_nf_key" == Y ]]; then
        print -P "  %F{green}✓ Nerd Font glyphs enabled.%f"
    else
        _DRAGON_CURRENT[USE_NERD_FONT]="false"
        print -P "  %F{yellow}✓ ASCII fallbacks will be used — no special font needed.%f"
        print -P "  %F{245}  (install a Nerd Font later → re-run %Bdragon-configure%b to switch back)%f"
    fi
    print ""
    print -P "  %F{245}Press any key to continue...%f"
    _dragon_read_key _dragon_any
}

# ─────────────────────────────────────────────────────────────────────────────
# Preset selector
# ─────────────────────────────────────────────────────────────────────────────

_dragon_select_preset() {
    clear
    print -P "%B%F{cyan}── dragon Theme Configurator ────────────────────────────────────────%f%b"
    print ""
    print -P "  Welcome! Choose a %Bstarting point%b for your prompt:"
    print ""

    # The "default" preset is the recommended starting point. By convention it
    # is named "default" — if absent, we fall back to the first registered name.
    local default_idx=1 i=1 name
    for name in "${_DRAGON_PRESET_NAMES[@]}"; do
        [[ "$name" == "default" ]] && default_idx=$i
        print -P "  %B[${i}] ${name}%b — ${_DRAGON_PRESET_DESC[$name]}"
        local line
        while IFS= read -r line; do
            print -- "               ${line}"
        done <<< "${_DRAGON_PRESET_EXAMPLE[$name]}"
        print ""
        (( i++ ))
    done

    print -P "  %F{245}You will step through each feature group and can change anything.%f"
    print -P "  %F{245}Defaults are pre-applied; you only need to change what you want.%f"
    print ""
    local n=${#_DRAGON_PRESET_NAMES}
    printf "  Choice [1-%d, default=%d]: " "$n" "$default_idx"

    local key chosen_preset
    _dragon_read_key key
    if [[ "$key" =~ ^[0-9]$ ]] && (( key >= 1 && key <= n )); then
        chosen_preset="${_DRAGON_PRESET_NAMES[$key]}"
    else
        chosen_preset="${_DRAGON_PRESET_NAMES[$default_idx]}"
    fi
    print -P "\n  %F{green}✓ Starting from ${chosen_preset} preset%f"

    _DRAGON_CHOSEN_PRESET="$chosen_preset"
    _dragon_apply_preset "$chosen_preset"
    sleep 0.6
}

# ─────────────────────────────────────────────────────────────────────────────
# Conf file writer
# ─────────────────────────────────────────────────────────────────────────────

_dragon_write_conf() {
    local tmp_file="${_DRAGON_CONF_FILE}.wizard.tmp"

    {
        cat <<'HEADER'
##########################################
#### Theme configuration: dragon #####
##########################################
# Generated by dragon-configure. Edit freely, or re-run it to reconfigure.
# Uncommented lines (export ...) override theme defaults.
# Commented-out lines (# export ...) show all available options at their defaults.
#
# SSH forwarding: add 'SendEnv DRAGON__*' to ~/.ssh/config to carry your
# theme to remote machines running dragon. On the sending machine, conf.zsh
# exports DRAGON__FORWARDED=1 so it travels with the wildcard SendEnv.
# On the receiving machine, conf.zsh sees DRAGON__FORWARDED already set and
# returns immediately — forwarded values are never overwritten.
[[ "${DRAGON__FORWARDED:-}" == "1" ]] && return
export DRAGON__FORWARDED=1
#
# Variable naming convention:
#   DRAGON__ENABLE_{FEATURE}           — bool: true / false
#   DRAGON__{FEATURE}_FOREGROUND_COLOR — color name or 0-255
#   DRAGON__{FEATURE}_BACKGROUND_COLOR — color name or 0-255, empty = no color
#   DRAGON__{FEATURE}_BOLD             — bool
#   DRAGON__{FEATURE}_UNDERLINE        — bool
#   DRAGON__{FEATURE}_PREFIX           — string prepended before the segment
#   DRAGON__{FEATURE}_SUFFIX           — string appended after the segment
#
# Color values: name (black red green yellow blue magenta cyan white
#   grey maroon lime olive navy fuchsia aqua silver) or numeric 0-255.
# To browse 256-color palette, run:
#   for i in {0..255}; do print -Pn "%K{$i}  %k%F{$i}${(l:3::0:)i}%f " ${${(M)$((i%6)):#3}:+$'\n'}; done

HEADER

        # Write each group
        for group in "${_DRAGON_GROUPS[@]}"; do
            local title="${_DRAGON_GROUP_TITLE[$group]}"
            local pad_len=$(( 76 - 4 - ${#title} - 1 ))
            (( pad_len < 2 )) && pad_len=2
            local dashes="${(r:$pad_len::─:):-}"
            printf '# ── %s %s\n' "$title" "$dashes"
            printf '# %s\n' "${_DRAGON_GROUP_DESC[$group]}"

            local vars
            vars=( ${(z)_DRAGON_GROUP_VARS[$group]} )
            for var in "${vars[@]}"; do
                local val="${_DRAGON_CURRENT[$var]}"
                local default="${_DRAGON_DEFAULTS[$var]:-}"
                local hint="${_DRAGON_HINT[$var]:-}"
                local vtype="${_DRAGON_TYPE[$var]:-string}"
                # Single-quoted output: immune to shell expansion of $, `, and \.
                # The only char needing escape inside '...' is ' itself, via the
                # standard '\'' idiom (close-quote, escaped-quote, reopen-quote).
                # Use a $q variable because in double-quoted strings `\'` is 2
                # chars (\, '), not 1 — building '\\\'' inline would be wrong.
                local q=\'
                local safe_val="${val//$q/$q\\$q$q}"

                # Emit type hint for special vars
                if [[ -n "$hint" ]]; then
                    printf '# %s\n' "$hint"
                elif [[ "$vtype" == enum:* ]]; then
                    printf '# Values: %s\n' "${vtype#enum:}"
                fi

                if [[ "$val" == "$default" ]]; then
                    printf "# export DRAGON__%s='%s'  # default\n" "$var" "$safe_val"
                else
                    printf "export DRAGON__%s='%s'\n" "$var" "$safe_val"
                fi
            done
            printf '\n'
        done
    } > "$tmp_file"

    if ! zsh -n "$tmp_file" 2>/dev/null; then
        print -P "%F{red}[dragon]%f Internal error: generated conf.zsh failed syntax check — not saved." >&2
        rm -f "$tmp_file"
        return 1
    fi

    command mv "$tmp_file" "${_DRAGON_CONF_FILE}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Start menu — shown when conf file already exists
# ─────────────────────────────────────────────────────────────────────────────

_dragon_filter_changed_groups() {
    local -a changed=()
    local group var
    for group in "${_DRAGON_GROUPS[@]}"; do
        local vars=( ${(z)_DRAGON_GROUP_VARS[$group]} )
        for var in "${vars[@]}"; do
            if [[ "${_DRAGON_CURRENT[$var]}" != "${_DRAGON_DEFAULTS[$var]:-}" ]]; then
                changed+=("$group")
                break
            fi
        done
    done
    _DRAGON_GROUPS=("${changed[@]}")
}

# Shared confirm-and-auto-backup for destructive preset resets. Caller prints
# its own header so the question can be specific. Returns 0 if the user
# accepts (and the backup, if any, succeeded); 1 if they decline.
_dragon_warn_preset_reset() {
    local prompt="${1:-Continue?}"
    if [[ -f "${_DRAGON_CONF_FILE}" ]]; then
        print -P "  Your current settings will be replaced."
        print -P "  %F{245}A timestamped backup will be saved to ${_DRAGON_CONF_FILE}.bak.<ts>%f"
        print ""
    fi
    printf "  %s [y/N] " "$prompt"
    local _confirm
    read -r _confirm
    [[ "$_confirm" == y* || "$_confirm" == Y* ]] || return 1
    if [[ -f "${_DRAGON_CONF_FILE}" ]]; then
        local _bak="${_DRAGON_CONF_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "${_DRAGON_CONF_FILE}" "$_bak"
        print -P "  %F{green}✓%f Backup saved: %B${_bak}%b"
    fi
    return 0
}

_dragon_show_start_menu() {
    clear
    print -P "%B%F{cyan}── dragon Theme Configurator ────────────────────────────────────────%f%b"
    print ""
    print -P "  Config found at %B${_DRAGON_CONF_FILE}%b"
    print ""
    print -P "  %B[1]%b Edit current config  — step through your non-default settings only"
    print -P "  %B[2]%b Full wizard          — step through all variable groups"
    print -P "  %B[3]%b Reset to preset      — discard current config, start fresh"
    print -P "  %B[4]%b Open in \$EDITOR      — edit the file directly (${EDITOR:-nano})"
    print ""
    printf "  Choice [1/2/3/4, default=1]: "

    local key
    _dragon_read_key key
    print ""

    case "$key" in
        2)
            # Full wizard: keep current settings, step through ALL groups
            print -P "  %F{green}✓ Full wizard%f"
            sleep 0.4
            _DRAGON_CHOSEN_PRESET="${_DRAGON_STATE[preset]:-default}"
            ;;
        3)
            clear
            print -P "%B%F{cyan}── dragon: Reset current config to preset ───────────────────────────%f%b"
            print ""
            print -P "  This will discard your current settings and step you through"
            print -P "  choosing a preset (short / default / verbose)."
            if ! _dragon_warn_preset_reset "Continue with reset?"; then
                print ""
                print -P "  %F{245}Cancelled — your current config is unchanged.%f"
                sleep 0.6
                _dragon_cleanup
                return 1
            fi
            print -P "  %F{green}✓ Reset to preset%f"
            sleep 0.4
            _dragon_select_preset
            ;;
        4)
            print -P "  %F{green}✓ Opening in ${EDITOR:-nano}...%f"
            sleep 0.4
            ${EDITOR:-nano} "${_DRAGON_CONF_FILE}"
            _dragon_cleanup
            return 1  # signal caller to exit without running wizard
            ;;
        *)
            # 1 or Enter — edit current (changed groups only)
            print -P "  %F{green}✓ Editing current config%f"
            sleep 0.4
            _dragon_filter_changed_groups
            if (( ${#_DRAGON_GROUPS} == 0 )); then
                clear
                print -P "  %F{245}All settings are at their defaults — nothing to edit.%f"
                print -P "  Run with %B[2]%b Full wizard to review everything."
                print ""
                printf "  Press any key to exit... "
                _dragon_read_key _dragon_any
                _dragon_cleanup
                return 1
            fi
            _DRAGON_CHOSEN_PRESET="${_DRAGON_STATE[preset]:-default}"
            ;;
    esac
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Main function
# ─────────────────────────────────────────────────────────────────────────────

dragon-configure() {
    if [[ "${1-}" == "--help" || "${1-}" == "-h" ]]; then
        cat <<'EOF'
Usage: dragon-configure [options]

Options:
  (none)              Full interactive wizard — step through every setting
  --new-only          Only configure variables added since the last run
  --preset <name>     Instantly switch to a preset (short / default / verbose)
  --dismiss           Silence the "new variables" notifier until next update
  --version, -v       Print the installed dragon version
  --help, -h          Show this help

Config file: ~/.config/master-oogway/conf.zsh
EOF
        return 0
    fi

    if [[ "${1-}" == "--version" || "${1-}" == "-v" ]]; then
        local version
        version=$(git -C "${HOME}/.master-oogway" log -1 --format="%cd-%h" --date=format:"%Y-%m-%d_%H%M%S" 2>/dev/null \
            || echo "unknown")
        echo "dragon ${version}"
        return 0
    fi

    if [[ "${1-}" == "--dismiss" ]]; then
        local current_hash current_mtime
        current_hash=$(_dragon_vars_hash)
        current_mtime=$(stat -c '%Y' "${_DRAGON_THEMES_DIR}/schema.zsh" 2>/dev/null)
        mkdir -p "${_DRAGON_STATE_DIR}"
        local tmp_state="${_DRAGON_STATE_FILE}.tmp"
        grep -v -e '^dismissed_hash=' -e '^themes_mtime=' "${_DRAGON_STATE_FILE}" \
            2>/dev/null > "${tmp_state}" || true
        printf 'dismissed_hash=%s\nthemes_mtime=%s\n' "${current_hash}" "${current_mtime}" \
            >> "${tmp_state}"
        command mv "${tmp_state}" "${_DRAGON_STATE_FILE}"
        print -P "%F{green}✓%f Dragon notifier dismissed until next update."
        return 0
    fi

    if [[ "${ZSH_THEME:-}" != "dragon" ]]; then
        print -P "%F{yellow}[dragon] Warning: ZSH_THEME is '${ZSH_THEME:-<unset>}', not 'dragon' — conf.zsh changes will have no effect until you switch themes.%f"
    fi

    local new_only=false
    [[ "${1-}" == "--new-only" ]] && new_only=true

    # Init all data
    _dragon_init_defaults
    _dragon_init_types
    _dragon_init_hints
    _dragon_init_groups
    _dragon_init_presets
    typeset -g _DRAGON_CHOSEN_PRESET="default"
    typeset -gA _DRAGON_STATE=()

    # Load existing conf (sets _DRAGON_CURRENT from defaults + active conf values)
    _dragon_load_current_conf

    # ── Preset switcher: dragon-configure --preset <name>
    if [[ "${1-}" == "--preset" ]]; then
        local _preset="${2:-}"
        if [[ -z "$_preset" || -z "${_DRAGON_PRESET_DESC[$_preset]:-}" ]]; then
            print -P "%F{red}✗%f Invalid preset: '${_preset:-<none>}'"
            print -P "  Valid presets: %B${(j:%b  %B:)_DRAGON_PRESET_NAMES[@]}%b"
            print -P "  Usage: dragon-configure --preset <name>"
            _dragon_cleanup
            return 1
        fi

        clear
        print -P "%B%F{cyan}── dragon: Switch to '${_preset}' preset ────────────────────────────%f%b"
        print ""
        print -P "  This will reset your theme config to the %B${_preset}%b preset defaults."
        if ! _dragon_warn_preset_reset "Switch to ${_preset} preset now?"; then
            print ""
            print -P "  %F{245}Aborted. Your conf.zsh is unchanged. Re-run: dragon-configure --preset ${_preset}%f"
            _dragon_cleanup
            return 0
        fi

        # Preserve USE_NERD_FONT — it reflects terminal capability, not style preference.
        # _dragon_apply_preset resets all vars to schema defaults; we restore it afterward.
        # Only restore if the saved value is non-empty — otherwise let the preset default win
        # (avoids zero-ing USE_NERD_FONT on a never-configured system).
        local _saved_nerd_font="${_DRAGON_CURRENT[USE_NERD_FONT]-}"
        _dragon_apply_preset "$_preset"
        [[ -n "$_saved_nerd_font" ]] && _DRAGON_CURRENT[USE_NERD_FONT]="$_saved_nerd_font"
        _dragon_write_conf
        _dragon_write_state "$_preset"
        print ""
        print -P "  %F{green}✓ Switched to ${_preset} preset.%f"
        print -P "  %F{245}Reload to apply: %Bsoursh%b"
        print -P "  %F{245}Fine-tune with:  %Bdragon-configure%b%f"
        _dragon_cleanup
        return 0
    fi

    # ── New-only mode: check for new vars
    if $new_only; then
        _dragon_read_state
        local stored_hash="${_DRAGON_STATE[vars_hash]:-}"
        local current_hash
        current_hash=$(_dragon_vars_hash)
        if [[ "$stored_hash" == "$current_hash" ]]; then
            print -P "%F{green}✓ No new dragon theme variables detected.%f"
            print -P "  Run %Bdragon-configure%b (without --new-only) to reconfigure everything."
            _dragon_cleanup
            return 0
        fi
        clear
        print -P "%B%F{cyan}── dragon: New Theme Features ───────────────────────────────────────%f%b"
        print ""
        print -P "  New theme variables have been added since you last configured."
        print -P "  Default values have been applied for them."
        print -P "  Stepping through all groups — your existing settings are preserved."
        print ""
        print -P "  %F{245}Press any key to start...%f"
        _dragon_read_key _dragon_any
        _DRAGON_CHOSEN_PRESET="${_DRAGON_STATE[preset]:-default}"
    elif [[ -f "${_DRAGON_CONF_FILE}" ]]; then
        _dragon_read_state
        _dragon_show_start_menu || return 0
    else
        # First run — guided tour then preset selection
        _dragon_guided_tour
        _dragon_select_preset
    fi

    # ── Step through all groups
    local step=0
    local total=${#_DRAGON_GROUPS}
    while (( step < total )); do
        _dragon_run_step "${_DRAGON_GROUPS[$((step + 1))]}" $((step + 1)) $total
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
    _dragon_render_preview
    print ""
    printf "  Save configuration? [Y/n]: "
    local confirm
    read -r confirm
    if [[ "$confirm" == n* || "$confirm" == N* ]]; then
        print -P "  %F{yellow}Discarded. No changes were saved.%f"
        _dragon_cleanup
        return 0
    fi

    # ── Write conf and state
    _dragon_write_conf
    _dragon_write_state "${_DRAGON_CHOSEN_PRESET}"

    # Apply directly to the current shell — export every chosen value so the
    # already-set DRAGON__ vars are overwritten (set_if_unset won't help here).
    local var val
    for var val in "${(@kv)_DRAGON_CURRENT}"; do
        export "DRAGON__${var}=${val}"
    done
    dragon__update_zsh_prompt 2>/dev/null

    print ""
    print -P "  %F{green}✓ Saved to %B${_DRAGON_CONF_FILE}%b%F{green} — prompt updated immediately.%f"
    print -P "  %F{245}Edit that file directly to change individual settings without re-running the wizard.%f"
    print ""

    _dragon_cleanup
}

_dragon_cleanup() {
    unset _DRAGON_DEFAULTS _DRAGON_CURRENT _DRAGON_TYPE _DRAGON_HINT _DRAGON_STATE _DRAGON_CHOSEN_PRESET
    unset _DRAGON_GROUP_TITLE _DRAGON_GROUP_DESC _DRAGON_GROUP_VARS _DRAGON_GROUPS
    unset _DRAGON_PRESET_NAMES _DRAGON_PRESET_DESC _DRAGON_PRESET_EXAMPLE
}
