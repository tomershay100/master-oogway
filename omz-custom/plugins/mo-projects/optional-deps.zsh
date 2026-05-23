# Soft deps for mo-projects — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
    [fzf]="fuzzy finder — enables proj (interactive project picker)"
)
typeset -gA MO_OPTIONAL_APT=(
    [fzf]="fzf"
)
