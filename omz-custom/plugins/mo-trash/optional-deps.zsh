# Soft deps for mo-trash — read by install.sh, never sourced at runtime.
#
# This file used the older `optional_deps=(fzf)` form, which the collector in
# install.sh no longer reads: it iterates ${(@k)MO_OPTIONAL_DEPS}, and on an
# undefined name that expansion fails with "bad math expression: empty string".
# Two consequences, both upstream and on both platforms — the fzf dependency
# was never reported to anyone installing, and every install printed a stray
# [ERR] from the collector's subshell.
typeset -gA MO_OPTIONAL_DEPS=(
	[fzf]="interactive picker for trash-restore"
)
typeset -gA MO_OPTIONAL_APT=(
	[fzf]="fzf"
)
