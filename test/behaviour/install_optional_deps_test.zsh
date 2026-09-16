# The optional-dep report tells the user which recommended packages are
# missing. On macOS a whole class of them cannot be installed and does not need
# to be: xclip, wl-clipboard, xsel, xdg-utils, iproute2 and trash-cli all map
# to "@none:<why>" because pbcopy, open(1), ifconfig and /usr/bin/trash already
# cover them. The filter skipped only "@builtin", so every one of those was
# still reported as missing — and the hint beside it read "macOS uses
# pbcopy/pbpaste — no install needed", telling the user to install a package
# while explaining that they should not.

if [[ "$OSTYPE" != darwin* ]]; then
	t_skip "install.sh does not report platform-supplied packages as missing" \
		"the filter under test is macOS-only"
else
	_mo_optdeps_report() {
		local harness="$1/harness.sh"
		{
			print -r -- '#!/usr/bin/env bash'
			print -r -- 'set -Eeuo pipefail'
			print -r -- 'MO_PLATFORM=macos'
			command grep '^_mo_is_macos()' "$MO_ROOT/install.sh"
			awk '/^_mo_brew_formula\(\)/,/^}$/'          "$MO_ROOT/install.sh"
			awk '/^_collect_missing_optionals\(\)/,/^}$/' "$MO_ROOT/install.sh"
			print -r -- "INSTALL_DIR=${(q)MO_ROOT}"
			print -r -- '_MO_MISSING=()'
			print -r -- '_collect_missing_optionals || true'
			# Report only the packages this platform supplies by other means.
			print -r -- 'for e in ${_MO_MISSING[@]+"${_MO_MISSING[@]}"}; do'
			print -r -- '  pkg="${e##*$'"'"'\t'"'"'}"'
			print -r -- '  case "$(_mo_brew_formula "$pkg")" in @none:*) echo "$pkg" ;; esac'
			print -r -- 'done'
		} > "$harness"
		bash "$harness" 2>&1
	}

	typeset -g _MO_OD_TMP="$(mktemp -d "${TMPDIR:-/tmp}/mo-optdeps.XXXXXX")"
	assert_eq "" "$(_mo_optdeps_report "$_MO_OD_TMP")" \
		"no package macOS supplies by other means is reported as missing"
	rm -rf "$_MO_OD_TMP"
	unset _MO_OD_TMP
	unfunction _mo_optdeps_report
fi
