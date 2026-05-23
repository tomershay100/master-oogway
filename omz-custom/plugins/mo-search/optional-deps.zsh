# Soft deps for mo-search — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
    [fzf]="fuzzy finder — enables fhist, fman, fenv, fp, fcd, fkill, sshto, frg, and FZF key bindings (Ctrl+T / Ctrl+R / Alt+C)"
    [fd]="faster file search — replaces find as FZF_DEFAULT_COMMAND (Ctrl+T file picker)"
    [bat]="syntax-highlighted file previews inside fzf (Ctrl+T)"
    [rg]="ripgrep — enables frg (fuzzy ripgrep picker)"
)
typeset -gA MO_OPTIONAL_APT=(
    [fzf]="fzf"
    [fd]="fd-find"
    [bat]="bat"
    [rg]="ripgrep"
)
