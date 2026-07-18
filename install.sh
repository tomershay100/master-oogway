#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# install.sh - dragon zsh environment installer (bundle: master-oogway)
# Run with --help for usage.
# ------------------------------------------------------------------------------
set -Eeuo pipefail

readonly REPO_URL="https://github.com/tomershay100/master-oogway.git"
readonly INSTALL_DIR="${HOME}/.master-oogway"
readonly CONF_DIR="${HOME}/.config/master-oogway"
# First-ever install: $CONF_DIR doesn't exist yet. Captured before any config
# write creates it, so the welcome banner shows only on the genuine first run.
if [[ -d "${CONF_DIR}" ]]; then MO_FIRST_INSTALL=false; else MO_FIRST_INSTALL=true; fi
readonly MO_FIRST_INSTALL
readonly ZSHRC="${HOME}/.zshrc"
readonly GITCONFIG="${HOME}/.gitconfig"
readonly GITCONFIG_BUNDLE="${HOME}/.gitconfig.master-oogway"

# User-owned config files live as real files under $CONF_DIR (git-backupable)
# and are symlinked into $HOME. Real files carry no dot prefix; the ~/ symlinks
# keep it so zsh/git/editorconfig find them.
readonly ZSHRC_REAL="${CONF_DIR}/zshrc"
readonly ZSHENV_REAL="${CONF_DIR}/zshenv"
readonly GITCONFIG_REAL="${CONF_DIR}/gitconfig"
readonly EDITORCONFIG_REAL="${CONF_DIR}/editorconfig"
readonly ZSHRC_SNAPSHOT="${CONF_DIR}/zshrc.snapshot"

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

# True when $1 is already a symlink pointing into $CONF_DIR — the marker that
# master-oogway migrated this file. Replaces the old '# master-oogway:managed'
# grep: the symlink itself proves ownership.
_mo_is_managed_symlink()
{
	local link="$1"
	[[ -L "$link" ]] || return 1
	[[ "$(readlink "$link")" == "${CONF_DIR}/"* ]]
}

# Migrate a user config file to the symlink layout, idempotently.
#   $1 home path  (e.g. ~/.zshrc)      $2 real path (e.g. $CONF_DIR/zshrc)
#   $3 seed       action when the real file doesn't exist yet:
#                 a source-file path → copy it in (zshrc/editorconfig template)
#                 "" (empty)         → create an empty real file (caller then
#                                      populates it, e.g. append source lines)
# The home file is backed up (if a non-managed real file/foreign symlink) and
# replaced with a symlink. If already our symlink, this is a no-op.
_mo_migrate_to_symlink()
{
	local home_path="$1" real_path="$2" seed="${3:-}"

	if _mo_is_managed_symlink "$home_path" && [[ -e "$real_path" ]]; then
		success "already linked: ${home_path} → ${real_path}"
		return 0
	fi

	mkdir -p "$(dirname "$real_path")"

	# Seed the real file if it doesn't exist yet. An existing real file is the
	# user's — never clobbered here (only --force paths overwrite, done by
	# callers before calling us).
	if [[ ! -e "$real_path" ]]; then
		if [[ -n "$seed" ]] && [[ -f "$home_path" ]] && [[ ! -L "$home_path" ]]; then
			# migrate the user's existing real file verbatim
			cp -p "$home_path" "$real_path"
		elif [[ -n "$seed" ]]; then
			cp -p "$seed" "$real_path"
		else
			: > "$real_path"
		fi
	fi

	# Back up whatever is at the home path (real file or foreign symlink) unless
	# it's already our managed symlink.
	if [[ -e "$home_path" || -L "$home_path" ]] && ! _mo_is_managed_symlink "$home_path"; then
		local backup
		backup=$(_mo_backup "$home_path")
		[[ -n "$backup" ]] && info "Backed up ${home_path} → ${backup}"
	fi

	ln -sfn "$real_path" "$home_path"
	success "linked: ${home_path} → ${real_path}"
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

# Welcome banner — first install only. Single-quoted heredoc so the $$ art is
# literal (no expansion). cat can be aliased; use command cat.
_mo_banner()
{
	command cat <<'MO_BANNER'
$$\      $$\                       $$\                                $$$$$$\
$$$\    $$$ |                      $$ |                              $$  __$$\
$$$$\  $$$$ | $$$$$$\   $$$$$$$\ $$$$$$\    $$$$$$\   $$$$$$\        $$ /  $$ | $$$$$$\   $$$$$$\  $$\  $$\  $$\  $$$$$$\  $$\   $$\
$$\$$\$$ $$ | \____$$\ $$  _____|\_$$  _|  $$  __$$\ $$  __$$\       $$ |  $$ |$$  __$$\ $$  __$$\ $$ | $$ | $$ | \____$$\ $$ |  $$ |
$$ \$$$  $$ | $$$$$$$ |\$$$$$$\    $$ |    $$$$$$$$ |$$ |  \__|      $$ |  $$ |$$ /  $$ |$$ /  $$ |$$ | $$ | $$ | $$$$$$$ |$$ |  $$ |
$$ |\$  /$$ |$$  __$$ | \____$$\   $$ |$$\ $$   ____|$$ |            $$ |  $$ |$$ |  $$ |$$ |  $$ |$$ | $$ | $$ |$$  __$$ |$$ |  $$ |
$$ | \_/ $$ |\$$$$$$$ |$$$$$$$  |  \$$$$  |\$$$$$$$\ $$ |             $$$$$$  |\$$$$$$  |\$$$$$$$ |\$$$$$\$$$$  |\$$$$$$$ |\$$$$$$$ |
\__|     \__| \_______|\_______/    \____/  \_______|\__|             \______/  \______/  \____$$ | \_____\____/  \_______| \____$$ |
                                                                                         $$\   $$ |                        $$\   $$ |
                                                                                         \$$$$$$  |                        \$$$$$$  |
                                                                                          \______/                          \______/
MO_BANNER
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

	# For each symlinked user file: drop our symlink, restore the pre-install
	# backup if one exists. The real file under $CONF_DIR is never deleted here
	# (it may hold user edits) — $CONF_DIR removal is prompted separately below.
	_uninstall_symlinked_file()
	{
		local home_path="$1"
		local backup
		backup=$(_find_backup "${home_path}.pre-master-oogway")

		if _mo_is_managed_symlink "$home_path"; then
			rm -f "$home_path"
			success "Removed symlink ${home_path}"
		fi

		if [[ -n "$backup" ]]; then
			# only restore if we actually removed a link (or nothing is there)
			if [[ ! -e "$home_path" ]]; then
				cp "$backup" "$home_path"
				rm -f "$backup"
				success "Restored ${home_path} from ${backup} (backup removed)"
			fi
		fi
	}

	# .zshrc
	_uninstall_symlinked_file "${ZSHRC}"
	rm -f "${ZSHRC}.upstream-snapshot"

	# .gitconfig — drop the symlink + restore backup; the bundle payload goes too.
	_uninstall_symlinked_file "${GITCONFIG}"
	rm -f "${GITCONFIG_BUNDLE}"
	success "Removed ${GITCONFIG_BUNDLE}"

	# .zshenv — drop symlink + restore backup, then remove the managed payload.
	# Done BEFORE the CONF_DIR prompt so restoring the backup isn't undone by it.
	_uninstall_symlinked_file "${HOME}/.zshenv"
	rm -f "${HOME}/.zshenv.master-oogway"
	success "Removed ~/.zshenv.master-oogway"

	# .editorconfig — drop symlink + restore backup. The real file under
	# $CONF_DIR is left for the CONF_DIR prompt below (never force-deleted here).
	_uninstall_symlinked_file "${HOME}/.editorconfig"

	# lan-ssh — reverse 'master-oogway lan-ssh setup': crontab line, ssh_config
	# SendEnv stanza, sshd AcceptEnv drop-in, generated alias file.
	if crontab -l 2>/dev/null | grep -qF "# master-oogway:lan-scan"; then
		crontab -l 2>/dev/null | grep -vF "# master-oogway:lan-scan" | crontab -
		success "Removed lan-scan crontab line"
	fi
	if grep -qF "# BEGIN master-oogway:sendenv" "${HOME}/.ssh/config" 2>/dev/null; then
		sed -i '/# BEGIN master-oogway:sendenv/,/# END master-oogway:sendenv/d' "${HOME}/.ssh/config"
		success "Removed SendEnv stanza from ~/.ssh/config"
	fi
	if [[ -f /etc/ssh/sshd_config.d/99-master-oogway-acceptenv.conf ]]; then
		if confirm "Remove sshd AcceptEnv drop-in and reload sshd? (sudo)"; then
			sudo rm -f /etc/ssh/sshd_config.d/99-master-oogway-acceptenv.conf
			sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd 2>/dev/null || true
			success "Removed sshd AcceptEnv drop-in"
		fi
	fi
	rm -f "${CONF_DIR}/custom-zsh/lan-hosts.zsh"

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

	success "dragon uninstall complete. Open a new terminal to apply changes."
	exit 0
fi

# -- Pre-flight -----------------------------------------------------------------

[[ "${MO_FIRST_INSTALL}" == true ]] && _mo_banner

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

# -- .zshrc: migrated once to $CONF_DIR/zshrc, symlinked, then never touched ----

# Record the shipped template as the snapshot: the template as of this install.
# The next install compares against it to decide whether the template moved.
_save_zshrc_snapshot()
{
	copy_file "${INSTALL_DIR}/zshrc.master-oogway" "${ZSHRC_SNAPSHOT}"
}

# First install: seed $CONF_DIR/zshrc from the shipped template, back up any
# existing ~/.zshrc (oh-my-zsh stock or user's own), symlink it in. master-oogway
# owns the zshrc — a replaced real file is flagged via todo_item so the user can
# port edits back from the backup.
_install_zshrc()
{
	# master-oogway owns ~/.zshrc — it ships the full plugin list, exports and
	# environment, not just a theme. On first install (or --force) we always seed
	# our template; any pre-existing ~/.zshrc (oh-my-zsh stock or the user's own)
	# is backed up by _mo_migrate_to_symlink and flagged below so the user can
	# port edits back. Passing an empty seed skips the verbatim-migrate branch;
	# we write the template ourselves.
	if [[ ! -e "${ZSHRC_REAL}" ]] || [[ "${MO_FORCE}" == true ]]; then
		local backup
		backup=$(_mo_backup "${ZSHRC_REAL}")
		[[ -n "$backup" ]] && info "Backed up ${ZSHRC_REAL} → ${backup}"
		copy_file "${INSTALL_DIR}/zshrc.master-oogway" "${ZSHRC_REAL}"
	fi
	# Warn the user before their real ~/.zshrc is replaced with our symlink.
	if [[ -f "${ZSHRC}" ]] && [[ ! -L "${ZSHRC}" ]]; then
		todo_item "Your previous ~/.zshrc was replaced by master-oogway. The original \
is backed up (~/.zshrc.pre-master-oogway.*) — port any custom settings into \
~/.config/master-oogway/zshrc, then run 'soursh'."
	fi
	_mo_migrate_to_symlink "${ZSHRC}" "${ZSHRC_REAL}" ""
	_save_zshrc_snapshot
}

# On update, the real zshrc ($CONF_DIR/zshrc, reached via the ~/.zshrc symlink)
# is never auto-modified — it may hold user edits. Three files matter:
#   template = the zshrc shipped by this install
#   snapshot = the template as of the LAST install (~/.config/.../zshrc.snapshot)
#   real     = $CONF_DIR/zshrc, the user's current file
# and two messages:
#   template != snapshot  → WARN: the template changed in this update. Advance
#       the snapshot to the new template so the next install is silent.
#   template == snapshot AND snapshot != real  → INFO: the user has local edits
#       vs the shipped template — remind them `diff-zshrc` can show them.
# Otherwise (template == snapshot == real) → silent.
_sync_zshrc_snapshot()
{
	local template="${INSTALL_DIR}/zshrc.master-oogway"
	[[ -f "${template}" ]] || return 0

	# template != snapshot → the update ships a new template. Warn once, then
	# advance the snapshot (a missing snapshot counts as "changed" too).
	if [[ ! -f "${ZSHRC_SNAPSHOT}" ]] || ! cmp -s "${template}" "${ZSHRC_SNAPSHOT}"; then
		warn "The zshrc template changed in this update. Your ~/.zshrc was left"
		warn "untouched — review with 'master-oogway diff-zshrc' and apply any changes."
		_save_zshrc_snapshot
		return 0
	fi

	# template == snapshot: nothing new upstream. Only speak up if the user's
	# own real zshrc has drifted from it — a gentle reminder, not a warning.
	if [[ -f "${ZSHRC_REAL}" ]] && ! cmp -s "${ZSHRC_SNAPSHOT}" "${ZSHRC_REAL}"; then
		info "Your ~/.zshrc differs from the installed template — 'master-oogway diff-zshrc' shows the diff any time."
	fi
}

# Migrate when ~/.zshrc isn't yet our managed symlink (fresh install, or an
# oh-my-zsh/user file predating this layout), or when --force. An already-linked
# file may hold user edits, so it's only drift-checked.
if ! _mo_is_managed_symlink "${ZSHRC}" || [[ "${MO_FORCE}" == true ]]; then
	_install_zshrc
else
	_sync_zshrc_snapshot
fi

# -- .zshenv --------------------------------------------------------------------

_install_zshenv()
{
	local template="${INSTALL_DIR}/zshenv.master-oogway"
	local managed="${HOME}/.zshenv.master-oogway"
	local source_line="source ~/.zshenv.master-oogway"

	copy_file "$template" "$managed"

	# Migrate ~/.zshenv → $CONF_DIR/zshenv (seeding from the user's existing file
	# if any, else an empty file), then ensure the source line is present in the
	# real file. The line points at the managed payload, which keeps updating.
	_mo_migrate_to_symlink "${HOME}/.zshenv" "${ZSHENV_REAL}" ""

	if grep -qFx "$source_line" "${ZSHENV_REAL}"; then
		success "already up-to-date: ${ZSHENV_REAL}"
	else
		# prepend a newline only if the file has content, to keep it tidy
		[[ -s "${ZSHENV_REAL}" ]] && printf '\n' >> "${ZSHENV_REAL}"
		printf '%s\n' "$source_line" >> "${ZSHENV_REAL}"
		success "Added source line to ${ZSHENV_REAL}"
	fi
}

_install_zshenv

# -- .editorconfig --------------------------------------------------------------
# Installed at ~/.editorconfig so the conventions apply globally — EditorConfig
# walks up from the file being edited and picks up the first match.

_install_editorconfig()
{
	local template="${INSTALL_DIR}/editorconfig.master-oogway"

	if [[ "${MO_FORCE}" == true ]]; then
		local backup
		backup=$(_mo_backup "${EDITORCONFIG_REAL}")
		[[ -n "$backup" ]] && info "Backed up ${EDITORCONFIG_REAL} → ${backup}"
		copy_file "$template" "${EDITORCONFIG_REAL}"
	fi
	_mo_migrate_to_symlink "${HOME}/.editorconfig" "${EDITORCONFIG_REAL}" "$template"

	if ! cmp -s "$template" "${EDITORCONFIG_REAL}"; then
		warn "~/.editorconfig has drifted from the master-oogway template."
		warn "Review with: diff ${EDITORCONFIG_REAL} ${INSTALL_DIR}/editorconfig.master-oogway"
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

	# Migrate ~/.gitconfig → $CONF_DIR/gitconfig (seeding from the user's existing
	# file if any, else empty) and symlink it in. All writes below target the
	# real file; the ~/.gitconfig symlink resolves to it transparently.
	_mo_migrate_to_symlink "${GITCONFIG}" "${GITCONFIG_REAL}" ""

	# Prepend the bundle [include] once, if absent. It stays in the user-owned
	# real file; the included ~/.gitconfig.master-oogway keeps updating.
	if grep -qF 'gitconfig.master-oogway' "${GITCONFIG_REAL}" 2>/dev/null; then
		success "${GITCONFIG_REAL} already includes gitconfig.master-oogway"
	elif [[ -s "${GITCONFIG_REAL}" ]]; then
		local tmp
		tmp=$(mktemp "${GITCONFIG_REAL}.XXXXXX")
		chmod --reference="${GITCONFIG_REAL}" "${tmp}"
		{
			printf '[include]\n\tpath = ~/.gitconfig.master-oogway\n\n'
			cat "${GITCONFIG_REAL}"
		} > "${tmp}"
		mv "${tmp}" "${GITCONFIG_REAL}"
		success "Added bundle include to ${GITCONFIG_REAL}"
	else
		printf '[include]\n\tpath = ~/.gitconfig.master-oogway\n' > "${GITCONFIG_REAL}"
		success "Added bundle include to ${GITCONFIG_REAL}"
	fi

	git config --file "${GITCONFIG_REAL}" user.name  "$git_name"
	git config --file "${GITCONFIG_REAL}" user.email "$git_email"
	success "Git identity: ${git_name} <${git_email}>"
}

_install_gitconfig

# -- dragon theme: regenerate conf.zsh -----------------------------------------

# On every update, silently rewrite conf.zsh through the writer: existing user
# values are preserved, any newly-added schema vars appear as commented defaults
# in their group, and a timestamped .bak is kept. No prompt, no change-detection
# — new options are simply visible in the file next time it is opened. Skipped
# when conf.zsh does not yet exist (a fresh install has nothing to preserve).
_regen_theme_conf()
{
	local themes_dir="${INSTALL_DIR}/omz-custom/themes/dragon"
	local conf_file="${CONF_DIR}/conf.zsh"

	if [[ ! -f "${conf_file}" ]]; then
		todo_item "Configure your prompt: open a new terminal and run 'dragon-configure'"
		return
	fi

	cp "${conf_file}" "${conf_file}.bak.$(date +%Y%m%d_%H%M%S)"

	# Regenerate in a one-shot zsh: init the schema, load the current values,
	# carry over the `# preset:` header, and re-emit through the writer. The
	# writer self-validates with `zsh -n` and writes atomically.
	if zsh -c '
		typeset -g _DRAGON_CONF_FILE="$2"
		typeset -g _DRAGON_STATE_DIR="${2:h}"
		typeset -g _DRAGON_THEMES_DIR="$1"
		source "$1/schema.zsh"
		source "$1/configure/state.zsh"
		source "$1/configure/writer.zsh"
		_dragon_init_defaults; _dragon_init_types
		_dragon_init_hints;    _dragon_init_groups
		_dragon_load_current_conf
		local preset
		preset=$(command grep -m1 "^# preset: " "$2" | cut -d" " -f3)
		_dragon_write_conf "$preset"
	' -- "${themes_dir}" "${conf_file}" 2>/dev/null; then
		success "dragon theme config refreshed (backup kept)"
	else
		warn "dragon theme config could not be refreshed — left unchanged"
	fi
}

_regen_theme_conf
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
	- custom-plugins/         — your plugins
	- custom-pre-zsh/  custom-zsh/  — your *.zsh snippets

  Worth backing up as its own git repo. One-time setup:

	cd ${short}
	cat > .gitignore <<'GITIGN'
# Derived state — regenerated by install/refresh
state
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
