# dragon-notifier.zsh — sourced from ~/.zshrc after oh-my-zsh.
# Notifies once per session if new theme variables were added since last config run.

() {
    local themes_dir="${HOME}/.appa-fino/zsh-custom.d/themes"
    local state_file="${HOME}/.config/appa-fino/state"

    [[ -d "${themes_dir}" ]] || return
    [[ -f "${state_file}" ]] || return

    local current_hash stored_hash
    current_hash=$(grep -roh 'DRAGON__[A-Z_]*' "${themes_dir}" 2>/dev/null \
        | sort -u | md5sum | cut -d' ' -f1)
    stored_hash=$(grep '^vars_hash=' "${state_file}" 2>/dev/null | cut -d= -f2)

    [[ "${current_hash}" != "${stored_hash}" ]] || return

    print -P "%F{yellow}[dragon]%f New theme options available — run %Bdragon-configure --new-only%b"
}
