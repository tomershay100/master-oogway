# Remove this file to use the system vim as-is.

source "${0:h}/requirements.zsh" || return

alias vim="nvim"

export EDITOR="nvim"
export VISUAL="nvim"
export SUDO_EDITOR="nvim"
