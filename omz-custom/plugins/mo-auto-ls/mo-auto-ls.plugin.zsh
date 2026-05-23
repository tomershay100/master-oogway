_ls_after_cd() { ls; }
[[ ${chpwd_functions[(Ie)_ls_after_cd]:-0} -eq 0 ]] && chpwd_functions+=(_ls_after_cd)
