# oh-my-zsh does not source $ZSH_CUSTOM/lib; nor does a zshrc seeded before it.
[[ -n ${_MO_PLATFORM_LOADED-} ]] || source "${0:h}/../../lib/platform.zsh"

source "${0:h}/requirements.zsh" || return

# Homebrew helpers. Arch-aware via _mo_brew_prefix, so the same config works on
# Apple Silicon (/opt/homebrew) and Intel (/usr/local).

_mo_brew_need_fzf() {
	command -v fzf &>/dev/null && return 0
	echo "${1}: fzf not installed (try: brew install fzf)" >&2
	return 1
}

bup() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: bup"
		echo "  Update Homebrew, upgrade all formulae and casks, then clean up."
		return
	fi
	print -P "%F{cyan}==> brew update%f"    && brew update    || return 1
	print -P "%F{cyan}==> brew upgrade%f"   && brew upgrade   || return 1
	print -P "%F{cyan}==> brew cleanup%f"   && brew cleanup   || return 1
	print -P "%F{green}%BUP TO DATE ✓%b%f"
}

bi() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: bi [search-term]"
		echo "  Fuzzy-pick formulae and casks to install. TAB selects several."
		return
	fi
	_mo_brew_need_fzf bi || return 1
	local -a picks
	picks=( ${(f)"$(
		{ brew formulae; brew casks } 2>/dev/null \
			| fzf -m --query="${1:-}" --height=60% --reverse \
				  --prompt="install> " \
				  --preview 'brew info {} 2>/dev/null | head -40'
	)"} )
	(( ${#picks} )) || return 0
	brew install "${picks[@]}"
}

bun() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: bun"
		echo "  Fuzzy-pick installed packages to uninstall. TAB selects several."
		return
	fi
	_mo_brew_need_fzf bun || return 1
	local -a picks
	picks=( ${(f)"$(
		brew list --formula --cask 2>/dev/null \
			| fzf -m --height=60% --reverse --prompt="uninstall> " \
				  --preview 'brew info {} 2>/dev/null | head -40'
	)"} )
	(( ${#picks} )) || return 0
	brew uninstall "${picks[@]}"
}

bs() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
		echo "Usage: bs <term>"
		echo "  Search formulae and casks; shows full info for the match you pick."
		return
	fi
	local -a hits
	hits=( ${(f)"$(brew search "$@" 2>/dev/null | command grep -v '^==>' | command grep -v '^$')"} )
	(( ${#hits} )) || { echo "bs: no matches for '$*'"; return 1; }
	if command -v fzf &>/dev/null; then
		local pick
		pick=$(printf '%s\n' "${hits[@]}" | fzf --height=60% --reverse \
			--prompt="info> " --preview 'brew info {} 2>/dev/null | head -40') || return 130
		[[ -n "$pick" ]] && brew info "$pick"
	else
		printf '%s\n' "${hits[@]}"
	fi
}

bl() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: bl"
		echo "  Browse top-level packages (brew leaves) with their dependencies."
		return
	fi
	if command -v fzf &>/dev/null; then
		brew leaves 2>/dev/null | fzf --height=60% --reverse --prompt="leaves> " \
			--preview 'echo "── deps ──"; brew deps --tree {} 2>/dev/null | head -30
echo; echo "── used by ──"; brew uses --installed {} 2>/dev/null | head -10'
	else
		brew leaves
	fi
}

bout() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: bout"
		echo "  Show outdated packages."
		return
	fi
	brew outdated --verbose
}
