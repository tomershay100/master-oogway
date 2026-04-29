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
    _C='\033[0m' _BOLD='\033[1m'
    _GREEN='\033[0;32m' _YELLOW='\033[1;33m' _RED='\033[0;31m' _CYAN='\033[0;36m' _MAGENTA='\033[0;35m'
else
    _C='' _BOLD='' _GREEN='' _YELLOW='' _RED='' _CYAN='' _MAGENTA=''
fi

success() { echo -e "${_GREEN}[OK ]${_C} $*"; }
info()    { echo -e "${_CYAN}[INF]${_C} $*"; }
warn()    { echo -e "${_YELLOW}[WRN]${_C} $*" >&2; }
die()     { echo -e "${_RED}[ERR]${_C} $*" >&2; exit 1; }
_ask()    { echo -en "${_MAGENTA}[ASK]${_C} $*" > /dev/tty; }

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
    echo -e "${_YELLOW}┌─────────────────────────────────────────────────────┐${_C}"
    echo -e "${_YELLOW}│  Manual steps required after install                │${_C}"
    echo -e "${_YELLOW}└─────────────────────────────────────────────────────┘${_C}"
    local i=1
    for item in "${_TODO_ITEMS[@]}"; do
        echo -e "${_YELLOW}  ${i}. ${item}${_C}"
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
    cd "$(dirname "${_SCRIPT_SOURCE}")" 2>/dev/null && pwd
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
        git -C "${INSTALL_DIR}" pull --ff-only
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
    git -C "${INSTALL_DIR}" pull --ff-only
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
            git -C "${local_dir}/../.." submodule update --init --recursive "${missing[@]}"
        else
            success "Plugin submodules already initialized"
        fi
    }
    _init_plugins
fi

# ── Pre-flight ─────────────────────────────────────────────────────────────────

require_cmd zsh
require_cmd git

if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
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

copy_file "${INSTALL_DIR}/.gitconfig" "${HOME}/.gitconfig"

# ── Git identity ───────────────────────────────────────────────────────────────

_setup_git_identity() {
    if [[ -f "${HOME}/.gitconfig.local" ]]; then
        success "${HOME}/.gitconfig.local already exists — skipping"
        return
    fi
    warn "${HOME}/.gitconfig.local not found — git user identity is not configured."
    if confirm "Enter your git name and email now?"; then
        local git_name git_email
        _ask "git user.name:  "; read -r git_name  < /dev/tty
        _ask "git user.email: "; read -r git_email < /dev/tty
        mkdir -p "$(dirname "${HOME}/.gitconfig.local")"
        cat > "${HOME}/.gitconfig.local" <<EOF
[user]
	name  = ${git_name}
	email = ${git_email}
EOF
        success "Created ${HOME}/.gitconfig.local"
    else
        warn "Skipping. Create ${HOME}/.gitconfig.local manually with [user] name and email."
    fi
}

_setup_git_identity

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
