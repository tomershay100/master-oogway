# Soft deps for mo-dirs — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
    [fzf]="fuzzy finder — enables fcd (fuzzy cd) and directory preview"
    [eza]="better directory listings inside fcd preview panel"
)
typeset -gA MO_OPTIONAL_APT=(
    [fzf]="fzf"
    [eza]="eza"
)
