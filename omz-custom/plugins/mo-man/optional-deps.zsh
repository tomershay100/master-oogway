# Soft deps for mo-man — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
    [bat]="syntax-highlighted man pages — used by mo-man for colourised output"
)
typeset -gA MO_OPTIONAL_APT=(
    [bat]="bat"
)
