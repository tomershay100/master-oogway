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
    # schema.zsh is the sentinel: it's the only file that changes when a new DRAGON__ variable
    # is added. One stat call instead of a find|sort|tail pipeline on every shell open.
    current_mtime=$(stat -c '%Y' "${themes_dir}/schema.zsh" 2>/dev/null)

    if [[ -n "$stored_mtime" && "$current_mtime" == "$stored_mtime" ]]; then
        # Theme files unchanged since last configure run — skip hash entirely.
        current_hash="$stored_hash"
    else
        # Hash sorted _DRAGON_DEFAULTS keys — immune to comment/doc changes.
        # Must match configure.zsh:_dragon_vars_hash and install.sh
        # — change all three together.
        current_hash=$(printf '%s\n' "${(@k)_DRAGON_DEFAULTS}" | sort | md5sum | cut -d' ' -f1)
    fi

    [[ "${current_hash}" != "${stored_hash}" ]] || return
    [[ "${current_hash}" != "${dismissed_hash}" ]] || return

    print -P "%F{yellow}[dragon]%f New theme options available — run %Bdragon-configure --new-only%b"
    print -P "%F{245}  (to silence this: dragon-configure --dismiss)%f"
} "${0:a:h}"
