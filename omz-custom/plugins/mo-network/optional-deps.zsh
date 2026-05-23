# Soft deps for mo-network — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
    [fzf]="fuzzy finder — enables sshto (fuzzy SSH host picker)"
)
typeset -gA MO_OPTIONAL_APT=(
    [fzf]="fzf"
)
