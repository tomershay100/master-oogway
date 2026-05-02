# Provides: shell inspection and config helpers — h, ?, cwhich, vwhich, vizsh, soursh.

alias h="history 50"

'?'() { echo $?; }
cwhich() { cat "$(which "$1")"; }
vwhich() { vim "$(which "$1")"; }

alias vizsh="vim ~/.zshrc"
alias soursh="source ~/.zshrc"
