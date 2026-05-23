# Soft deps for mo-files — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
    [fzf]="fuzzy finder — enables fp (fuzzy file picker with preview)"
    [bat]="syntax-highlighted preview inside fp"
)
typeset -gA MO_OPTIONAL_APT=(
    [fzf]="fzf"
    [bat]="bat"
)
