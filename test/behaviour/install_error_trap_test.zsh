# install.sh runs under `set -Eeuo pipefail`, and -E makes subshells inherit
# the ERR trap. A command substitution is a subshell, so a deliberately guarded
#
#   out=$(git pull ...) || die "git pull failed: ..."
#
# fired the trap *inside* the substitution before the guard could run. The user
# saw two [ERR] lines: first a confusing "command failed (exit 1) at line N"
# naming an internal line number, then the real message. Under the curl-pipe
# bootstrap the first one read "unknown (main)", since BASH_SOURCE is not a
# file there.
#
# Only the top-level shell should report; the guard in the caller is what
# handles a subshell failure.

_mo_trap_output() {
	local harness="$_MO_TRAP_TMP/harness.sh"
	{
		print -r -- '#!/usr/bin/env bash'
		print -r -- 'set -Eeuo pipefail'
		print -r -- 'COLOR_RESET="" COLOR_RED=""'
		command grep '^die()' "$MO_ROOT/install.sh"
		awk '/^_on_error\(\)$/,/^}$/' "$MO_ROOT/install.sh"
		command grep "^trap '_on_error" "$MO_ROOT/install.sh"
		# The shape every guarded git call in install.sh uses.
		print -r -- 'out=$(false) || die "the real message"'
	} > "$harness"
	# bash 3.2 is what macOS ships and what install.sh must survive.
	/bin/bash "$harness" 2>&1 >/dev/null
}

typeset -g _MO_TRAP_TMP="$(mktemp -d "${TMPDIR:-/tmp}/mo-trap.XXXXXX")"

assert_eq 1 "$(_mo_trap_output | grep -c '\[ERR\]')" \
	"a guarded command substitution reports one error, not two"

assert_contains "$(_mo_trap_output)" "the real message" \
	"the error the caller wrote is the one that survives"

assert_not_contains "$(_mo_trap_output)" "command failed" \
	"the trap does not narrate an internal line number over the real message"

rm -rf "$_MO_TRAP_TMP"
unset _MO_TRAP_TMP
unfunction _mo_trap_output
