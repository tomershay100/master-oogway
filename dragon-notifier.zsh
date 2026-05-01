# dragon-notifier.zsh — sourced from ~/.zshrc after oh-my-zsh.
# Notifies once per session if new theme variables were added since last config run.

() {
    local theme_file="${HOME}/.dragon/zsh-custom.d/themes/dragon-notifier.zsh"
    local state_file="${HOME}/.config/dragon/state"

    [[ -f "${theme_file}" ]] || return
    [[ -f "${state_file}" ]] || return

    local current_hash stored_hash
    current_hash=$(grep -o 'DRAGON__[A-Z_]*' "${theme_file}" 2>/dev/null \
        | sort -u | md5sum | cut -d' ' -f1)
    stored_hash=$(grep '^vars_hash=' "${state_file}" 2>/dev/null | cut -d= -f2)

    [[ "${current_hash}" != "${stored_hash}" ]] || return

    print -P "%F{yellow}[dragon]%f New theme options available — run %Bdragon-configure --new-only%b"
}
