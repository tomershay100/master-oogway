autoload -Uz add-zsh-hook
_ls_after_cd() {
	[[ -o interactive ]] || return
	local count
	count=$(ls -1A | wc -l)
	if (( count > 40 )); then
		echo "${count} entries"
	else
		ls
	fi
}
add-zsh-hook chpwd _ls_after_cd
