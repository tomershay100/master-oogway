#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# install.sh - appa-fino zsh environment installer
#
# Three modes (auto-detected):
#   curl pipe   curl -fsSL <url>/install.sh | bash
#               Clones the repo to ~/.appa-fino/, then re-execs from there.
#
#   update      ~/.appa-fino/install.sh
#               git pull + submodule update, then re-applies dotfiles.
#
#   dev         shared/shell/install.sh  (inside the dotfiles repo)
#               Symlinks shared/shell/ → ~/.appa-fino/, then applies dotfiles.
# ------------------------------------------------------------------------------
set -Eeuo pipefail

readonly REPO_URL="https://github.com/tomershay100/appa-fino.git"
readonly INSTALL_DIR="${HOME}/.appa-fino"
readonly CONF_DIR="${HOME}/.config/appa-fino"
readonly STATE_FILE="${CONF_DIR}/state"
readonly ZSHRC="${HOME}/.zshrc"

# ── Colors & logging ───────────────────────────────────────────────────────────

if [[ -t 1 ]] && [[ "${NO_COLOR:-}" == "" ]] && [[ "${TERM:-}" != "dumb" ]]; then
    COLOR_RESET='\033[0m' COLOR_BOLD='\033[1m'
    COLOR_GREEN='\033[0;32m' COLOR_YELLOW='\033[1;33m' COLOR_RED='\033[0;31m' COLOR_CYAN='\033[0;36m' COLOR_MAGENTA='\033[0;35m'
else
    COLOR_RESET='' COLOR_BOLD='' COLOR_GREEN='' COLOR_YELLOW='' COLOR_RED='' COLOR_CYAN='' COLOR_MAGENTA=''
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

# ── Mode: curl pipe ────────────────────────────────────────────────────────────
# Bootstrap only: clone (or pull) the repo, then re-exec the real install.sh.

if _running_via_pipe; then
    require_cmd git
    if [[ -d "${INSTALL_DIR}/.git" ]]; then
        info "Updating ${INSTALL_DIR}..."
        git -C "${INSTALL_DIR}" pull --ff-only || die "git pull failed — resolve conflicts or re-clone"
        git -C "${INSTALL_DIR}" submodule update --init --recursive
    else
        [[ -e "${INSTALL_DIR}" ]] && die "${INSTALL_DIR} exists but is not a git repo. Remove it and retry."
        info "Cloning appa-fino into ${INSTALL_DIR}..."
        git clone --recurse-submodules "${REPO_URL}" "${INSTALL_DIR}"
    fi
    exec bash "${INSTALL_DIR}/install.sh"
fi

# ── Mode: update (running from ~/.appa-fino/install.sh) ───────────────────────

if _running_from_install_dir; then
    info "Updating ${INSTALL_DIR}..."
    git -C "${INSTALL_DIR}" pull --ff-only || die "git pull failed — resolve conflicts or re-clone"
    git -C "${INSTALL_DIR}" submodule update --init --recursive
    success "Repository up-to-date"
fi

# ── Mode: dev (running from inside the dotfiles repo) ─────────────────────────
# Symlink shared/shell/ → ~/.appa-fino/ so edits to the repo are live.

if ! _running_from_install_dir; then
    local_dir="$(_script_dir)"
    if [[ -L "${INSTALL_DIR}" && "$(readlink "${INSTALL_DIR}")" == "${local_dir}" ]]; then
        success "${INSTALL_DIR} already linked to this repo"
    elif [[ -L "${INSTALL_DIR}" ]]; then
        warn "${INSTALL_DIR} points elsewhere: $(readlink "${INSTALL_DIR}")"
        if confirm "Re-link to ${local_dir}?"; then
            ln -sfn "${local_dir}" "${INSTALL_DIR}"
            success "Re-linked ${INSTALL_DIR} → ${local_dir}"
        fi
    elif [[ -e "${INSTALL_DIR}" ]]; then
        die "${INSTALL_DIR} exists and is not a symlink. Remove it and re-run."
    else
        ln -s "${local_dir}" "${INSTALL_DIR}"
        success "Linked ${INSTALL_DIR} → ${local_dir}"
    fi

    # In dev mode, plugin submodules live in the dotfiles repo.
    _init_plugins() {
        local plugins_dir="${INSTALL_DIR}/zsh-custom.d/plugins"
        local -a missing=()
        for plugin in gitstatus you-should-use zsh-autosuggestions zsh-syntax-highlighting; do
            local plugin_dir="${plugins_dir}/${plugin}"
            if [[ ! -e "${plugin_dir}/.git" ]]; then
                [[ -d "${plugin_dir}" ]] && rm -rf "${plugin_dir}"
                missing+=("shared/shell/zsh-custom.d/plugins/${plugin}")
            fi
        done
        if [[ ${#missing[@]} -gt 0 ]]; then
            info "Initializing missing plugin submodules: ${missing[*]}"
            local repo_root
            repo_root="$(git -C "${local_dir}" rev-parse --show-toplevel)"
            git -C "${repo_root}" submodule update --init --recursive "${missing[@]}"
        else
            success "Plugin submodules already initialized"
        fi
    }
    _init_plugins
fi

# ── Pre-flight ─────────────────────────────────────────────────────────────────

require_cmd zsh
require_cmd git

if [[ ! -f "${HOME}/.oh-my-zsh/oh-my-zsh.sh" ]]; then
    die "oh-my-zsh not found. Install first:\n  sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
fi

command -v fzf    &>/dev/null || todo_item "Install fzf for fuzzy history search: sudo apt install fzf"
command -v meld   &>/dev/null || todo_item "Install meld for git difftool: sudo apt install meld"
command -v direnv &>/dev/null || todo_item "Install direnv for per-directory envs: sudo apt install direnv"
if ! command -v eza &>/dev/null && ! command -v exa &>/dev/null; then
    todo_item "Install eza (Ubuntu) or exa (Raspberry Pi) for enhanced ls: sudo apt install eza"
fi
if ! command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    todo_item "Install bat for syntax-highlighted cat/less: sudo apt install bat"
fi

# ── .zshrc: first install replaces; subsequent runs leave it alone ─────────────

_install_zshrc() {
    if [[ -f "${ZSHRC}" ]]; then
        local backup="${ZSHRC}.pre-appa-fino"
        cp "${ZSHRC}" "${backup}"
        info "Backed up ${ZSHRC} → ${backup}"
    fi
    copy_file "${INSTALL_DIR}/zshrc.template" "${ZSHRC}"
}

if [[ ! -f "${ZSHRC}" ]]; then
    _install_zshrc
elif grep -q '\.appa-fino' "${ZSHRC}" 2>/dev/null; then
    success "${ZSHRC} already configured for appa-fino — not overwritten"
else
    _install_zshrc
fi

# ── .zshenv ────────────────────────────────────────────────────────────────────

copy_file "${INSTALL_DIR}/.zshenv" "${HOME}/.zshenv"

# ── .gitconfig ─────────────────────────────────────────────────────────────────

_install_gitconfig() {
    local git_name git_email
    if [[ -f "${HOME}/.gitconfig" ]]; then
        git_name=$(git config --file "${HOME}/.gitconfig" user.name  2>/dev/null || true)
        git_email=$(git config --file "${HOME}/.gitconfig" user.email 2>/dev/null || true)
    fi

    if [[ -z "$git_name" ]]; then
        _ask "Git user name: "
        read -r git_name < /dev/tty
    fi
    if [[ -z "$git_email" ]]; then
        _ask "Git email: "
        read -r git_email < /dev/tty
    fi

    copy_file "${INSTALL_DIR}/gitconfig" "${HOME}/.gitconfig"

    git config --file "${HOME}/.gitconfig" user.name  "$git_name"
    git config --file "${HOME}/.gitconfig" user.email "$git_email"
    success "Git identity: ${git_name} <${git_email}>"
}

_install_gitconfig

# ── ~/.ssh/config — SendEnv for appa-fino theme forwarding ────────────────────

_install_ssh_sendenv() {
    local ssh_config="${HOME}/.ssh/config"
    local send_line="    SendEnv APPA_FINO__*"

    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"

    if [[ ! -f "$ssh_config" ]]; then
        printf 'Host *\n%s\n' "$send_line" >> "$ssh_config"
        chmod 600 "$ssh_config"
        success "Created ~/.ssh/config with SendEnv APPA_FINO__*"
        return
    fi

    # Already present anywhere in the file — nothing to do.
    if grep -qF "SendEnv APPA_FINO__*" "$ssh_config"; then
        success "SendEnv APPA_FINO__* already in ~/.ssh/config"
        return
    fi

    # Insert SendEnv on the line after the first 'Host *' stanza header.
    if grep -qE '^Host \*[[:space:]]*$' "$ssh_config"; then
        sed -i "/^Host \*[[:space:]]*$/a\\${send_line}" "$ssh_config"
        success "Added SendEnv APPA_FINO__* to existing Host * block in ~/.ssh/config"
    else
        # No Host * block — append one.
        printf '\nHost *\n%s\n' "$send_line" >> "$ssh_config"
        success "Appended Host * block with SendEnv APPA_FINO__* to ~/.ssh/config"
    fi
}

_install_ssh_sendenv

# ── /etc/ssh/sshd_config — AcceptEnv for appa-fino theme forwarding ───────────

_install_sshd_acceptenv() {
    local sshd_config="/etc/ssh/sshd_config"
    local accept_line="AcceptEnv APPA_FINO__*"

    if [[ ! -f "$sshd_config" ]]; then
        info "sshd not found — skipping AcceptEnv (not a server or sshd not installed)"
        return
    fi

    if grep -qF "$accept_line" "$sshd_config"; then
        success "AcceptEnv APPA_FINO__* already in /etc/ssh/sshd_config"
        return
    fi

    info "Adding AcceptEnv APPA_FINO__* to /etc/ssh/sshd_config (sudo required)..."
    printf '%s\n' "$accept_line" | sudo tee -a "$sshd_config" >/dev/null
    sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd 2>/dev/null || true
    success "Added AcceptEnv APPA_FINO__* and reloaded sshd"
}

_install_sshd_acceptenv

# ── appa-fino theme: check for new variables ───────────────────────────────────

_check_theme_vars() {
    local theme_file="${INSTALL_DIR}/zsh-custom.d/themes/appa-fino.zsh"
    local current_hash
    current_hash=$(grep -o 'APPA_FINO__[A-Z_]*' "${theme_file}" 2>/dev/null \
        | sort -u | md5sum | cut -d' ' -f1)

    if [[ ! -f "${STATE_FILE}" ]]; then
        todo_item "Configure your prompt: open a new terminal and run 'appa-fino-configure'"
        return
    fi

    local stored_hash
    stored_hash=$(grep '^vars_hash=' "${STATE_FILE}" 2>/dev/null | cut -d= -f2)
    if [[ "${current_hash}" != "${stored_hash}" ]]; then
        todo_item "New appa-fino theme options available: run 'appa-fino-configure --new-only'"
    else
        success "appa-fino theme already configured"
    fi
}

_check_theme_vars

# ── Done ───────────────────────────────────────────────────────────────────────

print_todos
success "appa-fino installation complete. Open a new terminal to apply changes."
