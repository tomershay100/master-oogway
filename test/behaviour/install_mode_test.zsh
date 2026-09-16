# install.sh picks its mode from _running_from_install_dir: true means "I am
# ~/.master-oogway/install.sh" (update — git pull), false means "I am a clone
# somewhere else" (dev — symlink ~/.master-oogway at me).
#
# It compared the script's logical directory against `pwd -P` of INSTALL_DIR,
# mixing logical and physical paths, and got both answers wrong the moment a
# symlink was involved:
#
#   dev mode      ~/.master-oogway is a symlink TO the clone, so both sides
#                 resolved to the clone and every re-run of ./install.sh ran
#                 `git pull` on the developer's working tree — fatal on a
#                 branch with no upstream.
#   symlinked HOME  the two sides disagreed, so the curl-pipe bootstrap cloned,
#                 re-exec'd, was misread as dev mode and died with
#                 "~/.master-oogway exists and is not a symlink" on every try.
#
# Both sides must be logical: INSTALL_DIR is spelled "$HOME/.master-oogway",
# and that is exactly the path the update-mode script was invoked through.

_mo_install_mode() {
	local sandbox="$1" script_source="$2" home="$3"
	local harness="$sandbox/harness.sh"
	{
		print -r -- '#!/usr/bin/env bash'
		print -r -- 'set -Eeuo pipefail'
		print -r -- "HOME=${(q)home}"
		print -r -- 'readonly INSTALL_DIR="${HOME}/.master-oogway"'
		print -r -- "_SCRIPT_SOURCE=${(q)script_source}"
		awk '/^_script_dir\(\)$/,/^}$/' "$MO_ROOT/install.sh"
		awk '/^_running_from_install_dir\(\)$/,/^}$/' "$MO_ROOT/install.sh"
		print -r -- 'if _running_from_install_dir; then echo update; else echo dev; fi'
	} > "$harness"
	bash "$harness" 2>&1
}

# The scratchpad is a physical path, so the plain cases carry no accidental
# symlink of their own.
typeset -g _MO_IM_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mo-install-mode.XXXXXX")"
_MO_IM_ROOT="${_MO_IM_ROOT:A}"

# -- plain layout: a real ~/.master-oogway, run from inside it -----------------
mkdir -p "$_MO_IM_ROOT/plain/home/.master-oogway"
: > "$_MO_IM_ROOT/plain/home/.master-oogway/install.sh"
assert_eq update \
	"$(_mo_install_mode "$_MO_IM_ROOT/plain" \
		"$_MO_IM_ROOT/plain/home/.master-oogway/install.sh" \
		"$_MO_IM_ROOT/plain/home")" \
	"running from a real ~/.master-oogway is update mode"

# -- dev layout: ~/.master-oogway is a symlink to the clone --------------------
mkdir -p "$_MO_IM_ROOT/dev/home" "$_MO_IM_ROOT/dev/clone"
: > "$_MO_IM_ROOT/dev/clone/install.sh"
ln -s "$_MO_IM_ROOT/dev/clone" "$_MO_IM_ROOT/dev/home/.master-oogway"
assert_eq dev \
	"$(_mo_install_mode "$_MO_IM_ROOT/dev" \
		"$_MO_IM_ROOT/dev/clone/install.sh" \
		"$_MO_IM_ROOT/dev/home")" \
	"running from the clone a symlinked ~/.master-oogway points at is dev mode"

# -- symlinked HOME: the update-mode script must still know itself ------------
mkdir -p "$_MO_IM_ROOT/link/real/.master-oogway"
ln -s "$_MO_IM_ROOT/link/real" "$_MO_IM_ROOT/link/home"
: > "$_MO_IM_ROOT/link/real/.master-oogway/install.sh"
assert_eq update \
	"$(_mo_install_mode "$_MO_IM_ROOT/link" \
		"$_MO_IM_ROOT/link/home/.master-oogway/install.sh" \
		"$_MO_IM_ROOT/link/home")" \
	"a HOME behind a symlink is still update mode"

rm -rf "$_MO_IM_ROOT"
unset _MO_IM_ROOT
unfunction _mo_install_mode
