autoload -Uz add-zsh-hook
_ls_after_cd() {
	[[ -o interactive ]] || return
	local count
	# A glob, not `ls | wc -l`: BSD wc right-pads its count to 8 columns even
	# on stdin, which printed "      45 entries". Counting entries directly is
	# also correct for names containing a newline.
	local -a entries=( *(DN) )
	count=${#entries}
	if (( count > 40 )); then
		echo "${count} entries"
	else
		ls
	fi
}
add-zsh-hook chpwd _ls_after_cd
