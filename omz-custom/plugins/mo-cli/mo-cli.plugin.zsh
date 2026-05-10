# Provides: master-oogway CLI — update / uninstall / version / doctor / configure / edit / path / help.

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

# Internal: report missing optional tools and which plugins they affect.
_mo_doctor() {
    local missing=0
    _mo_check() {
        if command -v "$1" &>/dev/null; then
            print -P "  %F{green}✓%f $1 — $2"
        else
            print -P "  %F{red}✗%f $1 — $2 (sudo apt install $3)"
            missing=$((missing + 1))
        fi
    }
    print -P "%BMust-have:%b"
    _mo_check zsh        "the shell itself"               zsh
    _mo_check git        "for updates and gitstatus"      git
    _mo_check curl       "for natip + the OMZ installer"  curl
    print ""
    print -P "%BNice-to-have:%b"
    _mo_check fzf        "fuzzy pickers (Ctrl+R, fbranch, fkill, fcd, ...)" fzf
    _mo_check bat        "syntax-highlighted cat / less / man"              bat
    _mo_check eza        "enhanced ls / tree"                               eza
    _mo_check fd         "faster fzf file picker (Ctrl+T)"                  fd-find
    _mo_check rg         "the 'frg' fuzzy ripgrep picker"                   ripgrep
    _mo_check direnv     "auto-load .envrc per directory"                   direnv
    _mo_check meld       "git difftool / mergetool GUI"                     meld
    _mo_check lsof       "the 'port' command"                               lsof
    _mo_check zoxide     "smarter cd ('z' command)"                         zoxide
    print ""
    if (( missing == 0 )); then
        print -P "%F{green}All checked tools are installed.%f"
    else
        print -P "%F{yellow}${missing} optional tool(s) missing — install hints above.%f"
    fi
    unset -f _mo_check
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
        doctor)
            _mo_doctor
            ;;
        configure)
            dragon-configure "${@:2}"
            ;;
        edit)
            ${EDITOR:-vim} "${HOME}/.zshrc"
            ;;
        path)
            echo "$_MO_INSTALL_DIR"
            ;;
        help|-h|--help)
            cat <<EOF
Usage: master-oogway <command> [args]

Commands:
  update              Pull latest master-oogway and re-run install.sh
  uninstall           Run install.sh --uninstall (interactive)
  version             Print the installed dragon version (date + commit)
  doctor              Check which optional tools are installed
  configure [args]    Open dragon-configure (forwards args, e.g. --preset short)
  edit                Open ~/.zshrc in \$EDITOR
  path                Print the master-oogway install dir
  help                Show this message

Install dir: $_MO_INSTALL_DIR
EOF
            ;;
        *)
            echo "master-oogway: unknown command '$sub' — see 'master-oogway help'" >&2
            return 1
            ;;
    esac
}
