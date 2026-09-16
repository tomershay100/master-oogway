# Soft deps for mo-brew — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
	[fzf]="fuzzy pickers in bi, bun, bs and bl"
)
typeset -gA MO_OPTIONAL_APT=(
	[fzf]="fzf"
)
