# Remove this file to restore plain (uncolored) output for these commands.
#
# Every alias is guarded, because an unguarded one replaces a working command
# with a broken one:
#
#   ip     Linux-only. macOS has no `ip` at all.
#   dmesg  Linux-only in the sense that matters — macOS ships a BSD dmesg that
#          takes no --color and answers "usage: sudo dmesg" to the flag.
#   diff   BSD diff gained --color in macOS 13; older releases have not.
#   grep   supported by both GNU and BSD grep.
#
# On Linux the guards are no-ops beyond a minimal container missing a tool.

# True when $1 exists and accepts --color. Probed by running it: an option
# error shows up as a usage message, which exit status alone does not reveal
# (BSD dmesg rejects the flag and still exits 0, while `grep -q` supports it
# and exits 1 on no match).
# oh-my-zsh does not source $ZSH_CUSTOM/lib; nor does a zshrc seeded before it.
[[ -n ${_MO_PLATFORM_LOADED-} ]] || source "${0:h}/../../lib/platform.zsh"

_mo_colorize_supports() {
	local cmd="$1"; shift
	command -v "$cmd" &>/dev/null || return 1
	local out
	out=$("$cmd" --color=auto "$@" 2>&1 </dev/null)
	[[ "$out" == *"usage:"*        || "$out" == *"Usage:"*             ]] && return 1
	[[ "$out" == *"illegal option"* || "$out" == *"unknown option"*    ]] && return 1
	[[ "$out" == *"unrecognized option"* || "$out" == *"invalid option"* ]] && return 1
	return 0
}

# Probe every candidate on every platform, as upstream did.
#
# An earlier version of this file kept the probe only on macOS and used a bare
# `command -v` on Linux, to save four subprocesses at shell start. That traded
# correctness for startup time, against this file's own header: GNU diff gained
# --color in 3.4 (2016), so RHEL 7 and Debian jessie ship one that has not, and
# busybox grep has no --color at all. On those systems `command -v` succeeds
# and the alias replaces a working command with a broken one — which is exactly
# what the probe exists to prevent.
_mo_colorize_supports diff /dev/null /dev/null && alias diff="diff --color=auto"

for _mo_c in grep egrep fgrep; do
	_mo_colorize_supports "$_mo_c" -q x /dev/null && alias "$_mo_c=$_mo_c --color=auto"
done
unset _mo_c

# Linux-only tools; probing them on macOS would alias a command that cannot
# take the flag.
if _mo_is_linux; then
	for _mo_c in ip dmesg; do
		command -v "$_mo_c" &>/dev/null && alias "$_mo_c=$_mo_c --color=auto"
	done
	unset _mo_c
fi

unfunction _mo_colorize_supports
