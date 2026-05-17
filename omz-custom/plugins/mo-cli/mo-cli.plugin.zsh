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
    # _mo_check <name|alt|...> <desc> <apt-pkg>
    # Accepts pipe-separated alternative binary names; succeeds if any is on
    # PATH. The display shows whichever was found (so the user sees the
    # actual binary they have, e.g. 'batcat' on Ubuntu, not the canonical
    # 'bat'). On miss, shows the primary (first) name.
    _mo_check() {
        local cmds="$1" desc="$2" pkg="$3"
        local found="" c
        for c in ${(s:|:)cmds}; do
            if command -v "$c" &>/dev/null; then
                found="$c"
                break
            fi
        done
        if [[ -n "$found" ]]; then
            print -P "  %F{green}✓%f $found — $desc"
        else
            print -P "  %F{red}✗%f ${cmds%%|*} — $desc (sudo apt install $pkg)"
            missing=$((missing + 1))
        fi
    }
    print -P "%BMust-have:%b"
    _mo_check zsh         "the shell itself"               zsh
    _mo_check git         "for updates and gitstatus"      git
    _mo_check curl        "for natip + the OMZ installer"  curl
    print ""
    print -P "%BNice-to-have:%b"
    _mo_check fzf         "fuzzy pickers (Ctrl+R, fbranch, fkill, fcd, ...)" fzf
    # Ubuntu's apt installs 'bat' as 'batcat' and 'fd-find' as 'fdfind' to
    # avoid name collisions with other packages — accept both.
    _mo_check "bat|batcat" "syntax-highlighted cat / less / man"             bat
    _mo_check eza         "enhanced ls / tree"                               eza
    _mo_check "fd|fdfind" "faster fzf file picker (Ctrl+T)"                  fd-find
    _mo_check rg          "the 'frg' fuzzy ripgrep picker"                   ripgrep
    _mo_check direnv      "auto-load .envrc per directory"                   direnv
    _mo_check meld        "git difftool / mergetool GUI"                     meld
    _mo_check lsof        "the 'port' command"                               lsof
    _mo_check zoxide      "smarter cd ('z' command)"                         zoxide
    _mo_check nmap        "LAN host discovery for mo-lan-ssh"                nmap
    _mo_check dig         "DNS lookups for mo-lan-ssh (AXFR + reverse DNS)"  dnsutils
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
