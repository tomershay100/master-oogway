
_MO_INSTALL_DIR="${HOME}/.master-oogway"

# Internal: print the current dragon version from git metadata, with a graceful
# fallback when the install dir isn't a git repo (shouldn't happen in practice).
_mo_version() {
    if git -C "$_MO_INSTALL_DIR" rev-parse --git-dir &>/dev/null; then
        git -C "$_MO_INSTALL_DIR" log -1 \
            --format="dragon %cd-%h" --date=format:"%Y-%m-%d_%H%M%S"
    else
        echo "dragon (unknown — $_MO_INSTALL_DIR is not a git repo)"
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
            if diff -q "$zshrc" "$template" &>/dev/null; then
                echo "$zshrc matches the template — no diff."
                return 0
            fi
            if [[ -n "$tool" ]]; then
                # ${=tool} splits on whitespace so 'code --diff' works.
                ${=tool} "$zshrc" "$template"
            elif command -v git &>/dev/null && [[ -n "$(git config --get diff.tool 2>/dev/null)" ]]; then
                git difftool --no-index "$zshrc" "$template"
            else
                diff -u "$zshrc" "$template"
            fi
            ;;
        help|-h|--help)
            cat <<EOF
Usage: master-oogway <command> [args]

Commands:
  update               Pull latest master-oogway and re-run install.sh
  uninstall            Run install.sh --uninstall (interactive)
  version              Print the installed dragon version (date + commit)
  configure [args]     Open dragon-configure (forwards args, e.g. --preset short)
  edit                 Open ~/.zshrc in \$EDITOR
  diff-zshrc [tool]    Show diff between your ~/.zshrc and the current template.
                       [tool] overrides; otherwise uses git's diff.tool if set,
                       else \`diff -u\`.
  path                 Print the master-oogway install dir
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
