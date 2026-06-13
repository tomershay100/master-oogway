
_MO_INSTALL_DIR="${HOME}/.master-oogway"

_mo_version() {
    if git -C "$_MO_INSTALL_DIR" rev-parse --git-dir &>/dev/null; then
        git -C "$_MO_INSTALL_DIR" log -1 \
            --format="master-oogway %cd-%h" --date=format:"%Y-%m-%d_%H%M%S"
    else
        echo "master-oogway (unknown — $_MO_INSTALL_DIR is not a git repo)"
    fi
}

master-oogway() {
    local sub="${1:-help}"
    case "$sub" in
        update)
            "$_MO_INSTALL_DIR/install.sh"
            ;;
        uninstall)
            "$_MO_INSTALL_DIR/install.sh" --uninstall
            ;;
        version|-v|--version)
            _mo_version
            ;;
        configure)
            command -v dragon-configure &>/dev/null \
                || { echo "master-oogway: dragon-configure not found — is the dragon theme loaded?" >&2; return 1; }
            dragon-configure "${@:2}"
            ;;
        edit)
            ${EDITOR:-vim} "${HOME}/.zshrc"
            ;;
        path)
            echo "$_MO_INSTALL_DIR"
            ;;
        diff-zshrc)
            local tool="${2:-}"
            local template="${_MO_INSTALL_DIR}/zshrc.master-oogway"
            local zshrc="${HOME}/.zshrc"
            [[ -f "$template" ]] || { echo "master-oogway: template not found at $template" >&2; return 1; }
            [[ -f "$zshrc" ]]    || { echo "master-oogway: $zshrc not found" >&2; return 1; }
            if diff -q "$template" "$zshrc" &>/dev/null; then
                echo "$zshrc matches the template — no diff."
                return 0
            fi
            if [[ -n "$tool" ]]; then
                # ${=tool} splits on whitespace so 'code --diff' works.
                ${=tool} "$template" "$zshrc"
            elif command -v git &>/dev/null && [[ -n "$(git config --get diff.tool 2>/dev/null)" ]]; then
                git difftool --no-index "$template" "$zshrc"
            else
                diff -u "$template" "$zshrc"
            fi
            ;;
        ssh-forwarding)
            local action="${2:-}"
            local ssh_config="${HOME}/.ssh/config"
            local marker_begin="# BEGIN master-oogway:sendenv"
            local marker_end="# END master-oogway:sendenv"
            case "$action" in
                setup)
                    if grep -qF "$marker_begin" "$ssh_config" 2>/dev/null; then
                        echo "master-oogway: SSH forwarding already configured in $ssh_config"
                        return 0
                    fi
                    mkdir -p "${HOME}/.ssh"
                    chmod 700 "${HOME}/.ssh"
                    printf '\n%s\nHost *\n    SendEnv DRAGON__*\n    HashKnownHosts no\n%s\n' \
                        "$marker_begin" "$marker_end" >> "$ssh_config"
                    chmod 600 "$ssh_config"
                    echo "master-oogway: Added SendEnv DRAGON__* to $ssh_config"
                    ;;
                remove)
                    if ! grep -qF "$marker_begin" "$ssh_config" 2>/dev/null; then
                        echo "master-oogway: SSH forwarding block not found in $ssh_config"
                        return 0
                    fi
                    sed -i "/# BEGIN master-oogway:sendenv/,/# END master-oogway:sendenv/d" "$ssh_config"
                    echo "master-oogway: Removed SendEnv DRAGON__* block from $ssh_config"
                    ;;
                *)
                    echo "Usage: master-oogway ssh-forwarding <setup|remove>" >&2
                    return 1
                    ;;
            esac
            ;;
        help|-h|--help)
            cat <<EOF
Usage: master-oogway <command> [args]

Commands:
  update               Pull latest master-oogway and re-run install.sh
  uninstall            Run install.sh --uninstall (interactive)
  version              Print the installed dragon version (date + commit)
  configure [args]     Open dragon-configure (forwards args, e.g. --pick, --preset short)
  edit                 Open ~/.zshrc in \$EDITOR
  diff-zshrc [tool]    Show diff between your ~/.zshrc and the current template.
                       [tool] overrides; otherwise uses git's diff.tool if set,
                       else \`diff -u\`.
  path                 Print the master-oogway install dir
  ssh-forwarding       Manage dragon theme SSH forwarding (SendEnv).
    setup              Add SendEnv DRAGON__* block to ~/.ssh/config
    remove             Remove SendEnv DRAGON__* block from ~/.ssh/config
  help                 Show this message

Install dir: $_MO_INSTALL_DIR
EOF
            ;;
        *)
            echo "master-oogway: unknown command '$sub' — see 'master-oogway help'" >&2
            return 1
            ;;
    esac
}
