# Soft deps for mo-search — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
    [fd]="faster file search — replaces find as FZF_DEFAULT_COMMAND (Ctrl+T file picker)"
    [bat]="syntax-highlighted file previews inside fzf (Ctrl+T)"
    [rg]="ripgrep — enables frg (fuzzy ripgrep picker)"
)
typeset -gA MO_OPTIONAL_APT=(
    [fd]="fd-find"
    [bat]="bat"
    [rg]="ripgrep"
)
