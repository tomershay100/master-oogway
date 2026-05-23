# Soft deps for mo-process — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
    [fzf]="fuzzy finder — enables fkill (fuzzy process killer)"
)
typeset -gA MO_OPTIONAL_APT=(
    [fzf]="fzf"
)
