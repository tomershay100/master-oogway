# Soft deps for mo-shell-tools — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
    [bat]="syntax-highlighted output — used by cwhich (show file with syntax highlight)"
    [bc]="arbitrary-precision calculator — required by calc"
)
typeset -gA MO_OPTIONAL_APT=(
    [bat]="bat"
    [bc]="bc"
)
