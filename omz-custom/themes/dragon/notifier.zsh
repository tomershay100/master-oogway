# notifier.zsh — sourced by dragon.zsh-theme (so it only runs when ZSH_THEME=dragon).
# Notifies once per new hash if theme variables were added since last configure run.
#
# Performance: on the common path (no new variables) the grep file scan is
# skipped entirely by comparing the themes directory mtime against the value
# cached in the state file by dragon-configure / _dragon_write_state.

# Resolve the themes dir at SOURCE time and pass it as $1 to the anon function.
# Inside an anon function, $0 is the literal string "(anon)" — NOT the script
# file — so `${0:a:h}` would resolve to $PWD's parent (often $HOME) and the
# downstream `find` would scan the user's entire home directory. Don't change
# this without testing in a fresh shell.
() {
    local themes_dir="$1"
    local state_file="${HOME}/.config/master-oogway/state"

    [[ -d "${themes_dir}" ]] || return
    [[ -f "${state_file}" ]] || return

    local stored_hash dismissed_hash stored_mtime current_mtime current_hash
    stored_hash=$(grep -m1 '^vars_hash='     "${state_file}" 2>/dev/null | cut -d= -f2)
    dismissed_hash=$(grep -m1 '^dismissed_hash=' "${state_file}" 2>/dev/null | cut -d= -f2)
    stored_mtime=$(grep -m1 '^themes_mtime=' "${state_file}" 2>/dev/null | cut -d= -f2)
    current_mtime=$(find "${themes_dir}" -name '*.zsh' -printf '%T@\n' 2>/dev/null \
        | sort -n | tail -1)

    if [[ -n "$stored_mtime" && "$current_mtime" == "$stored_mtime" ]]; then
        # Theme files unchanged since last configure run — skip the grep entirely.
        current_hash="$stored_hash"
    else
        # Hash the SET of DRAGON__VARNAME identifiers across the theme dir.
        # Must match install.sh:571 and configure.zsh:_dragon_vars_hash
        # — change all three together.
        current_hash=$(grep -Eroh 'DRAGON__[A-Z_]+' "${themes_dir}" 2>/dev/null \
            | sort -u | md5sum | cut -d' ' -f1)
    fi

    [[ "${current_hash}" != "${stored_hash}" ]] || return
    [[ "${current_hash}" != "${dismissed_hash}" ]] || return

    print -P "%F{yellow}[dragon]%f New theme options available — run %Bdragon-configure --new-only%b"
    print -P "%F{245}  (to silence until next update: dragon-configure --dismiss)%f"

    # Rewrite the state file atomically — update dismissed_hash and mtime in place,
    # so dismissed_hash entries don't accumulate and mtime stays fresh.
    local tmp_state="${state_file}.tmp"
    grep -v -e '^dismissed_hash=' -e '^themes_mtime=' "${state_file}" 2>/dev/null \
        > "${tmp_state}" || true
    printf 'dismissed_hash=%s\nthemes_mtime=%s\n' "${current_hash}" "${current_mtime}" \
        >> "${tmp_state}"
    command mv "${tmp_state}" "${state_file}"
} "${0:a:h}"
