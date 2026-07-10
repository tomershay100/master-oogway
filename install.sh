#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# install.sh - dragon zsh environment installer (bundle: master-oogway)
# Run with --help for usage.
# ------------------------------------------------------------------------------
set -Eeuo pipefail

readonly REPO_URL="https://github.com/tomershay100/master-oogway.git"
readonly INSTALL_DIR="${HOME}/.master-oogway"
readonly CONF_DIR="${HOME}/.config/master-oogway"
readonly STATE_FILE="${CONF_DIR}/state"
readonly ZSHRC="${HOME}/.zshrc"
readonly ZSHRC_SNAPSHOT="${CONF_DIR}/zshrc.snapshot"
readonly GITCONFIG="${HOME}/.gitconfig"
readonly GITCONFIG_BUNDLE="${HOME}/.gitconfig.master-oogway"

# -- Colors & logging -----------------------------------------------------------

if [[ -t 1 ]] && [[ "${NO_COLOR:-}" == "" ]] && [[ "${TERM:-}" != "dumb" ]] && command -v tput &>/dev/null; then
	readonly COLOR_RESET="$(tput sgr0)"
	readonly COLOR_GREEN="$(tput setaf 2)" COLOR_YELLOW="$(tput bold)$(tput setaf 3)" COLOR_RED="$(tput setaf 1)" COLOR_CYAN="$(tput setaf 6)" COLOR_MAGENTA="$(tput setaf 5)"
else
	readonly COLOR_RESET='' COLOR_GREEN='' COLOR_YELLOW='' COLOR_RED='' COLOR_CYAN='' COLOR_MAGENTA=''
fi

success() { echo -e "${COLOR_GREEN}[OK ]${COLOR_RESET} $*"; }
info()    { echo -e "${COLOR_CYAN}[INF]${COLOR_RESET} $*"; }
warn()    { echo -e "${COLOR_YELLOW}[WRN]${COLOR_RESET} $*" >&2; }
die()     { echo -e "${COLOR_RED}[ERR]${COLOR_RESET} $*" >&2; exit 1; }
_ask()    { echo -en "${COLOR_MAGENTA}[ASK]${COLOR_RESET} $*" > /dev/tty; }

# -- Error handling -------------------------------------------------------------

_on_error()
{
	local exit_code=$?
	local func="${FUNCNAME[1]:-main}"
	local file="${BASH_SOURCE[1]:-unknown}"
	trap - ERR
	die "${file} (${func}): command failed (exit ${exit_code}) at line $1: ${BASH_COMMAND}"
}
trap '_on_error $LINENO' ERR


# -- Helpers --------------------------------------------------------------------

require_cmd()
{
	local cmd="$1" pkg="${2:-$1}"
	command -v "$cmd" &>/dev/null || die "'${cmd}' not found. Install: sudo apt install ${pkg}"
}

# -- Required package check -----------------------------------------------------
# Checks zsh, git, curl are present. If any are missing, prints one message
# listing all of them together and exits. No sudo, no auto-install.

_check_required_packages()
{
	local -a missing=()
	command -v zsh  &>/dev/null || missing+=(zsh)
	command -v git  &>/dev/null || missing+=(git)
	command -v curl &>/dev/null || missing+=(curl)

	[[ ${#missing[@]} -eq 0 ]] && return 0

	echo "" >&2
	echo -e "${COLOR_RED}┌─────────────────────────────────────────────────────┐${COLOR_RESET}" >&2
	echo -e "${COLOR_RED}│  Required packages missing                          │${COLOR_RESET}" >&2
	echo -e "${COLOR_RED}└─────────────────────────────────────────────────────┘${COLOR_RESET}" >&2
	echo "" >&2
	echo -e "  The following packages are required by master-oogway:" >&2
	echo "" >&2
	for pkg in "${missing[@]}"; do
		echo -e "    ${COLOR_RED}•${COLOR_RESET} ${pkg}" >&2
	done
	echo "" >&2
	echo -e "  Install them first, then re-run the installer:" >&2
	echo "" >&2
	echo -e "    ${COLOR_CYAN}sudo apt install ${missing[*]}${COLOR_RESET}" >&2
	echo "" >&2
	exit 1
}

# oh-my-zsh — required, but not an apt package, so checked separately. Checked
# up front (before any clone) so the user learns every prerequisite in one shot
# rather than after a full clone + re-exec. We print the official one-liner and
# exit rather than running it: its installer is interactive and replaces the
# user's shell — better the user sees the source before running.
_check_oh_my_zsh()
{
	[[ -f "${HOME}/.oh-my-zsh/oh-my-zsh.sh" ]] && return 0
	die "oh-my-zsh not found — please install it first, then re-run this script:

  sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
}

copy_file()
{
	local src="$1" dst="$2"
	[[ -e "$src" ]] || die "Source does not exist: ${src}"
	mkdir -p "$(dirname "$dst")"
	if [[ -L "$dst" ]]; then
		rm "$dst"
	elif [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
		success "already up-to-date: ${dst}"
		return 0
	fi
	cp -p "$src" "$dst"
	info "copied: ${src} → ${dst}"
}

# Find the most recent backup created by this installer for $1 (the base path
# without timestamp suffix, e.g. ~/.zshrc.pre-master-oogway). Echoes the
# resolved path, or nothing if no backup exists.
#
# Why both forms: since 2026-05-17 _install_zshrc writes timestamped backups
# (so a re-install doesn't clobber an existing one). Older installs left a
# single .pre-master-oogway file with no timestamp. Restoring needs to find
# either — newest timestamped wins; legacy bare name is the fallback.
# Back up $1 to $1.pre-master-oogway.<timestamp> if it exists.
# Echoes the backup path, or nothing if the source didn't exist.
_mo_backup()
{
	local src="$1"
	[[ -f "$src" ]] || return 0
	local backup="${src}.pre-master-oogway.$(date +%Y%m%d_%H%M%S)"
	cp "$src" "$backup"
	info "Backed up ${src} → ${backup}" >&2
	echo "$backup"
}

_find_backup() {
	local base="$1"
	# nullglob makes a no-match expand to an empty array instead of the
	# literal pattern. Save + restore so toggling here can't surprise the
	# caller. Pure bash + [[ -nt ]] avoids ls-parsing (shellcheck SC2012).
	local _had_nullglob
	shopt -q nullglob && _had_nullglob=true || _had_nullglob=false
	shopt -s nullglob
	local -a backups=( "${base}".[0-9]* )
	$_had_nullglob || shopt -u nullglob

	local newest="" candidate
	for candidate in "${backups[@]}"; do
		[[ -f "$candidate" ]] || continue
		[[ -z "$newest" || "$candidate" -nt "$newest" ]] && newest="$candidate"
	done
	if [[ -n "$newest" ]]; then
		echo "$newest"
		return
	fi
	[[ -f "$base" ]] && echo "$base"
}

confirm()
{
	local prompt="$1" default="${2:-n}"
	# [[ -r /dev/tty ]] only checks permissions on the device node (mode 666),
	# which passes even without a controlling terminal — the later read would
	# then fail with ENXIO and abort the script under set -e. Actually opening
	# /dev/tty is the reliable test for headless contexts (cron, CI, setsid).
	if ! { : < /dev/tty; } 2>/dev/null; then
		[[ "$default" =~ ^[Yy] ]] && return 0 || return 1
	fi
	local suffix="[y/N]"
	[[ "$default" =~ ^[Yy] ]] && suffix="[Y/n]"
	stty sane < /dev/tty 2>/dev/null || true
	_ask "$prompt $suffix "
	local reply
	read -r reply < /dev/tty
	[[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

_TODO_ITEMS=()
todo_item()  { _TODO_ITEMS+=("$*"); }
print_todos()
{
	[[ ${#_TODO_ITEMS[@]} -eq 0 ]] && return 0
	echo ""
	echo -e "${COLOR_YELLOW}┌─────────────────────────────────────────────────────┐${COLOR_RESET}"
	echo -e "${COLOR_YELLOW}│  Manual steps required after install                │${COLOR_RESET}"
	echo -e "${COLOR_YELLOW}└─────────────────────────────────────────────────────┘${COLOR_RESET}"
	local i=1
	for item in "${_TODO_ITEMS[@]}"; do
		echo -e "${COLOR_YELLOW}  ${i}. ${item}${COLOR_RESET}"
		i=$(( i + 1 ))
	done
	echo ""
}

# -- Optional dependency report -------------------------------------------------
# _collect_missing_optionals: reads optional-deps.zsh from every plugin and
# populates three associative arrays (by nameref) in the caller's scope:
#   _mo_missing_cmds[plugin]  = "cmd1 cmd2 ..."
#   _mo_descriptions[cmd]     = human-readable description
#   _mo_apt_pkgs[cmd]         = apt package name
# Returns 1 (no output) when nothing is missing.

_collect_missing_optionals()
{
	local plugins_dir="${INSTALL_DIR}/omz-custom/plugins"

	local plugin_dir dep_file plugin_name raw_deps raw_apt cmd desc pkg
	for dep_file in "${plugins_dir}"/mo-*/optional-deps.zsh; do
		[[ -f "$dep_file" ]] || continue
		plugin_dir="${dep_file%/optional-deps.zsh}"
		plugin_name="${plugin_dir##*/}"

		raw_deps=$(zsh -c '
			source "$1"
			for k in "${(@k)MO_OPTIONAL_DEPS}"; do
				printf "%s\t%s\n" "$k" "${MO_OPTIONAL_DEPS[$k]}"
			done
		' -- "$dep_file" 2>/dev/null) || continue

		raw_apt=$(zsh -c '
			source "$1"
			for k in "${(@k)MO_OPTIONAL_APT}"; do
				printf "%s\t%s\n" "$k" "${MO_OPTIONAL_APT[$k]}"
			done
		' -- "$dep_file" 2>/dev/null) || continue

		while IFS=$'\t' read -r cmd desc; do
			[[ -n "$cmd" ]] || continue
			# key by plugin+cmd: the same command has a different description per plugin
			_mo_descriptions["${plugin_name}"$'\t'"${cmd}"]="$desc"
		done <<< "$raw_deps"

		while IFS=$'\t' read -r cmd pkg; do
			[[ -n "$cmd" ]] || continue
			_mo_apt_pkgs["$cmd"]="$pkg"
		done <<< "$raw_apt"

		local missing_for_plugin=""
		while IFS=$'\t' read -r cmd _; do
			[[ -n "$cmd" ]] || continue
			# command -v is PATH-only; daemons/tools in /usr/sbin are invisible to non-root on Debian
			{ command -v "$cmd" &>/dev/null || [[ -x "/usr/sbin/$cmd" ]] || [[ -x "/sbin/$cmd" ]]; } \
				&& continue
			case "$cmd" in
				fd)  command -v fdfind &>/dev/null && continue ;;
				bat) command -v batcat &>/dev/null && continue ;;
			esac
			missing_for_plugin="${missing_for_plugin} ${cmd}"
		done <<< "$raw_deps"

		missing_for_plugin="${missing_for_plugin# }"
		[[ -n "$missing_for_plugin" ]] && _mo_missing_cmds["$plugin_name"]="$missing_for_plugin"
	done

	[[ ${#_mo_missing_cmds[@]} -gt 0 ]]
}

# _report_optional_deps: prints the optional-package table and install hint.
# Call after _collect_missing_optionals has populated the three arrays.
# $1 = "block" → hard-exit after printing (fresh install without --no-recommended-packages)
#    = "warn"  → print only, no exit (update mode)

_report_optional_deps()
{
	local mode="${1:-warn}"

	echo ""
	echo -e "${COLOR_YELLOW}┌─────────────────────────────────────────────────────┐${COLOR_RESET}"
	echo -e "${COLOR_YELLOW}│  Recommended packages not installed                 │${COLOR_RESET}"
	echo -e "${COLOR_YELLOW}└─────────────────────────────────────────────────────┘${COLOR_RESET}"

	local all_missing_pkgs=()
	local plugin first cmd desc pkg; local -a cmds_for_plugin
	for plugin in "${!_mo_missing_cmds[@]}"; do
		first=true
		read -ra cmds_for_plugin <<< "${_mo_missing_cmds[$plugin]}"
		for cmd in "${cmds_for_plugin[@]}"; do
			desc="${_mo_descriptions["${plugin}"$'\t'"${cmd}"]:-$cmd}"
			pkg="${_mo_apt_pkgs[$cmd]:-$cmd}"
			if $first; then
				printf "  ${COLOR_YELLOW}%-20s${COLOR_RESET}  %-12s  %s\n" "$plugin" "$cmd" "$desc"
				first=false
			else
				printf "  %-20s  %-12s  %s\n" "" "$cmd" "$desc"
			fi
			all_missing_pkgs+=("$pkg")
		done
	done

	local unique_pkgs=()
	declare -A _seen_pkg=()
	for p in "${all_missing_pkgs[@]}"; do
		[[ -z "${_seen_pkg[$p]+set}" ]] || continue
		_seen_pkg["$p"]=1
		unique_pkgs+=("$p")
	done

	echo ""
	if [[ "$mode" == "block" ]]; then
		echo -e "  These packages are optional but recommended for the best experience."
		echo -e "  Install them alongside master-oogway:"
		echo ""
		echo -e "    ${COLOR_CYAN}sudo apt install ${unique_pkgs[*]}${COLOR_RESET}"
		echo ""
		echo -e "  Or skip them and install without the recommended packages:"
		echo ""
		if _running_via_pipe; then
			echo -e "    ${COLOR_CYAN}~/.master-oogway/install.sh --no-recommended-packages${COLOR_RESET}"
		else
			echo -e "    ${COLOR_CYAN}./install.sh --no-recommended-packages${COLOR_RESET}"
		fi
		echo ""
		exit 1
	else
		echo -e "  Install recommended packages for the best experience:"
		echo ""
		echo -e "    ${COLOR_CYAN}sudo apt install ${unique_pkgs[*]}${COLOR_RESET}"
		echo ""
	fi
}

# -- Mode detection -------------------------------------------------------------

_SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"

_running_via_pipe()
{
	case "${_SCRIPT_SOURCE}" in
		""|bash|/dev/stdin|/dev/fd/*|/proc/self/fd/*) return 0 ;;
	esac
	return 1
}

_script_dir()
{
	local dir
	dir=$(cd "$(dirname "${_SCRIPT_SOURCE}")" 2>/dev/null && pwd)
	[[ -n "$dir" ]] || { echo "error: cannot resolve script directory" >&2; return 1; }
	echo "$dir"
}

_running_from_install_dir()
{
	local real_install_dir
	real_install_dir=$(cd "${INSTALL_DIR}" 2>/dev/null && pwd -P) || return 1
	[[ "$(_script_dir)" == "${real_install_dir}" ]]
}

_running_from_master_oogway_clone()
{
	local dir; dir="$(_script_dir)" || return 1
	local remote
	remote=$(git -C "$dir" remote get-url origin 2>/dev/null) || return 1
	[[ "$remote" == *"master-oogway"* ]]
}

# -- Version --------------------------------------------------------------------

_print_version()
{
	local version
	version=$(git -C "${INSTALL_DIR}" log -1 --format="%cd-%h" --date=format:"%Y-%m-%d_%H%M%S" 2>/dev/null \
		|| echo "unknown")
	echo "master-oogway ${version}"
}

MO_FORCE=false
MO_UNINSTALL=false
MO_NO_RECOMMENDED=false

# The parse loop consumes "$@"; keep a copy so the bootstrap re-exec can
# forward the original flags to the re-exec'd install.sh.
MO_ORIG_ARGS=("$@")

while [[ $# -gt 0 ]]; do
	case "$1" in
		--help|-h)
			cat <<'EOF'
Usage: install.sh [--help | --version | --uninstall | --force | --no-recommended-packages]

Modes (auto-detected from where you run the script):
  curl pipe   bash -c "$(curl -fsSL <url>/install.sh)"
              Clones the repo to ~/.master-oogway/ then re-execs from there.

  update      ~/.master-oogway/install.sh
              Runs git pull + submodule update, then re-applies dotfiles.

  dev         /path/to/local/clone/install.sh
              Symlinks ~/.master-oogway → local clone for live development.

Options:
  --help                      Show this message and exit
  --version                   Print the installed version (date + git hash) and exit
  --uninstall                 Remove all master-oogway files, config, and dotfile changes
  --force, -f                 Overwrite ~/.zshrc even if it already exists
  --no-recommended-packages   Skip the recommended-packages check and install anyway
EOF
			exit 0
			;;
		--version|-v)
			_print_version
			exit 0
			;;
		--uninstall) MO_UNINSTALL=true ;;
		--force|-f)  MO_FORCE=true ;;
		--no-recommended-packages) MO_NO_RECOMMENDED=true ;;
		*) die "Unknown option: $1 (run with --help for usage)" ;;
	esac
	shift
done

# -- Mode: curl pipe / bootstrap ------------------------------------------------
# Triggered when piped through bash, OR when the script is run from a directory
# that is not a master-oogway clone (e.g. a copied script, /tmp, a random path).
# Clones (or pulls) the repo, then re-execs the real install.sh from INSTALL_DIR.

_git_out=""

if _running_via_pipe || { ! _running_from_install_dir && ! _running_from_master_oogway_clone; }; then
	_running_via_pipe || info "Script is not running from a master-oogway clone — bootstrapping..."
	_check_required_packages
	_check_oh_my_zsh
	_toplevel=$(git -C "${INSTALL_DIR}" rev-parse --show-toplevel 2>/dev/null || true)
	if [[ -n "${_toplevel}" && "${_toplevel}" == "$(cd "${INSTALL_DIR}" 2>/dev/null && pwd -P)" ]]; then
		info "Updating ${INSTALL_DIR}..."
		_git_out=$(git -C "${INSTALL_DIR}" pull --ff-only 2>&1) || die "git pull failed:\n${_git_out}"
		_git_out=$(git -C "${INSTALL_DIR}" submodule update --init --recursive 2>&1) \
			|| die "Submodule update failed:\n${_git_out}\n\nTo recover: rm -rf ${INSTALL_DIR} and re-run the install command."
	else
		[[ -e "${INSTALL_DIR}" ]] && die "${INSTALL_DIR} exists but is not a git repo. Remove it and retry."
		info "Cloning master-oogway into ${INSTALL_DIR}..."
		_git_out=$(git clone --recurse-submodules "${REPO_URL}" "${INSTALL_DIR}" 2>&1) \
			|| die "Clone failed:\n${_git_out}\n\nTo recover: rm -rf ${INSTALL_DIR} and re-run the install command."
	fi
	# Already pulled + submodule-updated above; tell the re-exec'd update-mode
	# to skip its redundant pull (avoids the double "Updating" + double fetch).
	MO_SKIP_PULL=1 exec bash "${INSTALL_DIR}/install.sh" "${MO_ORIG_ARGS[@]}"
fi

# -- Plugin submodule self-healing ----------------------------------------------
# git submodule update --init --recursive skips dirs that already exist on disk,
# even if their .git was deleted. This function pre-scans for that corruption and
# wipes broken dirs so git can re-clone them cleanly.

_init_plugins()
{
	local plugins_dir="${INSTALL_DIR}/omz-custom/plugins"
	local -a missing=()
	# Derive plugin names from .gitmodules so adding a submodule needs no edit here.
	local -a submodules=()
	while IFS= read -r line; do
		[[ "$line" =~ path[[:space:]]*=[[:space:]]*omz-custom/plugins/([^[:space:]]+) ]] \
			&& submodules+=("${BASH_REMATCH[1]}")
	done < "${INSTALL_DIR}/.gitmodules"
	for plugin in "${submodules[@]}"; do
		local plugin_dir="${plugins_dir}/${plugin}"
		if [[ ! -e "${plugin_dir}/.git" ]]; then
			[[ -d "${plugin_dir}" ]] && rm -rf "${plugin_dir}"
			missing+=("${plugin}")
		fi
	done
	[[ ${#missing[@]} -gt 0 ]] && info "Re-initializing wiped plugin submodules: ${missing[*]}"
	_git_out=$(git -C "${INSTALL_DIR}" submodule update --init --recursive 2>&1) \
		|| die "Submodule update failed:\n${_git_out}\n\nTo recover: rm -rf ${INSTALL_DIR} and re-run the install command."
	success "Plugin submodules up-to-date"
}

# -- zcompile first-party zsh files --------------------------------------------
# Produces .zwc bytecode alongside each source file. zsh loads bytecode when it
# exists AND is newer than the source — older .zwc is silently ignored, so stale
# bytecode is never a correctness risk. Re-running install.sh after editing
# source files brings bytecode back up-to-date.
#
# Excluded on purpose:
#   presets/*.conf.zsh    — parsed as plain text by _dragon_load_current_conf_from
#   optional-deps.zsh     — read only by bash install.sh, not sourced at startup
#   _mo_lan_discover.zsh  — run as a standalone subprocess, not sourced
#   third-party submodule dirs (gitstatus, zsh-autosuggestions, etc.)

_zcompile_plugins()
{
	local omz="${INSTALL_DIR}/omz-custom"
	local compiled=0 skipped=0
	local f

	# Helper: compile $f if its .zwc is absent or older than the source.
	# Always returns 0 — compile failures are non-fatal (zsh falls back to source),
	# but errors are reported so broken files surface immediately.
	_zc() {
		local f="$1"
		[[ -f "$f" ]] || return 0
		if [[ -f "${f}.zwc" && "${f}.zwc" -nt "$f" ]]; then
			skipped=$(( skipped + 1 ))
			return 0
		fi
		if zsh -fc 'zcompile -- "$1"' zsh "$f"; then
			compiled=$(( compiled + 1 ))
		else
			warn "zcompile failed for $f"
		fi
		return 0
	}

	# lib/
	for f in "${omz}/lib"/*.zsh; do _zc "$f"; done

	# dragon theme — all top-level files, all configure/ parts, all parts/
	# Presets (*.conf.zsh) are intentionally skipped — parsed as plain text.
	# mo-* plugins are intentionally excluded: zsh bakes alias lookups into
	# bytecode at compile time, so compiled plugin functions would call the
	# system ls/cat/vim instead of the eza/bat/nvim aliases defined by earlier
	# override plugins. Keeping plugins as source preserves load-order semantics.
	for f in "${omz}/themes/dragon"/*.zsh \
			  "${omz}/themes/dragon/configure"/*.zsh \
			  "${omz}/themes/dragon/parts"/*.zsh; do
		_zc "$f"
	done

	success "zcompile: compiled ${compiled} file(s), ${skipped} already up-to-date"
}

# -- Mode: update (running from ~/.master-oogway/install.sh) ------------------

_MO_UPDATE_MODE=false
if _running_from_install_dir; then
	_MO_UPDATE_MODE=true
	if [[ "${MO_SKIP_PULL:-}" == "1" ]]; then
		# Bootstrap already pulled before re-exec; just heal submodules.
		_init_plugins
	else
		info "Updating ${INSTALL_DIR}..."
		_git_out=$(git -C "${INSTALL_DIR}" pull --ff-only 2>&1) || die "git pull failed:\n${_git_out}"
		_init_plugins
		success "Repository up-to-date"
	fi
fi

# -- Mode: dev (running from a master-oogway clone, not ~/.master-oogway) -------
# Symlinks the local clone → ~/.master-oogway/ so edits are live immediately.

if _running_from_master_oogway_clone && ! _running_from_install_dir; then
	_MO_DEV_DIR="$(_script_dir)"
	if [[ -L "${INSTALL_DIR}" && "$(realpath "${INSTALL_DIR}" 2>/dev/null)" == "$(realpath "${_MO_DEV_DIR}" 2>/dev/null)" ]]; then
		success "${INSTALL_DIR} already linked to this repo"
	elif [[ -L "${INSTALL_DIR}" ]]; then
		warn "${INSTALL_DIR} points elsewhere: $(readlink "${INSTALL_DIR}")"
		if confirm "Re-link to ${_MO_DEV_DIR}?"; then
			ln -sfn "${_MO_DEV_DIR}" "${INSTALL_DIR}"
			success "Re-linked ${INSTALL_DIR} → ${_MO_DEV_DIR}"
		else
			die "Aborted — ${INSTALL_DIR} still points to $(readlink "${INSTALL_DIR}")"
		fi
	elif [[ -e "${INSTALL_DIR}" ]]; then
		die "${INSTALL_DIR} exists and is not a symlink. Remove it and re-run."
	else
		ln -s "${_MO_DEV_DIR}" "${INSTALL_DIR}"
		success "Linked ${INSTALL_DIR} → ${_MO_DEV_DIR}"
	fi
	_init_plugins
fi

# -- Uninstall ------------------------------------------------------------------

if [[ "$MO_UNINSTALL" == true ]]; then
	info "Uninstalling dragon (master-oogway)..."

	# .zshrc
	_uninstall_zshrc_backup=$(_find_backup "${ZSHRC}.pre-master-oogway")
	if [[ -n "$_uninstall_zshrc_backup" ]]; then
		cp "$_uninstall_zshrc_backup" "${ZSHRC}"
		rm -f "$_uninstall_zshrc_backup"
		success "Restored ${ZSHRC} from ${_uninstall_zshrc_backup} (backup removed)"
	elif grep -qF '# master-oogway:managed' "${ZSHRC}" 2>/dev/null; then
		_zshrc_uninstall_backup="${ZSHRC}.pre-uninstall.$(date +%Y%m%d_%H%M%S)"
		cp "${ZSHRC}" "${_zshrc_uninstall_backup}"
		rm -f "${ZSHRC}"
		warn "Removed managed ${ZSHRC} — saved your copy to ${_zshrc_uninstall_backup}"
	else
		success "${ZSHRC} not managed by master-oogway — left untouched"
	fi
	rm -f "${ZSHRC}.upstream-snapshot"

	# .gitconfig
	_uninstall_gitconfig_backup=$(_find_backup "${HOME}/.gitconfig.pre-master-oogway")
	if [[ -n "$_uninstall_gitconfig_backup" ]]; then
		cp "$_uninstall_gitconfig_backup" "${HOME}/.gitconfig"
		rm -f "$_uninstall_gitconfig_backup"
		success "Restored ~/.gitconfig from ${_uninstall_gitconfig_backup} (backup removed)"
	elif [[ -f "${HOME}/.gitconfig" ]]; then
		git config --file "${HOME}/.gitconfig" --unset-all include.path '~/.gitconfig.master-oogway' 2>/dev/null || true
		success "Removed bundle [include] from ~/.gitconfig"
	fi
	rm -f "${HOME}/.gitconfig.master-oogway"
	success "Removed ~/.gitconfig.master-oogway"

	# ~/.ssh/config — remove master-oogway:sendenv block (marker or legacy bare line)
	_uninstall_ssh_config="${HOME}/.ssh/config"
	if grep -qF '# BEGIN master-oogway:sendenv' "$_uninstall_ssh_config" 2>/dev/null; then
		sed -i '/# BEGIN master-oogway:sendenv/,/# END master-oogway:sendenv/d' "$_uninstall_ssh_config"
		success "Removed SendEnv DRAGON__* block from ~/.ssh/config"
	elif grep -qF 'SendEnv DRAGON__*' "$_uninstall_ssh_config" 2>/dev/null; then
		sed -i '/SendEnv DRAGON__\*/d' "$_uninstall_ssh_config"
		success "Removed SendEnv DRAGON__* from ~/.ssh/config (legacy)"
	else
		success "SendEnv DRAGON__* not in ~/.ssh/config — nothing to remove"
	fi

	# /etc/ssh/sshd_config.d/99-master-oogway-acceptenv.conf — remove drop-in
	_uninstall_dropin="/etc/ssh/sshd_config.d/99-master-oogway-acceptenv.conf"
	_uninstall_sshd_config="/etc/ssh/sshd_config"
	_sshd_needs_reload=false
	if [[ -f "$_uninstall_dropin" ]]; then
		if confirm "Remove ${_uninstall_dropin} and reload sshd? (sudo required)"; then
			sudo rm -f "$_uninstall_dropin"
			_sshd_needs_reload=true
			success "Removed ${_uninstall_dropin}"
		else
			warn "Skipped — remove manually: sudo rm ${_uninstall_dropin}"
		fi
	fi
	# Also clean up any legacy marker-wrapped block left in the main config.
	if grep -qF '# BEGIN master-oogway:acceptenv' "$_uninstall_sshd_config" 2>/dev/null; then
		if confirm "Remove legacy AcceptEnv block from ${_uninstall_sshd_config} and reload sshd? (sudo required)"; then
			sudo sed -i '/# BEGIN master-oogway:acceptenv/,/# END master-oogway:acceptenv/d' "$_uninstall_sshd_config"
			_sshd_needs_reload=true
			info "Removed legacy AcceptEnv stanza from /etc/ssh/sshd_config"
		else
			warn "Skipped — remove manually: sudo sed -i '/# BEGIN master-oogway:acceptenv/,/# END master-oogway:acceptenv/d' ${_uninstall_sshd_config}"
		fi
	fi
	if [[ "$_sshd_needs_reload" == true ]]; then
		if sudo sshd -t 2>/dev/null; then
			sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd 2>/dev/null || true
			success "Reloaded sshd"
		else
			warn "sshd config validation failed after removal — sshd NOT reloaded; check manually"
		fi
	else
		success "AcceptEnv DRAGON__* not configured — nothing to remove"
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

	# .zshenv
	rm -f "${HOME}/.zshenv.master-oogway"
	success "Removed ~/.zshenv.master-oogway"
	if [[ -f "${HOME}/.zshenv" ]]; then
		sed -i '/zshenv\.master-oogway/d' "${HOME}/.zshenv"
		if [[ -z "$(tr -d '[:space:]' < "${HOME}/.zshenv")" ]]; then
			rm -f "${HOME}/.zshenv"
			success "Removed empty ~/.zshenv"
		else
			success "Removed source line from ~/.zshenv"
		fi
	fi

	# .editorconfig — not removed; may predate dragon or have been
	# edited by the user. Left in place with clear guidance.
	warn "${HOME}/.editorconfig was NOT removed."
	warn "  master-oogway wrote tab-indent / LF-ending conventions there."
	warn "  remove or edit: ${HOME}/.editorconfig"

	success "dragon uninstall complete. Open a new terminal to apply changes."
	exit 0
fi

# -- Pre-flight -----------------------------------------------------------------

[[ "$(uname)" == "Linux" ]] || die "dragon requires Linux (Ubuntu 24.04). macOS/BSD are not supported."

_check_required_packages

# en_US.UTF-8 locale — required for correct terminal rendering and zshrc's
# locale block. Not auto-fixed: update-locale writes /etc/default/locale and
# takes effect only in a new login shell, so the user must run it themselves.
if ! locale -a 2>/dev/null | grep -qiE '^en_US\.(utf-?8|UTF-8)$'; then
	warn "en_US.UTF-8 locale is not generated on this system."
	todo_item "Set up locale (run these commands, then open a new terminal):
	  sudo apt install -y locales
	  sudo sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
	  sudo locale-gen en_US.UTF-8
	  sudo update-locale LANG=en_US.UTF-8"
else
	success "en_US.UTF-8 locale already generated"
fi

_check_oh_my_zsh

# -- .zshrc: installed once; never overwritten unless --force -------------------

# Save the shipped template as the merge base for future 3-way merges. Called
# on every successful zshrc write so the snapshot always reflects what the
# user's ~/.zshrc was last derived from.
_save_zshrc_snapshot()
{
	copy_file "${INSTALL_DIR}/zshrc.master-oogway" "${ZSHRC_SNAPSHOT}"
}

_install_zshrc()
{
	local backup_path
	backup_path=$(_mo_backup "${ZSHRC}")
	if [[ -n "$backup_path" ]]; then
		info "Your previous ~/.zshrc was saved to ${backup_path}"
	fi
	copy_file "${INSTALL_DIR}/zshrc.master-oogway" "${ZSHRC}"
	_save_zshrc_snapshot
}

# On update, attempt a `git merge-file` 3-way merge so template changes flow
# into the user's managed ~/.zshrc without clobbering their local edits:
#   base   = snapshot (template as of the last install)
#   ours   = current ~/.zshrc (may hold user edits)
#   theirs = new template
# git merge-file exits 0 on a clean merge, 1 when it produced conflict markers,
# and >1 on a real error. Under `set -e` those non-zero exits would abort the
# script, so the exit code is captured explicitly with `|| status=$?`.
_merge_zshrc()
{
	local template="${INSTALL_DIR}/zshrc.master-oogway"
	[[ -f "${template}" ]] || return

	# Fast path: snapshot matches the template → nothing changed upstream.
	if [[ -f "${ZSHRC_SNAPSHOT}" ]] && command -v sha256sum &>/dev/null; then
		local template_sha snapshot_sha
		template_sha=$(sha256sum "${template}" | cut -d' ' -f1)
		snapshot_sha=$(sha256sum "${ZSHRC_SNAPSHOT}" | cut -d' ' -f1)
		[[ "${template_sha}" == "${snapshot_sha}" ]] && return
	fi

	# No snapshot yet: this is the first update after the merge feature shipped.
	# If the user's ~/.zshrc already matches the template, there's nothing to
	# merge — silently bootstrap the snapshot and return.  Only warn when they
	# actually differ (user has local edits we can't merge without a baseline).
	if [[ ! -f "${ZSHRC_SNAPSHOT}" ]]; then
		if command -v sha256sum &>/dev/null && [[ -f "${ZSHRC}" ]]; then
			local template_sha zshrc_sha
			template_sha=$(sha256sum "${template}" | cut -d' ' -f1)
			zshrc_sha=$(sha256sum "${ZSHRC}" | cut -d' ' -f1)
			if [[ "${template_sha}" == "${zshrc_sha}" ]]; then
				_save_zshrc_snapshot
				return
			fi
		fi
		warn "The zshrc template has changed, but no merge snapshot exists yet."
		warn "Run install.sh once to create ${ZSHRC_SNAPSHOT}, then future"
		warn "updates will 3-way merge template changes into your ~/.zshrc."
		warn "Meanwhile review changes with: master-oogway diff-zshrc"
		return
	fi

	# Write to a temp file rather than capturing stdout: command substitution
	# strips the trailing newline, which would corrupt ~/.zshrc on every merge.
	local tmp status=0
	tmp=$(mktemp "${ZSHRC}.merge.XXXXXX")
	git merge-file -p "${ZSHRC}" "${ZSHRC_SNAPSHOT}" "${template}" \
		> "${tmp}" || status=$?

	if [[ ${status} -eq 0 ]]; then
		mv "${tmp}" "${ZSHRC}"
		_save_zshrc_snapshot
		success "Merged zshrc template changes into ${ZSHRC} (3-way merge, no conflicts)."
	elif [[ ${status} -eq 1 ]]; then
		rm -f "${tmp}"
		warn "The zshrc template changed and conflicts with your local edits."
		warn "Your ~/.zshrc was left untouched. Merge manually against:"
		warn "  base:     ${ZSHRC_SNAPSHOT}"
		warn "  template: ${template}"
		warn "Or review changes with: master-oogway diff-zshrc"
	else
		rm -f "${tmp}"
		warn "The zshrc template has changed since your last install."
		warn "New features may have been added. Review with:"
		warn "  master-oogway diff-zshrc"
		warn "Apply any changes you want manually — your file is never auto-overwritten."
	fi
}

# Install when the file is absent, forced, or present but NOT master-oogway's
# (e.g. oh-my-zsh's installer wrote its own template — it carries no managed
# marker). A marked file may hold user edits, so it is 3-way merged instead.
if [[ ! -f "${ZSHRC}" ]] || [[ "${MO_FORCE}" == true ]] \
	|| ! grep -qF '# master-oogway:managed' "${ZSHRC}" 2>/dev/null; then
	_install_zshrc
else
	_merge_zshrc
fi

# Keep the legacy snapshot (used by `master-oogway diff-zshrc`) up-to-date.
copy_file "${INSTALL_DIR}/zshrc.master-oogway" "${ZSHRC}.upstream-snapshot"

# -- .zshenv --------------------------------------------------------------------

_install_zshenv()
{
	local template="${INSTALL_DIR}/zshenv.master-oogway"
	local managed="${HOME}/.zshenv.master-oogway"
	local zshenv="${HOME}/.zshenv"
	local source_line="source ~/.zshenv.master-oogway"

	copy_file "$template" "$managed"

	if [[ ! -f "$zshenv" ]]; then
		printf '%s\n' "$source_line" > "$zshenv"
		success "Created ${zshenv} sourcing ${managed}"
	elif grep -qFx "$source_line" "$zshenv"; then
		success "already up-to-date: ${zshenv}"
	elif [[ "${MO_FORCE}" == true ]]; then
		printf '\n%s\n' "$source_line" >> "$zshenv"
		success "Added source line to ${zshenv}"
	else
		warn "~/.zshenv is not sourcing ~/.zshenv.master-oogway — EDITOR/VISUAL won't be auto-set."
		warn "Re-add with: echo 'source ~/.zshenv.master-oogway' >> ~/.zshenv"
	fi
}

_install_zshenv

# -- .editorconfig --------------------------------------------------------------
# Installed at ~/.editorconfig so the conventions apply globally — EditorConfig
# walks up from the file being edited and picks up the first match.

_install_editorconfig()
{
	local template="${INSTALL_DIR}/editorconfig.master-oogway"
	local editorconfig="${HOME}/.editorconfig"

	if [[ ! -f "$editorconfig" ]] || [[ "${MO_FORCE}" == true ]]; then
		copy_file "$template" "$editorconfig"
	elif cmp -s "$template" "$editorconfig"; then
		success "already up-to-date: ${editorconfig}"
	else
		warn "~/.editorconfig has drifted from the master-oogway template."
		warn "Review with: diff ~/.editorconfig ~/.master-oogway/editorconfig.master-oogway"
	fi
}

_install_editorconfig

# -- .gitconfig -----------------------------------------------------------------
# ~/.gitconfig.master-oogway  — bundle-managed settings (always updated)
# ~/.gitconfig                — user-owned; created once, never overwritten
#                               contains [user] + [include] pointing to both files

_install_gitconfig()
{
	# Always update the bundle-managed file.
	copy_file "${INSTALL_DIR}/gitconfig.master-oogway" "${GITCONFIG_BUNDLE}"

	# Resolve git identity: prefer existing ~/.gitconfig, then ask.
	local git_name git_email
	git_name=$(git config --file "${GITCONFIG}" user.name  2>/dev/null || true)
	git_email=$(git config --file "${GITCONFIG}" user.email 2>/dev/null || true)

	if [[ -z "$git_name" ]] || [[ -z "$git_email" ]]; then
		[[ -r /dev/tty ]] || die "No tty available for interactive prompts." \
			"Pre-configure git identity before running install:" \
			"git config --global user.name 'Your Name' && git config --global user.email 'you@example.com'"
	fi

	if [[ -z "$git_name" ]]; then
		while [[ -z "$git_name" ]]; do
			_ask "Git user name: "
			read -r git_name < /dev/tty
		done
	fi
	if [[ -z "$git_email" ]]; then
		while [[ -z "$git_email" ]]; do
			_ask "Git email: "
			read -r git_email < /dev/tty
		done
	fi

	# If ~/.gitconfig already includes the bundle, leave it alone.
	if grep -qF 'gitconfig.master-oogway' "${GITCONFIG}" 2>/dev/null; then
		success "${GITCONFIG} already includes gitconfig.master-oogway — not overwritten"
	else
		# Include is missing. Add it only if file doesn't exist yet (first install)
		# or if --force was passed. Otherwise warn and skip.
		if [[ ! -f "${GITCONFIG}" ]] || [[ "${MO_FORCE}" == true ]]; then
			if [[ -f "${GITCONFIG}" ]]; then
				local tmp
				tmp=$(mktemp "${GITCONFIG}.XXXXXX")
				chmod --reference="${GITCONFIG}" "${tmp}"
				{
					printf '[include]\n\tpath = ~/.gitconfig.master-oogway\n\n'
					cat "${GITCONFIG}"
				} > "${tmp}"
				mv "${tmp}" "${GITCONFIG}"
			else
				printf '[include]\n\tpath = ~/.gitconfig.master-oogway\n' > "${GITCONFIG}"
			fi
			success "Added bundle include to ${GITCONFIG}"
		else
			warn "~/.gitconfig is not including ~/.gitconfig.master-oogway — git aliases and delta pager won't be active."
			warn "Re-add by prepending: [include] path = ~/.gitconfig.master-oogway to ~/.gitconfig"
		fi
	fi

	git config --file "${GITCONFIG}" user.name  "$git_name"
	git config --file "${GITCONFIG}" user.email "$git_email"
	success "Git identity: ${git_name} <${git_email}>"
}

_install_gitconfig

# -- ~/.ssh/config — SendEnv for dragon theme forwarding -----------------------

_install_ssh_sendenv()
{
	local ssh_config="${HOME}/.ssh/config"
	local marker_begin="# BEGIN master-oogway:sendenv"
	local marker_end="# END master-oogway:sendenv"

	mkdir -p "${HOME}/.ssh"
	chmod 700 "${HOME}/.ssh"

	# Already present (marker-based) — nothing to do.
	if grep -qF "$marker_begin" "$ssh_config" 2>/dev/null; then
		success "SendEnv DRAGON__* already in ~/.ssh/config"
		return
	fi

	# Existing config but no marker and no --force — warn only.
	if [[ -f "$ssh_config" ]] && [[ "${MO_FORCE}" != true ]]; then
		warn "Dragon theme SSH forwarding is not configured."
		warn "Run 'master-oogway ssh-forwarding setup' to enable it."
		return
	fi

	# Old install (no marker) — remove bare line before re-adding with markers.
	if grep -qF "SendEnv DRAGON__*" "$ssh_config" 2>/dev/null; then
		sed -i '/SendEnv DRAGON__\*/d' "$ssh_config"
		info "Migrated existing SendEnv DRAGON__* to marker-wrapped stanza"
	fi

	printf '\n%s\nHost *\n    SendEnv DRAGON__*\n    HashKnownHosts no\n%s\n' "$marker_begin" "$marker_end" >> "$ssh_config"
	chmod 600 "$ssh_config"
	success "Added SendEnv DRAGON__* to ~/.ssh/config"
}

_install_ssh_sendenv

# -- /etc/ssh/sshd_config — AcceptEnv for dragon theme forwarding --------------

_install_sshd_acceptenv()
{
	local sshd_config="/etc/ssh/sshd_config"
	local dropin_dir="/etc/ssh/sshd_config.d"
	local dropin="${dropin_dir}/99-master-oogway-acceptenv.conf"
	local marker_begin="# BEGIN master-oogway:acceptenv"
	local marker_end="# END master-oogway:acceptenv"

	if [[ ! -f "$sshd_config" ]]; then
		info "sshd not found — skipping AcceptEnv (not a server or sshd not installed)"
		return
	fi

	# Already present as a drop-in — nothing to do.
	if [[ -f "$dropin" ]]; then
		success "AcceptEnv DRAGON__* already in ${dropin}"
		return
	fi

	# Config exists but no drop-in and no --force — warn only.
	if [[ "${MO_FORCE}" != true ]]; then
		warn "Dragon theme SSH AcceptEnv is not configured on this server."
		warn "Run install.sh --force to configure it, or add ${dropin} manually."
		return
	fi

	info "SSH theme forwarding requires adding AcceptEnv DRAGON__* to sshd."
	if ! confirm "Add ${dropin} and reload sshd? (sudo required)"; then
		info "Skipped — run install.sh again to configure later, or add manually."
		return
	fi

	# Prime sudo so the chain below shares one auth prompt.
	sudo -v || true

	# Migrate: remove old marker-wrapped block from main sshd_config if present.
	if grep -qF "$marker_begin" "$sshd_config" 2>/dev/null; then
		sudo sed -i "/${marker_begin}/,/${marker_end}/d" "$sshd_config"
		info "Removed old marker-wrapped stanza from /etc/ssh/sshd_config"
	fi
	# Also remove any legacy bare line left by even older installs.
	if grep -qF 'AcceptEnv DRAGON__*' "$sshd_config" 2>/dev/null; then
		sudo sed -i '/AcceptEnv DRAGON__\*/d' "$sshd_config"
		info "Removed legacy bare AcceptEnv line from /etc/ssh/sshd_config"
	fi

	# Write drop-in, validate with sshd -t (which reads *.conf), remove on failure.
	local tmp
	tmp=$(mktemp)
	printf '# master-oogway: allow dragon theme vars to be forwarded over SSH\nAcceptEnv DRAGON__*\n' > "$tmp"
	sudo mkdir -p "$dropin_dir"
	sudo cp "$tmp" "$dropin"
	rm -f "$tmp"
	if ! sudo sshd -t 2>/dev/null; then
		warn "sshd config validation failed — drop-in removed"
		sudo rm -f "$dropin"
		return 1
	fi
	sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd 2>/dev/null || true
	success "Added ${dropin} and reloaded sshd"
}

_install_sshd_acceptenv

# -- dragon theme: check for new variables -----------------------------------

_check_theme_vars()
{
	local themes_dir="${INSTALL_DIR}/omz-custom/themes/dragon"
	local current_hash
	# Hash sorted _DRAGON_DEFAULTS keys via a one-shot zsh — immune to
	# grep over-matching comments. Must match configure.zsh and notifier.zsh.
	current_hash=$(zsh -c '
		source "$1/schema.zsh"
		_dragon_init_defaults
		printf "%s\n" "${(@k)_DRAGON_DEFAULTS}" | sort | md5sum | cut -d" " -f1
	' -- "${themes_dir}" 2>/dev/null)

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
_zcompile_plugins

# -- User extension directories -------------------------------------------------

_install_user_ext_dirs()
{
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

# -- Login shell check ----------------------------------------------------------

_check_login_shell()
{
	[[ "${SHELL:-}" == */zsh ]] && return
	warn "Your login shell is not zsh (current: ${SHELL:-unknown})."
	warn "master-oogway is a zsh environment — it won't load in bash sessions."
	if confirm "Change your login shell to zsh now? (runs: chsh -s \"$(command -v zsh)\")"; then
		# chsh prompts for a password and fails on a typo or Ctrl-C; under
		# set -e a bare call would abort the whole install at its last step.
		if chsh -s "$(command -v zsh)"; then
			success "Login shell changed to zsh. Log out and back in for it to take effect."
		else
			warn "chsh failed — login shell unchanged."
			todo_item "Change login shell to zsh: chsh -s \"$(command -v zsh)\""
		fi
	else
		todo_item "Change login shell to zsh: chsh -s \"$(command -v zsh)\""
	fi
}

_check_login_shell

# -- Backup-tip -----------------------------------------------------------------
# Suggest version-controlling the customisation dir. Skipped once the user has
# already initialised a git repo there (or hasn't installed anything customisable
# there yet — fresh installs land here before conf.zsh exists).

_print_backup_tip()
{
	[[ -d "${CONF_DIR}" ]] || return
	[[ -d "${CONF_DIR}/.git" ]] && return
	local short="${CONF_DIR/#$HOME/~}"
	echo ""
	echo -e "${COLOR_CYAN}┌─────────────────────────────────────────────────────┐${COLOR_RESET}"
	echo -e "${COLOR_CYAN}│  Tip: version-control your customisations           │${COLOR_RESET}"
	echo -e "${COLOR_CYAN}└─────────────────────────────────────────────────────┘${COLOR_RESET}"
	cat <<EOF
  ${short} holds your customisations:
	- conf.zsh                — dragon theme settings
	- lan-hosts.manual        — manual SSH host overlay
	- custom-plugins/         — your plugins
	- custom-pre-zsh/  custom-zsh/  — your *.zsh snippets

  Worth backing up as its own git repo. One-time setup:

	cd ${short}
	cat > .gitignore <<'GITIGN'
# Derived state — regenerated by install/refresh
state
lan-hosts
lan-hosts.lock
lan-hosts.sshconf.sha
# Timestamped backups
conf.zsh.bak.*
GITIGN
	git init && git add -A && git commit -m "initial master-oogway config"

EOF
}

# -- Done -----------------------------------------------------------------------

declare -A _mo_missing_cmds=() _mo_descriptions=() _mo_apt_pkgs=()
if _collect_missing_optionals; then
	if [[ "$_MO_UPDATE_MODE" == true ]]; then
		# update: never block, report at end so the user is informed
		print_todos
		_report_optional_deps "warn"
	elif [[ "$MO_NO_RECOMMENDED" == true ]]; then
		# fresh install with --no-recommended-packages: report but don't block
		print_todos
		_report_optional_deps "warn"
	else
		# fresh install: block and show install instructions
		print_todos
		_report_optional_deps "block"
	fi
else
	print_todos
fi
_print_backup_tip
success "dragon installation complete. Open a new terminal to apply changes."
