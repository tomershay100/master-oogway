# Provides: shell inspection and config helpers — h, ?, cwhich, vwhich, vizsh, soursh, please.

alias h="history 50"                              # last 50 history entries

'?'() { echo $?; }                                # print exit code of the last command
cwhich() { cat "$(which "$1")"; }                 # cat the source of a command
vwhich() { ${EDITOR:-vim} "$(which "$1")"; }      # open the source of a command in $EDITOR

alias vizsh='${EDITOR:-vim} ~/.zshrc'             # open ~/.zshrc in $EDITOR
alias soursh="source ~/.zshrc"                    # reload ~/.zshrc
alias please='sudo $(fc -ln -1)'                  # re-run the previous command with sudo
