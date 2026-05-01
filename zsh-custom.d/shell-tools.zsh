# Provides: shell inspection and config helpers — h, ?, cwhich, vwhich, vizsh, soursh.

alias h="history 50"

_echo_ret() { echo $?; }
alias '?'="_echo_ret"

_cwhich() { cat "$(which "$1")"; }
alias cwhich="_cwhich"

_vwhich() { vim "$(which "$1")"; }
alias vwhich="_vwhich"

alias vizsh="vim ~/.zshrc"
alias soursh="source ~/.zshrc"
