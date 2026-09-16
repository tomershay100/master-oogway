# Remove this file to use the system ls as-is.

# oh-my-zsh does not source $ZSH_CUSTOM/lib; nor does a zshrc seeded before it.
[[ -n ${_MO_PLATFORM_LOADED-} ]] || source "${0:h}/../../lib/platform.zsh"

source "${0:h}/requirements.zsh" || return

# Two upstream eza changes make the obvious `alias ls="eza -F"` unusable, and
# both hit every platform — Ubuntu 24.04 packages 0.18.2, so this is not a
# macOS quirk:
#
#   0.18.0  --classify gained an optional value. Written as a bare -F it
#           swallows the next token unless that token looks like a flag, so
#           `ls somedir` dies with:
#             error: invalid value 'somedir' for '--classify [<WHEN>]'
#           Binding the value with = keeps the path positional.
#
#   0.23.0  eza reads path names from stdin when stdin is not a TTY and no
#           path operand was given. In a script, a pipeline or a preview pane
#           that means `ls` silently lists nothing — or blocks forever waiting
#           on a pipe that never closes.
#
# So: bind the value, and always pass an operand. `ls` is a function rather
# than an alias because deciding whether an operand is present needs to look
# at the arguments.
# Options whose value is a separate word. Treating that value as a path was
# the bug in the first version of this function: `ls -L 1` read "1" as the
# operand, so no "." was appended and eza fell back to reading stdin — which
# in a pipeline or preview pane lists nothing, or blocks.
typeset -ga _MO_EZA_VALUE_OPTS=(
	-L --level -I --ignore-glob -s --sort -t --time
	--time-style --color --colour --absolute --git-repos
)

_mo_eza_ls() {
	local arg
	local -i want_value=0 have_operand=0 seen_ddash=0
	for arg in "$@"; do
		if (( seen_ddash )); then have_operand=1; break; fi
		if (( want_value )); then want_value=0; continue; fi
		if [[ "$arg" == "--" ]]; then seen_ddash=1; continue; fi
		if [[ "$arg" == -* ]]; then
			# --opt=value carries its own value; --opt may take the next word.
			[[ "$arg" != *=* ]] && (( ${_MO_EZA_VALUE_OPTS[(Ie)$arg]} )) && want_value=1
			continue
		fi
		have_operand=1
		break
	done
	if (( have_operand )); then
		eza --classify=auto "$@"
	else
		# An explicit operand is what stops eza reading path names from stdin.
		eza --classify=auto "$@" .
	fi
}

alias ls="_mo_eza_ls"   # --hyperlink has a known bug when piping
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
