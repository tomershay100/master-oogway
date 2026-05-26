autoload -Uz add-zsh-hook
_ls_after_cd() {
    if (( $+_MO_OPT_BIN[eza] )); then
        eza -F
    else
        command ls --color=auto
    fi
}
add-zsh-hook chpwd _ls_after_cd
