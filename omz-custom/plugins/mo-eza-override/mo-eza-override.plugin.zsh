# Remove this file to use the system ls as-is.

source "${0:h}/requirements.zsh" || return

alias ls="eza -F"   # --hyperlink has a known bug when piping
alias lsa="ls -A"
alias ll="lsa -l --smart-group --time-style=long-iso"
alias l="ls -l --no-user --smart-group --time-style=long-iso"
alias la="l -A"
alias lg="ls --git"
tree() {
	local arg
	local args=()
	for arg in "$@"; do
		[[ "$arg" == "-d" ]] && args+=("-D") || args+=("$arg")
	done
	lg --tree "${args[@]}"
}
