_mo_man_open() {
	local readme="$1"
	if command -v bat &>/dev/null; then
		bat --style=plain --language=markdown "$readme"
	elif command -v batcat &>/dev/null; then
		batcat --style=plain --language=markdown "$readme"
	else
		less "$readme"
	fi
}

_mo_man_fzf_pick() {
	local dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
	local plugin readme chosen
	local -a plugins=()
	for plugin in "${dir}"/mo-*/README.md(N); do
		plugins+=("${plugin:h:t}")
	done
	(( ${#plugins[@]} == 0 )) && { echo "mo-man: no mo-* plugins with a README found" >&2; return 1; }
	local preview_cmd="bat --style=plain --language=markdown ${dir}/{}/README.md 2>/dev/null || batcat --style=plain --language=markdown ${dir}/{}/README.md 2>/dev/null || cat ${dir}/{}/README.md"
	chosen=$(printf '%s\n' "${plugins[@]}" | fzf --prompt="mo-man> " --preview="$preview_cmd" --preview-window=right:60%) || return 130
	_mo_man_open "${dir}/${chosen}/README.md"
}

mo-man() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: mo-man [<plugin>]"
		echo "  Open the README of a mo-* plugin."
		echo "  With no argument, opens an fzf picker."
		echo "  Accepts short name (git) or full name (mo-git)."
		echo ""
		echo "Examples:"
		echo "  mo-man          # fzf picker"
		echo "  mo-man git"
		echo "  mo-man mo-files"
		return
	fi

	if [[ $# -eq 0 ]]; then
		command -v fzf &>/dev/null || { echo "mo-man: fzf not installed — provide a plugin name" >&2; return 1; }
		_mo_man_fzf_pick
		return
	fi

	local name="mo-${1#mo-}"
	local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/${name}"
	local readme="${plugin_dir}/README.md"

	if [[ ! -d "$plugin_dir" ]]; then
		echo "mo-man: plugin '${name}' not found in ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/" >&2
		return 1
	fi
	if [[ ! -f "$readme" ]]; then
		echo "mo-man: no README.md for '${name}'" >&2
		return 1
	fi

	_mo_man_open "$readme"
}
