# Soft deps for mo-process — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
    [fzf]="fuzzy finder — enables fkill (fuzzy process killer)"
    [lsof]="list open files — enables port (show process using a port)"
)
typeset -gA MO_OPTIONAL_APT=(
    [fzf]="fzf"
    [lsof]="lsof"
)
