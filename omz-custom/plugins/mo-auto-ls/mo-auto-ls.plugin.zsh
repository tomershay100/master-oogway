autoload -Uz add-zsh-hook

# (( )) recursively evaluates variable contents, so a non-numeric threshold
# (e.g. 'x') makes zsh look up ANOTHER variable named 'x' instead of failing
# cleanly. Validate once at load time rather than in the hook, which fires
# on every cd.
if [[ -n ${MO_AUTO_LS_THRESHOLD-} && ! $MO_AUTO_LS_THRESHOLD =~ ^[0-9]+$ ]]; then
	echo "mo-auto-ls: MO_AUTO_LS_THRESHOLD must be a positive integer, got '${MO_AUTO_LS_THRESHOLD}' — falling back to 40" >&2
	unset MO_AUTO_LS_THRESHOLD
fi

# eval lets the default 'ls' resolve through aliases (e.g. mo-eza-override)
# and word-splits multi-word values like 'ls -la' the same as a typed command.
_ls_after_cd() {
	[[ -o interactive ]] || return
	local count
	# A glob, not `ls | wc -l`: BSD wc right-pads its count to 8 columns even
	# on stdin, which printed "      45 entries". Counting entries directly is
	# also correct for names containing a newline.
	local -a entries=( *(DN) )
	count=${#entries}
	if (( count > ${MO_AUTO_LS_THRESHOLD:-40} )); then
		echo "${count} entries"
	else
		eval "${MO_AUTO_LS_COMMAND:-ls}"
	fi
}
add-zsh-hook chpwd _ls_after_cd
