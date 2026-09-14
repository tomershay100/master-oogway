source "$MO_ROOT/omz-custom/lib/platform.zsh"

# mo-trash had no behavioural coverage at all — only "it parses" and "it has a
# README" — while carrying a bug that could restore the wrong file to the wrong
# path. These exercise the real tool against a sandbox, never the user's trash.

# The plugin must be sourced from a FILE, not a `zsh -c` string: `rm` is an
# alias, and zsh fixes alias expansion at parse time, so a one-shot -c string
# would run /bin/rm and really delete the fixtures.
_mo_trash_t() {
	local script="$1"; shift
	local body="$MO_TRASH_SANDBOX/case.zsh"
	{
		print -r -- 'setopt EXTENDED_GLOB'
		print -r -- "export ZSH_CUSTOM='$MO_ROOT/omz-custom'"
		print -r -- "export MO_TRASH_INDEX='$MO_TRASH_SANDBOX/index.tsv'"
		print -r -- "for f in '$MO_ROOT'/omz-custom/lib/*.zsh(#qN); do source \$f; done"
		print -r -- "source '$MO_ROOT/omz-custom/plugins/mo-trash/mo-trash.plugin.zsh' 2>/dev/null"
		print -r -- "$script"
	} > "$body"
	zsh "$body" 2>&1
}

if _mo_is_macos && [[ -n "$(_mo_trash_tool)" ]]; then
	typeset -g MO_TRASH_SANDBOX=$(mktemp -d)
	typeset -ga _MO_TRASHED=()

	# -- the index records where a file came from -----------------------------
	mkdir -p "$MO_TRASH_SANDBOX/deep"
	print -- one > "$MO_TRASH_SANDBOX/deep/mo-t-$$-a.txt"
	_mo_trash_t "rm '$MO_TRASH_SANDBOX/deep/mo-t-$$-a.txt'" >/dev/null
	_MO_TRASHED+=("mo-t-$$-a.txt")

	assert_ok "rm moves the file out of the working tree" \
		test ! -e "$MO_TRASH_SANDBOX/deep/mo-t-$$-a.txt"
	assert_contains "$(<$MO_TRASH_SANDBOX/index.tsv)" "deep/mo-t-$$-a.txt" \
		"the index records the original absolute path"

	# -- a colliding basename must not overwrite the first entry --------------
	# /usr/bin/trash renames on collision ("f.txt" -> "f.txt 00-32-27.txt").
	# Guessing the landed name made the second index entry point at the first
	# file, so restoring it would have written the wrong content.
	mkdir -p "$MO_TRASH_SANDBOX/x" "$MO_TRASH_SANDBOX/y"
	print -- FROM-X > "$MO_TRASH_SANDBOX/x/mo-t-$$-c.txt"
	print -- FROM-Y > "$MO_TRASH_SANDBOX/y/mo-t-$$-c.txt"
	_mo_trash_t "rm '$MO_TRASH_SANDBOX/x/mo-t-$$-c.txt'; rm '$MO_TRASH_SANDBOX/y/mo-t-$$-c.txt'" >/dev/null

	local -a landed=( ${(f)"$(awk -F'\t' -v n="mo-t-$$-c.txt" '$3 ~ n {print $2}' "$MO_TRASH_SANDBOX/index.tsv")"} )
	_MO_TRASHED+=("${landed[@]}")
	assert_true "a collision produces two distinct index entries" "${#landed} == 2"
	assert_true "the two entries name different files in the trash" \
		"$([[ "${landed[1]}" != "${landed[2]}" ]] && print 1 || print 0)"
	if (( ${#landed} == 2 )); then
		assert_eq "FROM-X" "$(<"$(_mo_trash_dir)/${landed[1]}")" \
			"the first entry points at the first file's content"
		assert_eq "FROM-Y" "$(<"$(_mo_trash_dir)/${landed[2]}")" \
			"the second entry points at the second file's content"
	fi

	# -- \rm must bypass, not trash -------------------------------------------
	# Backslash suppresses alias expansion only. When rm was a function the
	# documented escape hatch silently trashed the file instead.
	print -- bypass > "$MO_TRASH_SANDBOX/mo-t-$$-b.txt"
	_mo_trash_t "\\rm '$MO_TRASH_SANDBOX/mo-t-$$-b.txt'" >/dev/null
	assert_ok "\\rm really deletes" test ! -e "$MO_TRASH_SANDBOX/mo-t-$$-b.txt"
	assert_ok "\\rm does not reach the trash" test ! -e "$(_mo_trash_dir)/mo-t-$$-b.txt"

	# -- the help text must survive zsh's echo --------------------------------
	# "\\rm" reaches the builtin echo as \r and overwrote the line.
	assert_contains "$(_mo_trash_t 'rm -h')" '\rm' "rm -h prints the bypass literally"
	assert_not_contains "$(_mo_trash_t 'rm -h')" $'\r' "rm -h emits no carriage return"

	# -- an unreadable trash must not be reported as an empty one -------------
	# macOS blocks readdir on ~/.Trash without Full Disk Access, which made
	# trash-prune and trash-empty claim success while doing nothing.
	if ! _mo_trash_dir_readable "$(_mo_trash_dir)"; then
		assert_contains "$(_mo_trash_t 'trash-prune 3650')" "cannot read" \
			"trash-prune reports a blocked read instead of 'nothing to prune'"
		assert_not_contains "$(_mo_trash_t 'trash-list')" "trash is empty" \
			"trash-list does not call a blocked read an empty trash"
	fi
	# Whatever the permission state, list must still see our own deletions.
	assert_contains "$(_mo_trash_t 'trash-list')" "mo-t-$$-a.txt" \
		"trash-list serves entries from the index"

	# -- a filename that starts with a dash ------------------------------------
	# Every arg matching -* was dropped as a flag, including the POSIX
	# end-of-options separator, so `rm -- -x.txt` reached the trash tool with
	# no targets at all and answered "rm: no files given". There was no way to
	# trash such a file: \rm bypasses to /bin/rm and deletes it for real.
	print -- dash > "$MO_TRASH_SANDBOX/-mo-t-$$-d.txt"
	_mo_trash_t "cd '$MO_TRASH_SANDBOX' && rm -- '-mo-t-$$-d.txt'" >/dev/null
	_MO_TRASHED+=("-mo-t-$$-d.txt")
	assert_ok "rm -- trashes a file whose name begins with a dash" \
		test ! -e "$MO_TRASH_SANDBOX/-mo-t-$$-d.txt"

	# The separator itself must not become a target.
	assert_not_contains "$(_mo_trash_t 'rm --')" "No such file" \
		"a bare -- is not treated as a filename"

	# -- tab and newline are legal in filenames; the index is line-oriented --
	# Both fields were written verbatim, so one such name split a record into
	# junk rows: the file was trashed but could never be listed or restored.
	# The index now stores both paths with \\, \t and \n escaped, and every
	# reader decodes only when it touches the filesystem.
	local _nl=$'\n' _tab=$'\t'
	mkdir -p "$MO_TRASH_SANDBOX/odd"
	print -- NL   > "$MO_TRASH_SANDBOX/odd/mo-t-$$-n${_nl}ame.txt"
	print -- TAB  > "$MO_TRASH_SANDBOX/odd/mo-t-$$-t${_tab}ab.txt"
	print -- BS   > "$MO_TRASH_SANDBOX/odd/mo-t-$$-b\\tslash.txt"
	_mo_trash_t "rm -- \"$MO_TRASH_SANDBOX/odd/\"mo-t-$$-*(N)" >/dev/null
	local -a odd_rows=( ${(f)"$(grep -c "mo-t-$$-[ntb]" "$MO_TRASH_SANDBOX/index.tsv")"} )
	assert_eq 3 "${odd_rows[1]}" "tab, newline and backslash names each take exactly one index row"
	assert_eq 0 "$(awk -F'\t' 'NF != 3' "$MO_TRASH_SANDBOX/index.tsv" | wc -l | tr -d ' ')" \
		"every index row still has three fields"

	local _enc_nl="mo-t-$$-n\\name.txt" _enc_tab="mo-t-$$-t\\tab.txt" _enc_bs="mo-t-$$-b\\\\tslash.txt"
	assert_eq "${MO_TRASH_SANDBOX:a}/odd/mo-t-$$-n${_nl}ame.txt" \
		"$(_mo_trash_t "_mo_trash_decode \"\$(_mo_trash_lookup '$_enc_nl')\"; print -rn -- \$REPLY")" \
		"lookup by escaped name decodes to the real original path (newline)"
	assert_eq "${MO_TRASH_SANDBOX:a}/odd/mo-t-$$-t${_tab}ab.txt" \
		"$(_mo_trash_t "_mo_trash_decode \"\$(_mo_trash_lookup '$_enc_tab')\"; print -rn -- \$REPLY")" \
		"lookup by escaped name decodes to the real original path (tab)"
	assert_eq "${MO_TRASH_SANDBOX:a}/odd/mo-t-$$-b\\tslash.txt" \
		"$(_mo_trash_t "_mo_trash_decode \"\$(_mo_trash_lookup '$_enc_bs')\"; print -rn -- \$REPLY")" \
		"a literal backslash-t in a name is not decoded as a tab"
	local _list; _list="$(_mo_trash_t 'trash-list')"
	assert_contains "$_list" "$_enc_nl" \
		"trash-list shows a newline name on one line, escaped"
	assert_contains "$_list" "odd/$_enc_nl" \
		"trash-list shows a newline in the ORIGINAL column escaped too"
	assert_eq 1 "$(print -r -- "$_list" | grep -cF "$_enc_nl")" \
		"a newline-named file takes exactly one trash-list row"
	assert_eq 3 "$(_mo_trash_t "_mo_trash_names | grep -c 'mo-t-$$-[ntb]'")" \
		"_mo_trash_names lists the three odd names, one per line"
	local _odd
	for _odd in "mo-t-$$-n${_nl}ame.txt" "mo-t-$$-t${_tab}ab.txt" "mo-t-$$-b\\tslash.txt"; do
		_MO_TRASHED+=("$_odd")
	done

	# -- a symlink is trashed as a link, not as its target --------------------
	# ${f:A} resolved the link, so `rm link` moved the TARGET — a whole
	# directory, if it pointed at one — to the trash and left the link dangling.
	mkdir -p "$MO_TRASH_SANDBOX/tgt-$$"
	print -- keep > "$MO_TRASH_SANDBOX/tgt-$$/kept.txt"
	ln -s "$MO_TRASH_SANDBOX/tgt-$$" "$MO_TRASH_SANDBOX/mo-t-$$-link"
	_mo_trash_t "rm '$MO_TRASH_SANDBOX/mo-t-$$-link'" >/dev/null
	_MO_TRASHED+=("mo-t-$$-link")
	assert_ok "rm on a symlink removes the link" test ! -L "$MO_TRASH_SANDBOX/mo-t-$$-link"
	assert_ok "rm on a symlink leaves the target alone" test -f "$MO_TRASH_SANDBOX/tgt-$$/kept.txt"

	# A dangling link is accepted by rm, so the index must not hide it: -e is
	# false for it, and compaction used to drop its row.
	ln -s "/nonexistent/mo-t-$$" "$MO_TRASH_SANDBOX/mo-t-$$-dangling"
	_mo_trash_t "rm '$MO_TRASH_SANDBOX/mo-t-$$-dangling'" >/dev/null
	_MO_TRASHED+=("mo-t-$$-dangling")
	assert_contains "$(_mo_trash_t '_mo_trash_names')" "mo-t-$$-dangling" \
		"a trashed dangling symlink is still listed from the index"

	# -- lookup must compare names as strings ---------------------------------
	# awk's == compared "01" and "1" as numbers, so restore put a file back at
	# another file's original path.
	mkdir -p "$MO_TRASH_SANDBOX/n1" "$MO_TRASH_SANDBOX/n2"
	print -- a > "$MO_TRASH_SANDBOX/n1/01"
	print -- b > "$MO_TRASH_SANDBOX/n2/1"
	_mo_trash_t "rm '$MO_TRASH_SANDBOX/n1/01'; rm '$MO_TRASH_SANDBOX/n2/1'" >/dev/null
	local -a _num=( ${(f)"$(awk -F'\t' -v s="$MO_TRASH_SANDBOX/n" '$3 ~ s {print $2}' "$MO_TRASH_SANDBOX/index.tsv")"} )
	_MO_TRASHED+=("${_num[@]}")
	assert_contains "$(_mo_trash_t "_mo_trash_lookup '${_num[1]}'")" "/n1/01" \
		"lookup of the name that landed for 01 does not return 1's path"

	# -- clean up: only the files this test created ---------------------------
	local _n
	for _n in "${_MO_TRASHED[@]}"; do
		[[ -n "$_n" ]] && command rm -rf -- "$(_mo_trash_dir)/$_n"
	done
	command rm -rf "$MO_TRASH_SANDBOX"
	unset MO_TRASH_SANDBOX _MO_TRASHED
fi
