# appa-fino.zsh — sourced from ~/.zshrc after oh-my-zsh.
# Notifies once per session if new theme variables were added since last config run.

() {
    local theme_file="${HOME}/.appa-fino/zsh-custom.d/themes/appa-fino.zsh"
    local state_file="${HOME}/.config/appa-fino/state"

    [[ -f "${theme_file}" ]] || return
    [[ -f "${state_file}" ]] || return

    local current_hash stored_hash
    current_hash=$(grep -o 'APPA_FINO__[A-Z_]*' "${theme_file}" 2>/dev/null \
        | sort -u | md5sum | cut -d' ' -f1)
    stored_hash=$(grep '^vars_hash=' "${state_file}" 2>/dev/null | cut -d= -f2)

    [[ "${current_hash}" != "${stored_hash}" ]] || return

    print -P "%F{yellow}[appa-fino]%f New theme options available — run %Bappa-fino-configure --new-only%b"
}
