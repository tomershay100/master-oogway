# install.sh mirrors _mo_pkg_hint in bash, because it runs before any zsh lib
# is sourced. The zsh original in lib/platform.zsh was fixed to parenthesise
# its notes and print a shared note once — the hint is displayed under
# "Install recommended packages" as a line to paste, and
# "; macOS uses pbcopy/pbpaste" is not a command. The bash mirror kept the old
# "; " join and no de-duplication, so the installer printed the very line the
# other fix exists to prevent. test/behaviour/platform_commands_test.zsh
# asserts this for the zsh half; this is the same assertion for the bash half.

if [[ "$OSTYPE" != darwin* ]]; then
	t_skip "install.sh's _mo_pkg_hint formats notes like the zsh original" \
		"both halves only branch this way on macOS"
else
	_mo_install_hint() {
		local harness="$_MO_HINT_TMP/harness.sh"
		{
			print -r -- '#!/usr/bin/env bash'
			print -r -- 'set -Eeuo pipefail'
			print -r -- 'MO_PLATFORM=macos'
			command grep '^_mo_is_macos()' "$MO_ROOT/install.sh"
			awk '/^_mo_brew_formula\(\)/,/^}$/' "$MO_ROOT/install.sh"
			awk '/^_mo_pkg_hint\(\)/,/^}$/'     "$MO_ROOT/install.sh"
			print -r -- "_mo_pkg_hint $*"
		} > "$harness"
		bash "$harness" 2>&1
	}

	typeset -g _MO_HINT_TMP="$(mktemp -d "${TMPDIR:-/tmp}/mo-hint.XXXXXX")"

	assert_not_contains "$(_mo_install_hint nmap xclip)" "; macOS" \
		"notes are not appended as if they were shell commands"

	# Counted per occurrence, not per line: the whole hint is one line, so
	# `grep -c` would report 1 however many times the note is repeated.
	assert_eq 1 "$(_mo_install_hint xclip wl-clipboard | grep -o 'pbcopy' | wc -l | tr -d ' ')" \
		"a note shared by two packages is printed once"

	# The half that must keep working: a plain formula list is still a
	# command the user can paste verbatim.
	assert_eq "brew install nmap fzf" "$(_mo_install_hint nmap fzf)" \
		"formulae alone still produce a bare brew command"

	rm -rf "$_MO_HINT_TMP"
	unset _MO_HINT_TMP
	unfunction _mo_install_hint
fi
