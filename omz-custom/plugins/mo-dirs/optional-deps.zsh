# Soft deps for mo-dirs — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
	[fzf]="fuzzy finder — enables fcd (fuzzy cd with directory preview)"
)
typeset -gA MO_OPTIONAL_APT=(
	[fzf]="fzf"
)
