# Works with whatever ls resolves to at runtime (plain ls, eza, etc.).
# Load mo-eza-override before this plugin so auto-ls uses eza's ls.
# Remove this file to disable automatic ls on directory change.

_ls_after_cd() {
    ls
}
[[ ${chpwd_functions[(Ie)_ls_after_cd]:-0} -eq 0 ]] && chpwd_functions+=(_ls_after_cd)
