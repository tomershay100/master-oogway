# Soft deps for mo-git — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
    [fzf]="fuzzy finder — enables gtag (fuzzy tag picker), fbranch (fuzzy branch switcher), flog (fuzzy commit log)"
    [meld]="visual diff tool — used by mo-cli diff-zshrc; falls back to git difftool"
)
typeset -gA MO_OPTIONAL_APT=(
    [fzf]="fzf"
    [meld]="meld"
)
