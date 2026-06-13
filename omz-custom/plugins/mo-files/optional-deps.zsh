# Soft deps for mo-files — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
	[fzf]="fuzzy finder — enables fp (fuzzy file picker with preview)"
)
typeset -gA MO_OPTIONAL_APT=(
	[fzf]="fzf"
)
