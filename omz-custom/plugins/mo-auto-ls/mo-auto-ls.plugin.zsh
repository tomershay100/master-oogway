autoload -Uz add-zsh-hook
_ls_after_cd() { ls; }
add-zsh-hook chpwd _ls_after_cd
