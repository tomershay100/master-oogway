# Soft deps for mo-env — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
	[fzf]="fuzzy finder — enables fenv (fuzzy environment variable picker)"
)
typeset -gA MO_OPTIONAL_APT=(
	[fzf]="fzf"
)
