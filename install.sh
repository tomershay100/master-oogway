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

# -- Platform -------------------------------------------------------------------
# install.sh runs under bash before any zsh is sourced, so it cannot use
# omz-custom/lib/platform.zsh. The few primitives it needs are mirrored here;
# keep the two in step.
# platform-lint: allow — this IS the platform detection.
case "$(uname -s)" in
	Linux)  MO_PLATFORM=linux ;;
	Darwin) MO_PLATFORM=macos ;;
	*)      MO_PLATFORM=linux ;;
esac

_mo_is_macos() { [[ "$MO_PLATFORM" == macos ]]; }

# How to get a Nerd Font on this platform. Not part of the recommended-package
# list: a font is useless until the terminal is pointed at it, which no
# installer can do for the user.
_mo_pkg_hint_font()
{
	if _mo_is_macos; then
		echo "brew install --cask font-jetbrains-mono-nerd-font"
	else
		echo "see https://github.com/ryanoasis/nerd-fonts, or your distro's fonts-* packages"
	fi
}

# Is any Nerd Font installed? The theme defaults DRAGON__USE_NERD_FONT to true,
# and when that assumption is wrong every powerline separator and segment icon
# renders as a tofu box — which reads as a broken install rather than a missing
# font. Checking costs one find; assuming costs the user a confusing prompt.
# -print -quit stops at the first hit instead of walking the whole tree.
_nerd_font_installed()
{
	local d
	if _mo_is_macos; then
		for d in "${HOME}/Library/Fonts" /Library/Fonts /System/Library/Fonts; do
			[[ -d "$d" ]] || continue
			[[ -n "$(find "$d" -iname '*nerd*font*' -print -quit 2>/dev/null)" ]] && return 0
		done
		return 1
	fi
	# platform-lint: allow — fontconfig is the Linux answer and this line is
	# already inside the non-macOS branch; the macOS branch above returns first.
	command -v fc-list &>/dev/null && fc-list 2>/dev/null | grep -qi nerd && return 0
	for d in "${HOME}/.local/share/fonts" "${HOME}/.fonts" /usr/share/fonts; do
		[[ -d "$d" ]] || continue
		[[ -n "$(find "$d" -iname '*nerd*font*' -print -quit 2>/dev/null)" ]] && return 0
	done
	return 1
}

# Names the Nerd Font already on disk, so the todo can say "point your terminal
# at this one" rather than "install a font you already have". Filenames are the
# only metadata reachable without a font parser: JetBrainsMonoNerdFont-Bold.ttf
# is a family followed by a style suffix.
_nerd_font_family()
{
	local d f name
	local -a dirs
	if _mo_is_macos; then
		dirs=("${HOME}/Library/Fonts" /Library/Fonts /System/Library/Fonts)
	else
		dirs=("${HOME}/.local/share/fonts" "${HOME}/.fonts" /usr/share/fonts)
	fi
	for d in ${dirs[@]+"${dirs[@]}"}; do
		[[ -d "$d" ]] || continue
		f="$(find "$d" -iname '*nerd*font*' -print -quit 2>/dev/null)"
		[[ -n "$f" ]] || continue
		name="${f##*/}"; name="${name%.*}"; name="${name%%-*}"
		[[ "$name" == *NerdFont* ]] && name="${name%%NerdFont*} Nerd Font"
		printf '%s' "$name"
		return 0
	done
	return 1
}

# Whether the glyphs will render, which is not what _nerd_font_installed
# answers: a font on disk says nothing about the font the terminal is set to.
# No portable way exists to read a terminal's active font, and under tmux or
# ssh that font belongs to a terminal this script cannot see — so the probe
# narrows it and the person looking at the screen settles it.
#
# Worded to match _dragon_ask_nerd_font in the theme's configure/pick.zsh, so
# the installer and dragon-configure never ask the same question two ways.
# Enter means no: a wrong no is a readable prompt, a wrong yes is tofu on
# every line. \x rather than \u — macOS ships bash 3.2, which has no \u.
_nerd_font_renders()
{
	_nerd_font_installed || return 1
	_mo_has_tty || return 0
	_ask "dragon can use special characters for a richer prompt.\n\n      Powerline arrow:  \xee\x82\xb0\n      Nerd Font icon:   \xef\x81\xbb\n\n      Do both render as a solid arrow and a folder icon? [y/N] "
	local reply
	reply="$(_mo_read_tty)"
	[[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# Mirrors of the two lib/platform.zsh primitives this script needs. It runs
# under bash before any zsh is sourced, so it cannot call them directly.
# GNU stat takes -c %a, BSD stat takes -f %OLp; GNU sed refuses an argument to
# -i, BSD sed requires one.
_mo_stat_mode() {
	if _mo_is_macos; then stat -f '%OLp' "$1" 2>/dev/null
	# platform-lint: allow — the Linux half of _mo_stat_mode.
	else                  stat -c '%a'   "$1" 2>/dev/null
	fi
}

_mo_sed_inplace() {
	# platform-lint: allow — this IS _mo_sed_inplace.
	if _mo_is_macos; then sed -i '' "$1" "$2"
	else                  sed -i    "$1" "$2"
	fi
}

# Debian package name -> Homebrew equivalent, where they differ. A case rather
# than an associative array: macOS ships bash 3.2, which has none.
# Kept in step with _MO_PKG_MACOS in omz-custom/lib/platform.zsh — this script
# runs under bash before any zsh is sourced, so it cannot read that map.
#
# @builtin  macOS ships this exact tool.
# @none:M   macOS solves the same problem another way, so neither the Debian
#           name nor any formula is right. These used to answer @builtin, which
#           told the user that xclip or iproute2 "ships with macOS — check your
#           PATH" and sent them hunting for something that cannot exist there.
_mo_brew_formula() {
	case "$1" in
		build-essential)                       echo "@xcode"   ;;
		texlive-xetex)                         echo "@cask:basictex" ;;
		meld)                                  echo "@cask:meld" ;;
		fd-find)                               echo "fd"       ;;
		p7zip-full)                            echo "sevenzip" ;;
		xz-utils)                              echo "xz"       ;;
		unrar)                                 echo "unar"     ;;
		# Ship with macOS.
		procps|bc|coreutils|less|curl)         echo "@builtin" ;;
		tar|unzip|zip|gzip|bzip2|git)          echo "@builtin" ;;
		# Solved differently on macOS.
		# platform-lint: allow — this is the package-name map itself.
		wl-clipboard|xclip|xsel)               echo "@none:macOS uses pbcopy/pbpaste — no install needed" ;;
		xdg-utils)                             echo "@none:macOS uses open(1) — no install needed" ;;
		iproute2)                              echo "@none:macOS has no ip(8); ifconfig and netstat cover it" ;;
		trash-cli)                             echo "@none:macOS ships /usr/bin/trash — no install needed" ;;
		*)                                     echo "$1"       ;;
	esac
}

# Install command for one or more packages, phrased for this platform.
_mo_pkg_hint() {
	if ! _mo_is_macos; then
		# platform-lint: allow — the Linux half of _mo_pkg_hint.
		echo "sudo apt install $*"
		return
	fi
	local pkg mapped note
	local formulae="" casks="" notes=""
	for pkg in "$@"; do
		mapped="$(_mo_brew_formula "$pkg")"
		note=""
		case "$mapped" in
			# No early return: it dropped every package after the first
			# non-formula, so `_mo_pkg_hint build-essential fzf` never
			# mentioned fzf.
			@xcode)   note="xcode-select --install" ;;
			@builtin) note="${pkg} ships with macOS — check your PATH" ;;
			@none:*)  note="${mapped#@none:}" ;;
			@cask:*)  casks="${casks}${casks:+ }${mapped#@cask:}" ;;
			*)        formulae="${formulae}${formulae:+ }${mapped}" ;;
		esac
		# Deduplicated, as lib/platform.zsh does: xclip and wl-clipboard carry
		# the identical sentence, and saying it twice reads as two separate
		# instructions. Matched with the separators attached so one note
		# cannot match inside another.
		if [[ -n "$note" ]]; then
			case "; ${notes};" in
				*"; ${note};"*) ;;
				*) notes="${notes}${notes:+; }${note}" ;;
			esac
		fi
	done
	# Formulae and casks cannot share one brew invocation.
	local out=""
	[[ -n "$formulae" ]] && out="brew install ${formulae}"
	[[ -n "$casks"    ]] && out="${out}${out:+ && }brew install --cask ${casks}"
	# Parenthesised rather than appended after "; ", matching the zsh original
	# in lib/platform.zsh. This string is shown under "Install recommended
	# packages" as a line to paste, and "; macOS uses pbcopy/pbpaste" is not a
	# command.
	if [[ -n "$notes" ]]; then
		if [[ -n "$out" ]]; then out="${out} (${notes})"; else out="${notes}"; fi
	fi
	# Always succeed: an empty hint returned 1 here, and under the ERR trap
	# that turned a package that needs no install into a scary [ERR] line.
	printf '%s\n' "$out"
	return 0
}

# -- Colors & logging -----------------------------------------------------------

if [[ -t 1 ]] && [[ "${NO_COLOR:-}" == "" ]] && [[ "${TERM:-}" != "dumb" ]] && command -v tput &>/dev/null; then
	# Assigned before `readonly` so a failing tput surfaces as a non-zero
	# status instead of being masked by the declaration's own exit code.
	COLOR_RESET="$(tput sgr0)"
	COLOR_GREEN="$(tput setaf 2)"
	COLOR_YELLOW="$(tput bold)$(tput setaf 3)"
	COLOR_RED="$(tput setaf 1)"
	COLOR_CYAN="$(tput setaf 6)"
	COLOR_MAGENTA="$(tput setaf 5)"
	readonly COLOR_RESET COLOR_GREEN COLOR_YELLOW COLOR_RED COLOR_CYAN COLOR_MAGENTA
else
	readonly COLOR_RESET='' COLOR_GREEN='' COLOR_YELLOW='' COLOR_RED='' COLOR_CYAN='' COLOR_MAGENTA=''
fi

success() { echo -e "${COLOR_GREEN}[OK ]${COLOR_RESET} $*"; }
info()    { echo -e "${COLOR_CYAN}[INF]${COLOR_RESET} $*"; }
warn()    { echo -e "${COLOR_YELLOW}[WRN]${COLOR_RESET} $*" >&2; }
die()     { echo -e "${COLOR_RED}[ERR]${COLOR_RESET} $*" >&2; exit 1; }
_ask()    { echo -en "${COLOR_MAGENTA}[ASK]${COLOR_RESET} $*" > /dev/tty; }

# `[[ -r /dev/tty ]]` only stats the device node, whose mode is 666, so it
# passes with no controlling terminal and the read then dies under set -e.
# Opening it is the only reliable test — see 0e768f5.
_mo_has_tty() { { : < /dev/tty; } 2>/dev/null; }
_mo_read_tty() { local r=""; read -r r < /dev/tty || r=""; printf '%s' "$r"; }

# Every prompt site needs the same refusal, so it lives in one place.
_die_no_git_identity()
{
	die "Cannot prompt for a git identity: no controlling terminal, or input closed." \
		"Pre-configure it before running install:" \
		"git config --global user.name 'Your Name' && git config --global user.email 'you@example.com'"
}

# Asked before anything is written. _install_gitconfig cannot prompt with no
# controlling terminal, and it reached that discovery only after ~/.zshenv and
# ~/.editorconfig were already symlinked — the install died having half
# configured the shell, and only a re-run finished the job. Same condition,
# same message, raised while the machine is still untouched.
_preflight_git_identity()
{
	local n e
	n=$(git config --file "${GITCONFIG}" user.name  2>/dev/null || true)
	e=$(git config --file "${GITCONFIG}" user.email 2>/dev/null || true)
	[[ -n "$n" && -n "$e" ]] && return 0
	{ : < /dev/tty; } 2>/dev/null || _die_no_git_identity
}

# -- Error handling -------------------------------------------------------------

_on_error()
{
	local exit_code=$?
	# `set -E` makes subshells inherit this trap, and a command substitution
	# is a subshell — so a deliberately guarded `out=$(cmd) || die "..."`
	# fired here first and printed a confusing "command failed at line N"
	# above the caller's real message (and "unknown (main)" under the
	# curl-pipe bootstrap, where BASH_SOURCE is not a file). The guard in the
	# caller is what handles a subshell failure; only the top-level shell
	# reports. BASH_SUBSHELL predates the bash 3.2 macOS ships.
	(( BASH_SUBSHELL == 0 )) || return "$exit_code"
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
	command -v "$cmd" &>/dev/null || die "'${cmd}' not found. Install: $(_mo_pkg_hint "${pkg}")"
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
	for pkg in ${missing[@]+"${missing[@]}"}; do
		echo -e "    ${COLOR_RED}•${COLOR_RESET} ${pkg}" >&2
	done
	echo "" >&2
	echo -e "  Install them first, then re-run the installer:" >&2
	echo "" >&2
	echo -e "    ${COLOR_CYAN}$(_mo_pkg_hint ${missing[@]+"${missing[@]}"})${COLOR_RESET}" >&2
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
# Ordered by the YYYYMMDD_HHMMSS suffix in the name, not by mtime: the name
# records when the backup was taken, while mtime is rewritten by copying or
# restoring the file. The suffix is fixed-width, so a lexical compare is
# chronological.
#
# Why both forms: since 2026-05-17 _install_zshrc writes timestamped backups
# (so a re-install doesn't clobber an existing one). Older installs left a
# single .pre-master-oogway file with no timestamp. Restoring needs to find
# either — newest timestamped wins; legacy bare name is the fallback.
# Names any backup left behind. Uninstall restores and removes the newest one
# only; older ones are from earlier installs, and the OLDEST is the file that
# predates master-oogway entirely. Deleting somebody's original on the way out
# is not ours to do — but leaving it silently on disk is how it gets found by
# accident a year later, so say it is there.
_report_leftover_backups()
{
	local _had_nullglob
	shopt -q nullglob && _had_nullglob=true || _had_nullglob=false
	shopt -s nullglob

	# Every base in one call, so the explanation is printed once however many
	# files turn up.
	local -a found=()
	local base b
	for base in "$@"; do
		local -a rest=( "${base}".[0-9]* )
		for b in ${rest[@]+"${rest[@]}"}; do [[ -f "$b" ]] && found+=("$b"); done
	done
	$_had_nullglob || shopt -u nullglob
	(( ${#found[@]} > 0 )) || return 0

	info "Earlier backup(s) left in place — remove them yourself if you no longer want them:"
	for b in ${found[@]+"${found[@]}"}; do info "    ${b}"; done
}

# Back up $1 to $1.pre-master-oogway.<timestamp> if it exists.
# Echoes the backup path, or nothing if the source didn't exist.
_mo_backup()
{
	local src="$1"
	[[ -f "$src" ]] || return 0
	local backup
	backup="${src}.pre-master-oogway.$(date +%Y%m%d_%H%M%S)"
	cp "$src" "$backup"
	# The single place a backup is announced. Three call sites used to repeat
	# this line right after calling us, so every migration logged it twice.
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

	# "${backups[@]}" on an empty array is an unbound-variable error under
	# `set -u` in the bash 3.2 macOS ships (bash 4.4+ made it safe). Without
	# the guard this aborted on the FIRST dotfile, so --uninstall reversed
	# nothing at all. Same idiom as the MO_ORIG_ARGS site below.
	local newest="" candidate
	for candidate in ${backups[@]+"${backups[@]}"}; do
		[[ -f "$candidate" ]] || continue
		[[ -z "$newest" || "$candidate" > "$newest" ]] && newest="$candidate"
	done
	if [[ -n "$newest" ]]; then
		echo "$newest"
		return
	fi
	[[ -f "$base" ]] && echo "$base"
	return 0
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
	local i=1 item rendered
	for item in ${_TODO_ITEMS[@]+"${_TODO_ITEMS[@]}"}; do
		# A multi-line todo is written as an indented string in the source, and
		# that indentation reached the screen verbatim — tabs and all — so the
		# continuation lines landed far to the right of the text they continue.
		# Re-indent them to sit under the first line, past the "N. " prefix.
		rendered=$(printf '%s\n' "$item" | sed '2,$s/^[[:space:]]*/     /')
		echo -e "${COLOR_YELLOW}  ${i}. ${rendered}${COLOR_RESET}"
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

	_MO_MISSING=()

	local dep_file plugin_name raw cmd desc pkg
	for dep_file in "${plugins_dir}"/mo-*/optional-deps.zsh; do
		[[ -f "$dep_file" ]] || continue
		plugin_name="$(basename "$(dirname "$dep_file")")"

		# One pass emits cmd, description and package together, so the three
		# maps the old version kept in step cannot drift apart.
		raw=$(zsh -c '
			source "$1" 2>/dev/null || exit 0
			for k in "${(@k)MO_OPTIONAL_DEPS}"; do
				printf "%s\t%s\t%s\n" "$k" "${MO_OPTIONAL_DEPS[$k]}" "${MO_OPTIONAL_APT[$k]:-$k}"
			done
		' -- "$dep_file" 2>/dev/null) || continue

		while IFS=$'\t' read -r cmd desc pkg; do
			[[ -n "$cmd" ]] || continue
			# command -v is PATH-only; tools in /usr/sbin are invisible to a
			# non-root user on Debian.
			{ command -v "$cmd" &>/dev/null || [[ -x "/usr/sbin/$cmd" ]] || [[ -x "/sbin/$cmd" ]]; } \
				&& continue
			case "$cmd" in
				fd)  command -v fdfind &>/dev/null && continue ;;
				bat) command -v batcat &>/dev/null && continue ;;
			esac
			# Skip tools this platform provides by other means — reporting
			# xclip as missing on macOS, where pbcopy covers it, is noise.
			# "@none:<why>" is that class just as much as "@builtin": the
			# package cannot be brew-installed and the hint beside it says so,
			# so listing it told the user to install what it called needless.
			if _mo_is_macos; then
				case "$(_mo_brew_formula "$pkg")" in
					@builtin|@none:*) continue ;;
				esac
			fi
			_MO_MISSING+=("${plugin_name}"$'\t'"${cmd}"$'\t'"${desc}"$'\t'"${pkg}")
		done <<< "$raw"
	done

	[[ ${#_MO_MISSING[@]} -gt 0 ]]
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

	local record plugin cmd desc pkg last_plugin="" seen=""
	local -a unique_pkgs=()
	for record in ${_MO_MISSING[@]+"${_MO_MISSING[@]}"}; do
		IFS=$'\t' read -r plugin cmd desc pkg <<< "$record"
		if [[ "$plugin" != "$last_plugin" ]]; then
			printf "  ${COLOR_YELLOW}%-20s${COLOR_RESET}  %-12s  %s\n" "$plugin" "$cmd" "$desc"
			last_plugin="$plugin"
		else
			printf "  %-20s  %-12s  %s\n" "" "$cmd" "$desc"
		fi
		# Dedup without an associative array: bash 3.2, which macOS ships, has none.
		case " ${seen} " in
			*" ${pkg} "*) ;;
			*) seen="${seen} ${pkg}"; unique_pkgs+=("$pkg") ;;
		esac
	done

	echo ""
	# "block" is a misnomer by the time this runs. The only caller is at the
	# very bottom of the script, so every dotfile has already been linked and
	# there is nothing left to prevent. It used to print "Or skip them and
	# install without the recommended packages", which reads as though nothing
	# had been installed, and then `exit 1` — reporting failure for an install
	# that had in fact succeeded, so `install.sh && something` never ran the
	# something. Both are now dropped; what differs from "warn" is only the
	# note about silencing this report.
	if [[ "$mode" == "block" ]]; then
		echo -e "  master-oogway is installed. These packages are optional, but"
		echo -e "  recommended for the best experience:"
		echo ""
		echo -e "    ${COLOR_CYAN}$(_mo_pkg_hint ${unique_pkgs[@]+"${unique_pkgs[@]}"})${COLOR_RESET}"
		echo ""
		echo -e "  To skip this report on future runs:"
		echo ""
		if _running_via_pipe; then
			echo -e "    ${COLOR_CYAN}~/.master-oogway/install.sh --no-recommended-packages${COLOR_RESET}"
		else
			echo -e "    ${COLOR_CYAN}./install.sh --no-recommended-packages${COLOR_RESET}"
		fi
		echo ""
	else
		echo -e "  Install recommended packages for the best experience:"
		echo ""
		echo -e "    ${COLOR_CYAN}$(_mo_pkg_hint ${unique_pkgs[@]+"${unique_pkgs[@]}"})${COLOR_RESET}"
		echo ""
	fi
}

# -- Mode detection -------------------------------------------------------------

_SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"

_running_via_pipe()
{
	case "${_SCRIPT_SOURCE}" in
		# platform-lint: allow — matching the shapes a pipe gives $0, not reading /proc.
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

# INSTALL_DIR is spelled "$HOME/.master-oogway", and that is the path an
# update-mode run was invoked through, so both sides of this comparison must
# stay logical. Resolving INSTALL_DIR with `pwd -P` instead made dev mode
# (where ~/.master-oogway is a symlink to the clone) look like update mode and
# pull the developer's working tree, and made a HOME behind a symlink fail the
# comparison so the bootstrap could never reach update mode at all.
_running_from_install_dir()
{
	local dir
	dir=$(_script_dir) || return 1
	[[ "$dir" == "${INSTALL_DIR}" ]]
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
	# Same bash 3.2 empty-array guard: a curl-pipe install passes no flags, so
	# this expansion was fatal on a stock macOS before the shell even started.
	MO_SKIP_PULL=1 exec bash "${INSTALL_DIR}/install.sh" ${MO_ORIG_ARGS[@]+"${MO_ORIG_ARGS[@]}"}
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
	# Guard the expansion: if .gitmodules ever stops matching, an empty array
	# is an unbound-variable error under `set -u` in bash 3.2, and the
	# installer would die here with an obscure message instead of simply
	# having nothing to heal.
	for plugin in ${submodules[@]+"${submodules[@]}"}; do
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
if _running_from_install_dir && [[ "$MO_UNINSTALL" != true ]]; then
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

# Checked here, not 200 lines down: discovering the missing dependency after
# the fact left ~/.master-oogway pointing at the clone and the submodules
# initialised, so an install that failed had still changed the machine. Pipe
# mode has always checked before cloning; dev mode had not.
[[ "$MO_UNINSTALL" == true ]] || _check_oh_my_zsh

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

		if [[ -n "$backup" && -f "$backup" ]]; then
			if [[ ! -e "$home_path" ]]; then
				# our symlink is gone and nothing took its place — restore the original
				cp "$backup" "$home_path"
				rm -f "$backup"
				success "Restored ${home_path} from ${backup} (backup removed)"
			else
				# user put their own file where our symlink was — keep it, but don't
				# leave the pre-install backup orphaned on disk
				rm -f "$backup"
				warn "${home_path} not managed by master-oogway — left as-is, removed stale backup ${backup}"
			fi
		fi

		_report_leftover_backups "${home_path}.pre-master-oogway"
	}

	# .zshrc
	_uninstall_symlinked_file "${ZSHRC}"
	rm -f "${ZSHRC}.upstream-snapshot"

	# .gitconfig — drop the symlink + restore backup; the bundle payload goes too.
	_uninstall_symlinked_file "${GITCONFIG}"
	if [[ -e "${GITCONFIG_BUNDLE}" ]]; then
		rm -f "${GITCONFIG_BUNDLE}"
		success "Removed ${GITCONFIG_BUNDLE}"
	fi

	# .zshenv — drop symlink + restore backup, then remove the managed payload.
	# Done BEFORE the CONF_DIR prompt so restoring the backup isn't undone by it.
	_uninstall_symlinked_file "${HOME}/.zshenv"
	if [[ -e "${HOME}/.zshenv.master-oogway" ]]; then
		rm -f "${HOME}/.zshenv.master-oogway"
		success "Removed ~/.zshenv.master-oogway"
	fi

	# .editorconfig — drop symlink + restore backup. The real file under
	# $CONF_DIR is left for the CONF_DIR prompt below (never force-deleted here).
	_uninstall_symlinked_file "${HOME}/.editorconfig"

	# lan-ssh — reverse 'master-oogway lan-ssh setup': crontab line, ssh_config
	# SendEnv stanza, sshd AcceptEnv drop-in, generated alias file.
	if crontab -l 2>/dev/null | grep -qF "# master-oogway:lan-scan"; then
		crontab -l 2>/dev/null | { grep -vF "# master-oogway:lan-scan" || true; } | crontab -
		success "Removed lan-scan crontab line"
	fi
	if grep -qF "# BEGIN master-oogway:sendenv" "${HOME}/.ssh/config" 2>/dev/null; then
		_mo_sed_inplace '/# BEGIN master-oogway:sendenv/,/# END master-oogway:sendenv/d' "${HOME}/.ssh/config"
		success "Removed SendEnv stanza from ~/.ssh/config"
	fi
	if [[ -f /etc/ssh/sshd_config.d/99-master-oogway-acceptenv.conf ]]; then
		if confirm "Remove sshd AcceptEnv drop-in and reload sshd? (sudo)"; then
			sudo rm -f /etc/ssh/sshd_config.d/99-master-oogway-acceptenv.conf
			# lan-ssh runs on macOS now, so this can no longer assume systemd.
			# launchd starts sshd per connection, so the removal already
			# applies to the next one; kick it only if it happens to be up.
			if _mo_is_macos; then
				sudo launchctl kickstart -k system/com.openssh.sshd 2>/dev/null || true
			else
				# platform-lint: allow — Linux half of the branch above.
				sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd 2>/dev/null || true
			fi
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
			# --force backs the user-owned files up in place, under $CONF_DIR
			# rather than beside the ~/ symlink, so the loop above never sees
			# them and they accumulate across every forced install.
			_report_leftover_backups \
				"${ZSHRC_REAL}.pre-master-oogway" \
				"${ZSHENV_REAL}.pre-master-oogway" \
				"${GITCONFIG_REAL}.pre-master-oogway" \
				"${EDITORCONFIG_REAL}.pre-master-oogway"
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

case "$MO_PLATFORM" in
	linux) success "Linux detected" ;;
	# platform-lint: allow — reporting the detected platform.
	macos) success "macOS detected ($(uname -m))" ;;
	*)     die "Unsupported platform: $(uname -s). master-oogway supports Linux and macOS." ;;
esac

_check_required_packages

# en_US.UTF-8 locale — required for correct terminal rendering and zshrc's
# locale block. Not auto-fixed: update-locale writes /etc/default/locale and
# takes effect only in a new login shell, so the user must run it themselves.
# Captured rather than piped: `grep -q` exits on the first match, and the
# SIGPIPE that gives `locale` makes the whole pipeline fail under
# `set -o pipefail` — reporting the locale as missing when it is present.
# macOS lists 80+ UTF-8 locales, so the early exit is guaranteed there.
_mo_locales="$(locale -a 2>/dev/null || true)"
if ! grep -qiE '^en_US\.(utf-?8|UTF-8)$' <<< "$_mo_locales"; then
	warn "en_US.UTF-8 locale is not generated on this system."
	if _mo_is_macos; then
		# macOS always ships en_US.UTF-8; reaching here means the locale
		# database is genuinely unusual, so there is nothing to generate.
		warn "en_US.UTF-8 not reported by locale -a — unusual on macOS; check your terminal's locale settings"
	else
		# platform-lint: allow — instructions printed only on the Linux branch.
		todo_item "Set up locale (run these commands, then open a new terminal):
	  sudo apt install -y locales
	  sudo sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
	  sudo locale-gen en_US.UTF-8
	  sudo update-locale LANG=en_US.UTF-8"
	fi
else
	success "en_US.UTF-8 locale already generated"
fi

_check_oh_my_zsh
_preflight_git_identity

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
		copy_file "$template" "${EDITORCONFIG_REAL}"
	fi
	_mo_migrate_to_symlink "${HOME}/.editorconfig" "${EDITORCONFIG_REAL}" "$template"

	if ! cmp -s "$template" "${EDITORCONFIG_REAL}"; then
		# shellcheck disable=SC2088  # literal text in a message, not a path
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

	# Opening /dev/tty is the reliable probe, exactly as confirm() explains:
	# `[[ -r /dev/tty ]]` only stats the device node, whose mode is 666, so it
	# passes with no controlling terminal at all. That check was left here when
	# confirm() was fixed, and the read below then failed — under set -u/-e a
	# failed read aborts the script, so the install died here having ALREADY
	# replaced ~/.zshrc and ~/.zshenv, leaving a half-configured shell and a
	# stack line instead of an explanation.
	if [[ -z "$git_name" ]] || [[ -z "$git_email" ]]; then
		{ : < /dev/tty; } 2>/dev/null || _die_no_git_identity
	fi

	# `read` also fails on EOF — Ctrl-D at the prompt, or any driver feeding the
	# installer a fixed number of lines. Same situation, so say the same thing
	# rather than aborting mid-install on an unhandled non-zero status.
	if [[ -z "$git_name" ]]; then
		while [[ -z "$git_name" ]]; do
			_ask "Git user name: "
			read -r git_name < /dev/tty || _die_no_git_identity
		done
	fi
	if [[ -z "$git_email" ]]; then
		while [[ -z "$git_email" ]]; do
			_ask "Git email: "
			read -r git_email < /dev/tty || _die_no_git_identity
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
		# chmod --reference is GNU-only; macOS errors "illegal option -- -"
		# and the ERR trap then kills an upgrade install. Fresh installs never
		# reached this branch, which is why it went unnoticed.
		local _mode
		_mode=$(_mo_stat_mode "${GITCONFIG_REAL}")
		[[ -n "${_mode}" ]] && chmod "${_mode}" "${tmp}"
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

	# Seed a default conf.zsh when none exists. conf.zsh must always exist so the
	# baked DRAGON__PAYLOAD (SSH forwarding) is present even for default-preset
	# users who never ran dragon-configure. Uses the same writer as the regen
	# path below, with no preset (schema defaults).
	if [[ ! -f "${conf_file}" ]]; then
		local _seed_nerd
		_nerd_font_renders && _seed_nerd=true || _seed_nerd=false
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
			# Seed the Nerd Font answer from the machine rather than the schema
			# default. The default is true, and on a machine with no Nerd Font
			# that renders every separator and icon as a tofu box on the very
			# first prompt — the install looks broken when it is not. $3 carries
			# the answer from the bash probe above.
			[[ -n "$3" ]] && _DRAGON_CURRENT[USE_NERD_FONT]="$3"
			_dragon_write_conf ""
		' -- "${themes_dir}" "${conf_file}" "${_seed_nerd}" 2>/dev/null; then
			if [[ "$_seed_nerd" == false ]]; then
				success "dragon theme config seeded (no Nerd Font found — plain separators)"
			else
				success "dragon theme config seeded (default preset)"
			fi
		else
			warn "dragon theme config could not be seeded"
		fi
		# Only plain separators leave the user something to fix.
		if [[ "$_seed_nerd" == false ]]; then
			if _nerd_font_installed; then
				# fc-list can report a font living outside the dirs
				# _nerd_font_family scans, so the name may be empty.
				local _fam
				_fam="$(_nerd_font_family || true)"
				[[ -n "$_fam" ]] && _fam=" ($_fam)"
				todo_item "A Nerd Font is installed${_fam} but your terminal
				  isn't using it, so the prompt was set up with plain separators. Point your
				  terminal's font setting at it — no installer can do that for you — then run
				  'dragon-configure' and answer yes to the font question."
			else
				todo_item "No Nerd Font found, so the prompt was set up with plain
				  separators — nothing will render as an empty box. For the icon prompt,
				  install a Nerd Font:
				    $(_mo_pkg_hint_font)
				  then point your terminal at it in its settings — no installer can do
				  that for you — and run 'dragon-configure', answering yes to the
				  Nerd Font question."
			fi
		fi
		return
	fi

	local conf_bak
	conf_bak="${conf_file}.bak.$(date +%Y%m%d_%H%M%S)"
	cp "${conf_file}" "${conf_bak}"

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
		# An update that changes nothing leaves nothing worth keeping. The
		# backup was written unconditionally, so every re-run dropped another
		# ~23 KB copy next to conf.zsh that differed only in its filename.
		if cmp -s "${conf_bak}" "${conf_file}"; then
			rm -f "${conf_bak}"
			success "dragon theme config already current"
		else
			success "dragon theme config refreshed (backup: ${conf_bak##*/})"
		fi
	else
		# Keep the backup: the file on disk is whatever the failed run left.
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

# Records of missing optional tools: "plugin<TAB>cmd<TAB>desc<TAB>package".
_MO_MISSING=()
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

# Fresh-install call to action — the last thing on screen so it can't be missed.
if [[ "${MO_FIRST_INSTALL}" == true ]]; then
	echo ""
	echo -e "${COLOR_CYAN}╔══════════════════════════════════════════════════════════╗${COLOR_RESET}"
	echo -e "${COLOR_CYAN}║  Next: run these once (from a new terminal)              ║${COLOR_RESET}"
	echo -e "${COLOR_CYAN}╠══════════════════════════════════════════════════════════╣${COLOR_RESET}"
	echo -e "${COLOR_CYAN}║${COLOR_RESET}  Pick your prompt preset:                                ${COLOR_CYAN}║${COLOR_RESET}"
	echo -e "${COLOR_CYAN}║${COLOR_RESET}      ${COLOR_GREEN}master-oogway configure${COLOR_RESET}                             ${COLOR_CYAN}║${COLOR_RESET}"
	echo -e "${COLOR_CYAN}║${COLOR_RESET}  Forward your theme over SSH to other machines:          ${COLOR_CYAN}║${COLOR_RESET}"
	echo -e "${COLOR_CYAN}║${COLOR_RESET}      ${COLOR_GREEN}master-oogway lan-ssh setup${COLOR_RESET}                         ${COLOR_CYAN}║${COLOR_RESET}"
	echo -e "${COLOR_CYAN}╚══════════════════════════════════════════════════════════╝${COLOR_RESET}"
	echo ""
fi

success "dragon installation complete. Open a new terminal to apply changes."
