# fman parses `man -k` output, whose shape differs between man-db (Linux,
# "ls (1)  - list") and mandoc (macOS, "ls(1) - list"). The character class
# that matches a page name left out '+', so every C++ toolchain page was
# either dropped or silently truncated: "c++filt (1)" parsed as "filt" and
# fman opened the wrong page, while "g++ (1)" matched nothing and vanished
# from the picker.

_mo_fman_parse_one() {
	zsh -f -c "source ${(q)MO_ROOT}/omz-custom/plugins/mo-search/mo-search.plugin.zsh >/dev/null 2>&1
		[[ -n \$_MO_FMAN_PARSE ]] || exit 1
		print -r -- ${(q)1} | awk \"\$_MO_FMAN_PARSE\"" 2>/dev/null
}

if ! _mo_fman_parse_one 'ls (1) - list' >/dev/null; then
	t_skip "fman parses man -k output" "mo-search did not load (fzf missing)"
else
	assert_eq "1 g++" "$(_mo_fman_parse_one 'g++ (1)              - GNU C++ compiler')" \
		"a name that ends in + is not dropped"

	assert_eq "1 c++filt" "$(_mo_fman_parse_one 'c++filt (1)          - demangle C++ symbols')" \
		"a name with + in the middle is not truncated"

	assert_eq "3 libstdc++" "$(_mo_fman_parse_one 'libstdc++ (3)        - GNU Standard C++ Library')" \
		"a library name ending in ++ survives"

	# Shapes that already worked — the fix must not cost them.
	assert_eq "1 ls" "$(_mo_fman_parse_one 'ls(1) - list directory contents')" \
		"mandoc glues the section to the name"

	assert_eq "1 ls" "$(_mo_fman_parse_one 'ls (1)               - list directory contents')" \
		"man-db separates the section from the name"

	assert_eq "2 fchmod" "$(_mo_fman_parse_one 'chmod, fchmod (2)    - change permissions')" \
		"grouped aliases resolve to the name that owns the section"
fi

unfunction _mo_fman_parse_one
