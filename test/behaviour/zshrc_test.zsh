# zshrc.master-oogway — the PATH block runs under two very different scopes.
#
# At login it is sourced at top level. But `soursh` (mo-shell-tools) is a
# FUNCTION — `soursh() { source ~/.zshrc; }` — so a re-source runs the same
# lines inside a function scope, where `typeset` creates a *local*. A bare
# `typeset -U path` there shadows the global with an empty array, and the
# `path=($path ...)` line then rebuilds PATH from nothing but the dirs listed
# on it. Every prefix not hardcoded there vanishes for the whole re-source:
# on macOS that is /opt/homebrew/bin, so brew, bat, eza, fd, rg and nvim all
# went missing and each plugin's requirements.zsh silently refused to load.
# `typeset -g` is the fix — it declares the global explicitly.

local _pathblock _survives
_pathblock=$(command grep -E '^typeset .*path|^path=\(' "$MO_ROOT/zshrc.master-oogway")

# Sourced at top level, as at login: a pre-existing prefix must survive.
_survives=$(zsh -c "
	path=(/opt/custom/bin /usr/bin /bin)
	$_pathblock
	[[ \":\$PATH:\" == *\":/opt/custom/bin:\"* ]] && echo yes || echo no
")
assert_eq "yes" "$_survives" "a login-time source keeps PATH entries it did not hardcode"

# Sourced inside a function, as `soursh` does: same requirement.
_survives=$(zsh -c "
	path=(/opt/custom/bin /usr/bin /bin)
	f() { $_pathblock
		[[ \":\$PATH:\" == *\":/opt/custom/bin:\"* ]] && echo yes || echo no; }
	f
")
assert_eq "yes" "$_survives" "a re-source inside a function keeps PATH entries it did not hardcode"

# And the dedup the block exists for must still work.
_survives=$(zsh -c "
	path=(/usr/bin /usr/bin /bin)
	$_pathblock
	print -r -- \${#path[@]}
")
assert_eq "6" "$_survives" "the block still deduplicates \$path"
