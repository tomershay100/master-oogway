#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# install.sh - dragon zsh environment installer (bundle: master-oogway)
#
# Three modes (auto-detected):
#   curl pipe   curl -fsSL <url>/install.sh | bash
#               Clones the repo to ~/.master-oogway/, then re-execs from there.
#
#   update      ~/.master-oogway/install.sh
#               git pull + submodule update, then re-applies dotfiles.
#
#   dev         shared/master-oogway/install.sh  (inside the dotfiles repo)
#               Symlinks shared/master-oogway/ → ~/.master-oogway/, then applies dotfiles.
# ------------------------------------------------------------------------------
set -Eeuo pipefail

readonly REPO_URL="https://github.com/tomershay100/master-oogway.git"
readonly INSTALL_DIR="${HOME}/.master-oogway"
readonly CONF_DIR="${HOME}/.config/master-oogway"
readonly STATE_FILE="${CONF_DIR}/state"
readonly ZSHRC="${HOME}/.zshrc"

# ── Colors & logging ───────────────────────────────────────────────────────────

if [[ -t 1 ]] && [[ "${NO_COLOR:-}" == "" ]] && [[ "${TERM:-}" != "dumb" ]]; then
    COLOR_RESET='\033[0m'
    COLOR_GREEN='\033[0;32m' COLOR_YELLOW='\033[1;33m' COLOR_RED='\033[0;31m' COLOR_CYAN='\033[0;36m' COLOR_MAGENTA='\033[0;35m'
else
    COLOR_RESET='' COLOR_GREEN='' COLOR_YELLOW='' COLOR_RED='' COLOR_CYAN='' COLOR_MAGENTA=''
fi

success() { echo -e "${COLOR_GREEN}[OK ]${COLOR_RESET} $*"; }
info()    { echo -e "${COLOR_CYAN}[INF]${COLOR_RESET} $*"; }
warn()    { echo -e "${COLOR_YELLOW}[WRN]${COLOR_RESET} $*" >&2; }
die()     { echo -e "${COLOR_RED}[ERR]${COLOR_RESET} $*" >&2; exit 1; }
_ask()    { echo -en "${COLOR_MAGENTA}[ASK]${COLOR_RESET} $*" > /dev/tty; }

# ── Error handling ─────────────────────────────────────────────────────────────

_on_error() {
    local exit_code=$?
    trap - ERR
    die "${BASH_SOURCE[1]:-unknown}: command failed (exit ${exit_code}) at line $1: ${BASH_COMMAND}"
}
trap '_on_error $LINENO' ERR

_cleanup() { local ec=$?; trap - EXIT INT TERM; exit "$ec"; }
trap _cleanup EXIT INT TERM

# ── Helpers ────────────────────────────────────────────────────────────────────

require_cmd() {
    local cmd="$1" pkg="${2:-$1}"
    command -v "$cmd" &>/dev/null || die "'${cmd}' not found. Install: sudo apt install ${pkg}"
}

# Try to install a package via apt-get if it's missing. Returns 0 if the command
# is now on PATH (either was already, or installed successfully), 1 otherwise.
# Caller decides whether to die() or continue.
apt_install() {
    local cmd="$1" pkg="${2:-$1}"
    command -v "$cmd" &>/dev/null && return 0
    if ! command -v apt-get &>/dev/null; then
        warn "'${cmd}' not installed and apt-get is unavailable — install '${pkg}' manually"
        return 1
    fi
    info "'${cmd}' not installed — running: sudo apt-get install -y ${pkg}"
    if sudo apt-get install -y "$pkg" >/dev/null 2>&1; then
        success "Installed ${pkg}"
        return 0
    fi
    warn "Failed to install '${pkg}' — try manually: sudo apt install ${pkg}"
    return 1
}

copy_file() {
    local src="$1" dst="$2"
    [[ -e "$src" ]] || die "Source does not exist: ${src}"
    mkdir -p "$(dirname "$dst")"
    if [[ -L "$dst" ]]; then
        rm "$dst"
    elif [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
        success "already up-to-date: ${dst}"
        return 0
    fi
    cp "$src" "$dst"
    info "copied: ${src} → ${dst}"
}

confirm() {
    local prompt="$1" default="${2:-n}"
    if [[ ! -t 0 ]]; then
        [[ "$default" =~ ^[Yy] ]] && return 0 || return 1
    fi
    local suffix="[y/N]"
    [[ "$default" =~ ^[Yy] ]] && suffix="[Y/n]"
    stty sane < /dev/tty 2>/dev/null || true
    _ask "$prompt $suffix "
    local reply; read -r reply < /dev/tty
    [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

_TODO_ITEMS=()
todo_item()  { _TODO_ITEMS+=("$*"); }
print_todos() {
    [[ ${#_TODO_ITEMS[@]} -eq 0 ]] && return 0
    echo ""
    echo -e "${COLOR_YELLOW}┌─────────────────────────────────────────────────────┐${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}│  Manual steps required after install                │${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}└─────────────────────────────────────────────────────┘${COLOR_RESET}"
    local i=1
    for item in "${_TODO_ITEMS[@]}"; do
        echo -e "${COLOR_YELLOW}  ${i}. ${item}${COLOR_RESET}"
        (( i++ ))
    done
    echo ""
}

# ── Mode detection ─────────────────────────────────────────────────────────────

_SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"

_running_via_pipe() {
    [[ -z "${_SCRIPT_SOURCE}" || "${_SCRIPT_SOURCE}" == "bash" || "${_SCRIPT_SOURCE}" == "/dev/stdin" ]]
}

_script_dir() {
    local dir
    dir=$(cd "$(dirname "${_SCRIPT_SOURCE}")" 2>/dev/null && pwd)
    [[ -n "$dir" ]] || { echo "error: cannot resolve script directory" >&2; return 1; }
    echo "$dir"
}

_running_from_install_dir() {
    [[ "$(_script_dir)" == "${INSTALL_DIR}" ]]
}

_running_from_master_oogway_clone() {
    local dir; dir="$(_script_dir)" || return 1
    local remote
    remote=$(git -C "$dir" remote get-url origin 2>/dev/null) || return 1
    [[ "$remote" == *"master-oogway"* ]]
}

# ── Mode: curl pipe / bootstrap ────────────────────────────────────────────────
# Triggered when piped through bash, OR when the script is run from a directory
# that is not a master-oogway clone (e.g. a copied script, /tmp, a random path).
# Clones (or pulls) the repo, then re-execs the real install.sh from INSTALL_DIR.

if _running_via_pipe || { ! _running_from_install_dir && ! _running_from_master_oogway_clone; }; then
    _running_via_pipe || info "Script is not running from a master-oogway clone — bootstrapping..."
    apt_install git || die "Cannot proceed without git"
    if [[ -d "${INSTALL_DIR}/.git" ]]; then
        info "Updating ${INSTALL_DIR}..."
        git -C "${INSTALL_DIR}" pull --ff-only || die "git pull failed — resolve conflicts or re-clone"
        git -C "${INSTALL_DIR}" submodule update --init --recursive
    else
        [[ -e "${INSTALL_DIR}" ]] && die "${INSTALL_DIR} exists but is not a git repo. Remove it and retry."
        info "Cloning master-oogway into ${INSTALL_DIR}..."
        git clone --recurse-submodules "${REPO_URL}" "${INSTALL_DIR}"
    fi
    exec bash "${INSTALL_DIR}/install.sh"
fi

# ── Mode: update (running from ~/.master-oogway/install.sh) ──────────────────

if _running_from_install_dir; then
    info "Updating ${INSTALL_DIR}..."
    git -C "${INSTALL_DIR}" pull --ff-only || die "git pull failed — resolve conflicts or re-clone"
    git -C "${INSTALL_DIR}" submodule update --init --recursive
    success "Repository up-to-date"
fi

# ── Mode: dev (running from a master-oogway clone, not ~/.master-oogway) ───────
# Symlinks the local clone → ~/.master-oogway/ so edits are live immediately.

if _running_from_master_oogway_clone && ! _running_from_install_dir; then
    local_dir="$(_script_dir)"
    if [[ -L "${INSTALL_DIR}" && "$(readlink "${INSTALL_DIR}")" == "${local_dir}" ]]; then
        success "${INSTALL_DIR} already linked to this repo"
    elif [[ -L "${INSTALL_DIR}" ]]; then
        warn "${INSTALL_DIR} points elsewhere: $(readlink "${INSTALL_DIR}")"
        if confirm "Re-link to ${local_dir}?"; then
            ln -sfn "${local_dir}" "${INSTALL_DIR}"
            success "Re-linked ${INSTALL_DIR} → ${local_dir}"
        else
            die "Aborted — ${INSTALL_DIR} still points to $(readlink "${INSTALL_DIR}")"
        fi
    elif [[ -e "${INSTALL_DIR}" ]]; then
        die "${INSTALL_DIR} exists and is not a symlink. Remove it and re-run."
    else
        ln -s "${local_dir}" "${INSTALL_DIR}"
        success "Linked ${INSTALL_DIR} → ${local_dir}"
    fi

    _init_plugins() {
        local plugins_dir="${INSTALL_DIR}/omz-custom/plugins"
        local -a missing=()
        for plugin in gitstatus you-should-use zsh-autosuggestions zsh-syntax-highlighting; do
            local plugin_dir="${plugins_dir}/${plugin}"
            if [[ ! -e "${plugin_dir}/.git" ]]; then
                [[ -d "${plugin_dir}" ]] && rm -rf "${plugin_dir}"
                missing+=("${plugin}")
            fi
        done
        if [[ ${#missing[@]} -gt 0 ]]; then
            info "Initializing missing plugin submodules: ${missing[*]}"
            git -C "${local_dir}" submodule update --init --recursive
        else
            success "Plugin submodules already initialized"
        fi
    }
    _init_plugins
fi

# ── Version ────────────────────────────────────────────────────────────────────

_print_version() {
    local version
    version=$(git -C "${INSTALL_DIR}" log -1 --format="%cd-%h" --date=format:"%Y-%m-%d_%H%M%S" 2>/dev/null \
        || echo "unknown")
    echo "master-oogway ${version}"
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'EOF'
Usage: install.sh [--help | --version | --uninstall]

Modes (auto-detected from where you run the script):
  curl pipe   bash -c "$(curl -fsSL <url>/install.sh)"
              Clones the repo to ~/.master-oogway/ then re-execs from there.

  update      ~/.master-oogway/install.sh
              Runs git pull + submodule update, then re-applies dotfiles.

  dev         /path/to/local/clone/install.sh
              Symlinks ~/.master-oogway → local clone for live development.

Options:
  --help       Show this message and exit
  --version    Print the installed version (date + git hash) and exit
  --uninstall  Remove all master-oogway files, config, and dotfile changes
EOF
    exit 0
fi

if [[ "${1:-}" == "--version" || "${1:-}" == "-v" ]]; then
    _print_version
    exit 0
fi

# ── Uninstall ──────────────────────────────────────────────────────────────────

if [[ "${1:-}" == "--uninstall" ]]; then
    info "Uninstalling dragon (master-oogway)..."

    # .zshrc
    _uninstall_zshrc_backup="${ZSHRC}.pre-master-oogway"
    if [[ -f "$_uninstall_zshrc_backup" ]]; then
        cp "$_uninstall_zshrc_backup" "${ZSHRC}"
        rm -f "$_uninstall_zshrc_backup"
        success "Restored ${ZSHRC} from backup (backup removed)"
    elif grep -qF '# master-oogway:managed' "${ZSHRC}" 2>/dev/null; then
        rm -f "${ZSHRC}"
        warn "Removed managed ${ZSHRC} — no backup found. Recreate it manually."
    else
        success "${ZSHRC} not managed by master-oogway — left untouched"
    fi

    # .gitconfig
    _uninstall_gitconfig_backup="${HOME}/.gitconfig.pre-master-oogway"
    if [[ -f "$_uninstall_gitconfig_backup" ]]; then
        cp "$_uninstall_gitconfig_backup" "${HOME}/.gitconfig"
        rm -f "$_uninstall_gitconfig_backup"
        success "Restored ~/.gitconfig from backup (backup removed)"
    elif [[ -f "${HOME}/.gitconfig" ]]; then
        sed -i '/gitconfig\.master-oogway/d' "${HOME}/.gitconfig"
        sed -i '/^\[include\]$/{N;/^\[include\]\n[[:space:]]*$/d}' "${HOME}/.gitconfig"
        success "Removed bundle [include] from ~/.gitconfig"
    fi
    rm -f "${HOME}/.gitconfig.master-oogway"
    success "Removed ~/.gitconfig.master-oogway"

    # ~/.ssh/config — remove SendEnv DRAGON__* line
    _uninstall_ssh_config="${HOME}/.ssh/config"
    if grep -qF 'SendEnv DRAGON__*' "$_uninstall_ssh_config" 2>/dev/null; then
        sed -i '/SendEnv DRAGON__\*/d' "$_uninstall_ssh_config"
        success "Removed SendEnv DRAGON__* from ~/.ssh/config"
    else
        success "SendEnv DRAGON__* not in ~/.ssh/config — nothing to remove"
    fi

    # /etc/ssh/sshd_config — remove AcceptEnv DRAGON__* (needs sudo)
    _uninstall_sshd_config="/etc/ssh/sshd_config"
    if grep -qF 'AcceptEnv DRAGON__*' "$_uninstall_sshd_config" 2>/dev/null; then
        if confirm "Remove AcceptEnv DRAGON__* from /etc/ssh/sshd_config and reload sshd? (sudo required)"; then
            sudo sed -i '/AcceptEnv DRAGON__\*/d' "$_uninstall_sshd_config"
            sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd 2>/dev/null || true
            success "Removed AcceptEnv DRAGON__* and reloaded sshd"
        else
            warn "Skipped — remove manually: sudo sed -i '/AcceptEnv DRAGON__\\\*/d' /etc/ssh/sshd_config"
        fi
    else
        success "AcceptEnv DRAGON__* not in /etc/ssh/sshd_config — nothing to remove"
    fi

    # ~/.config/master-oogway — user conf dir (contains conf.zsh, state, drop-ins)
    if [[ -d "${CONF_DIR}" ]]; then
        if confirm "Remove ${CONF_DIR} (contains your dragon theme config)?"; then
            rm -rf "${CONF_DIR}"
            success "Removed ${CONF_DIR}"
        else
            warn "Skipped — ${CONF_DIR} left in place"
        fi
    else
        success "${CONF_DIR} not found — nothing to remove"
    fi

    # ~/.master-oogway — symlink (dev) or cloned repo (production)
    if [[ -L "${INSTALL_DIR}" ]]; then
        rm -f "${INSTALL_DIR}"
        success "Removed symlink ${INSTALL_DIR}"
    elif [[ -d "${INSTALL_DIR}" ]]; then
        if confirm "Remove ${INSTALL_DIR} (the cloned dragon repo)?"; then
            rm -rf "${INSTALL_DIR}"
            success "Removed ${INSTALL_DIR}"
        else
            warn "Skipped — ${INSTALL_DIR} left in place"
        fi
    else
        success "${INSTALL_DIR} not found — nothing to remove"
    fi

    # .zshenv / .editorconfig — not removed; may predate dragon or have been
    # edited by the user. Left in place with clear guidance for each.
    warn "${HOME}/.zshenv was NOT removed."
    warn "  master-oogway wrote EDITOR/VISUAL exports there. If you no longer need them,"
    warn "  remove or edit: ${HOME}/.zshenv"
    warn "${HOME}/.editorconfig was NOT removed."
    warn "  master-oogway wrote tab-indent / LF-ending conventions there."
    warn "  remove or edit: ${HOME}/.editorconfig"

    success "dragon uninstall complete. Open a new terminal to apply changes."
    exit 0
fi

# ── Pre-flight ─────────────────────────────────────────────────────────────────

[[ "$(uname)" == "Linux" ]] || die "dragon requires Linux (Ubuntu 24.04). macOS/BSD are not supported."

# Must-have packages — auto-installed via apt-get when missing. dragon cannot
# function without these.
apt_install zsh  || die "Cannot proceed without zsh"
apt_install git  || die "Cannot proceed without git"
apt_install curl || die "Cannot proceed without curl (needed by the oh-my-zsh installer)"

# oh-my-zsh — required, but not an apt package. Print the official one-liner
# and exit rather than running it ourselves (its installer is interactive and
# replaces the user's shell — better the user sees the source before running).
if [[ ! -f "${HOME}/.oh-my-zsh/oh-my-zsh.sh" ]]; then
    die "oh-my-zsh not found — please install it first, then re-run this script:

  sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
fi

# Nice-to-have packages — silently skipped at runtime when missing (each plugin
# guards its own dependency). Just remind the user via the post-install todo
# list so they know the option exists.
command -v fzf    &>/dev/null || todo_item "Install fzf for fuzzy history search: sudo apt install fzf"
command -v meld   &>/dev/null || todo_item "Install meld for git difftool: sudo apt install meld"
command -v direnv &>/dev/null || todo_item "Install direnv for per-directory envs: sudo apt install direnv"
command -v lsof   &>/dev/null || todo_item "Install lsof for the 'port' command: sudo apt install lsof"
command -v rg     &>/dev/null || todo_item "Install ripgrep for the 'frg' fuzzy ripgrep picker: sudo apt install ripgrep"
command -v fd     &>/dev/null || todo_item "Install fd for faster fzf file picker (Ctrl+T): sudo apt install fd-find"
if ! command -v eza &>/dev/null && ! command -v exa &>/dev/null; then
    todo_item "Install eza (Ubuntu) or exa (Raspberry Pi) for enhanced ls: sudo apt install eza"
fi
if ! command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    todo_item "Install bat for syntax-highlighted cat/less/man: sudo apt install bat"
fi

# ── .zshrc: first install replaces; subsequent runs leave it alone ─────────────

_install_zshrc() {
    if [[ -f "${ZSHRC}" ]]; then
        local backup="${ZSHRC}.pre-master-oogway"
        if [[ ! -f "${backup}" ]]; then
            cp "${ZSHRC}" "${backup}"
            info "Backed up ${ZSHRC} → ${backup}"
        else
            info "Backup already exists at ${backup} — not overwriting"
        fi
    fi
    copy_file "${INSTALL_DIR}/zshrc.master-oogway" "${ZSHRC}"
}

_check_zshrc_drift() {
    local template="${INSTALL_DIR}/zshrc.master-oogway"
    [[ -f "${template}" ]] || return
    if ! diff -q "${template}" "${ZSHRC}" &>/dev/null; then
        warn "Your ~/.zshrc differs from the current template."
        warn "New features may have been added. To review:"
        warn "  diff ${ZSHRC} ${template}"
        warn "Apply any changes you want manually — your file is never auto-overwritten."
    fi
}

if [[ ! -f "${ZSHRC}" ]]; then
    _install_zshrc
elif grep -qF '# master-oogway:managed' "${ZSHRC}" 2>/dev/null; then
    success "${ZSHRC} already managed by master-oogway — not overwritten"
    _check_zshrc_drift
elif grep -q '\.master-oogway' "${ZSHRC}" 2>/dev/null; then
    success "${ZSHRC} already configured for dragon — not overwritten"
    _check_zshrc_drift
else
    _install_zshrc
fi

# ── one-shot path migration for installs predating the omz-custom rename ──────
# The directory was renamed: master-oogway-omz-custom → omz-custom, and the
# theme code moved into themes/dragon/. Existing ~/.zshrc files still point at
# the old path — rewrite the ZSH_CUSTOM line in place so the shell keeps loading.
if [[ -f "${ZSHRC}" ]] && grep -qF 'master-oogway-omz-custom' "${ZSHRC}"; then
    sed -i 's|master-oogway-omz-custom|omz-custom|g' "${ZSHRC}"
    success "Migrated ZSH_CUSTOM path in ${ZSHRC} (master-oogway-omz-custom → omz-custom)"
fi

# ── .zshenv ────────────────────────────────────────────────────────────────────

copy_file "${INSTALL_DIR}/zshenv.master-oogway" "${HOME}/.zshenv"

# ── .editorconfig ──────────────────────────────────────────────────────────────
# Installed at ~/.editorconfig so the conventions apply globally — EditorConfig
# walks up from the file being edited and picks up the first match.

copy_file "${INSTALL_DIR}/editorconfig.master-oogway" "${HOME}/.editorconfig"

# ── .gitconfig ─────────────────────────────────────────────────────────────────
# ~/.gitconfig.master-oogway  — bundle-managed settings (always updated)
# ~/.gitconfig                — user-owned; created once, never overwritten
#                               contains [user] + [include] pointing to both files

readonly GITCONFIG="${HOME}/.gitconfig"
readonly GITCONFIG_BUNDLE="${HOME}/.gitconfig.master-oogway"

_install_gitconfig() {
    # Always update the bundle-managed file.
    copy_file "${INSTALL_DIR}/gitconfig.master-oogway" "${GITCONFIG_BUNDLE}"

    # Resolve git identity: prefer existing ~/.gitconfig, then ask.
    local git_name git_email
    git_name=$(git config --file "${GITCONFIG}" user.name  2>/dev/null || true)
    git_email=$(git config --file "${GITCONFIG}" user.email 2>/dev/null || true)

    if [[ -z "$git_name" ]]; then
        _ask "Git user name: "
        read -r git_name < /dev/tty
    fi
    if [[ -z "$git_email" ]]; then
        _ask "Git email: "
        read -r git_email < /dev/tty
    fi

    # If ~/.gitconfig already includes the bundle, leave it alone.
    if grep -qF 'gitconfig.master-oogway' "${GITCONFIG}" 2>/dev/null; then
        success "${GITCONFIG} already includes gitconfig.master-oogway — not overwritten"
    else
        # Migrate: back up existing file, write a fresh minimal one.
        if [[ -f "${GITCONFIG}" ]]; then
            local backup="${GITCONFIG}.pre-master-oogway"
            cp "${GITCONFIG}" "${backup}"
            info "Backed up ${GITCONFIG} → ${backup}"
            info "Review ${backup} and move any personal settings to ${GITCONFIG}"
        fi
        cat > "${GITCONFIG}" <<EOF
# Bundle defaults — your settings below override these.
[include]
	path = ~/.gitconfig.master-oogway

# Your identity and personal overrides go here (or below the include above).
[user]
	name = ${git_name}
	email = ${git_email}
EOF
        success "Created ${GITCONFIG} with identity and bundle include"
        return
    fi

    git config --file "${GITCONFIG}" user.name  "$git_name"
    git config --file "${GITCONFIG}" user.email "$git_email"
    success "Git identity: ${git_name} <${git_email}>"
}

_install_gitconfig

# ── ~/.ssh/config — SendEnv for dragon theme forwarding ───────────────────────

_install_ssh_sendenv() {
    local ssh_config="${HOME}/.ssh/config"
    local send_line="    SendEnv DRAGON__*"

    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"

    if [[ ! -f "$ssh_config" ]]; then
        printf 'Host *\n%s\n' "$send_line" >> "$ssh_config"
        chmod 600 "$ssh_config"
        success "Created ~/.ssh/config with SendEnv DRAGON__*"
        return
    fi

    # Already present anywhere in the file — nothing to do.
    if grep -qF "SendEnv DRAGON__*" "$ssh_config"; then
        success "SendEnv DRAGON__* already in ~/.ssh/config"
        return
    fi

    # Insert SendEnv on the line after the first 'Host *' stanza header.
    if grep -qE '^Host \*[[:space:]]*$' "$ssh_config"; then
        sed -i "/^Host \*[[:space:]]*$/a\\${send_line}" "$ssh_config"
        success "Added SendEnv DRAGON__* to existing Host * block in ~/.ssh/config"
    else
        # No Host * block — append one.
        printf '\nHost *\n%s\n' "$send_line" >> "$ssh_config"
        success "Appended Host * block with SendEnv DRAGON__* to ~/.ssh/config"
    fi
}

_install_ssh_sendenv

# ── /etc/ssh/sshd_config — AcceptEnv for dragon theme forwarding ──────────────

_install_sshd_acceptenv() {
    local sshd_config="/etc/ssh/sshd_config"
    local accept_line="AcceptEnv DRAGON__*"

    if [[ ! -f "$sshd_config" ]]; then
        info "sshd not found — skipping AcceptEnv (not a server or sshd not installed)"
        return
    fi

    if grep -qF "$accept_line" "$sshd_config"; then
        success "AcceptEnv DRAGON__* already in /etc/ssh/sshd_config"
        return
    fi

    info "SSH theme forwarding requires adding AcceptEnv DRAGON__* to /etc/ssh/sshd_config."
    if ! confirm "Modify /etc/ssh/sshd_config and reload sshd? (sudo required)"; then
        info "Skipped — run install.sh again to configure later, or add manually."
        return
    fi
    printf '%s\n' "$accept_line" | sudo tee -a "$sshd_config" >/dev/null
    sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd 2>/dev/null || true
    success "Added AcceptEnv DRAGON__* and reloaded sshd"
}

_install_sshd_acceptenv

# ── dragon theme: check for new variables ───────────────────────────────────

_check_theme_vars() {
    local themes_dir="${INSTALL_DIR}/omz-custom/themes/dragon"
    local current_hash
    current_hash=$(grep -roh 'DRAGON__[A-Z_]*' "${themes_dir}" 2>/dev/null \
        | sort -u | md5sum | cut -d' ' -f1)

    if [[ ! -f "${STATE_FILE}" ]]; then
        todo_item "Configure your prompt: open a new terminal and run 'dragon-configure'"
        return
    fi

    local stored_hash
    stored_hash=$(grep '^vars_hash=' "${STATE_FILE}" 2>/dev/null | cut -d= -f2)
    if [[ "${current_hash}" != "${stored_hash}" ]]; then
        todo_item "New dragon theme options available: run 'dragon-configure --new-only'"
    else
        success "dragon theme already configured"
    fi
}

_check_theme_vars

# ── User extension directories ─────────────────────────────────────────────────

_install_user_ext_dirs() {
    local pre_dir="${CONF_DIR}/custom-pre-zsh"
    local post_dir="${CONF_DIR}/custom-zsh"
    mkdir -p "$pre_dir" "$post_dir"
    [[ -f "${pre_dir}/README" ]] || \
        echo "# Drop *.zsh files here; sourced before plugins on shell startup." \
        > "${pre_dir}/README"
    [[ -f "${post_dir}/README" ]] || \
        echo "# Drop *.zsh files here; sourced after plugins on shell startup." \
        > "${post_dir}/README"
    success "User extension dirs ready: custom-pre-zsh/ and custom-zsh/ in ${CONF_DIR}"
}

_install_user_ext_dirs

# ── Done ───────────────────────────────────────────────────────────────────────

print_todos
success "dragon installation complete. Open a new terminal to apply changes."
