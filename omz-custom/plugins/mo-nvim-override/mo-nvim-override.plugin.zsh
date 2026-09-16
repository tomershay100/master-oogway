# Remove this file to use the system vim as-is.

# oh-my-zsh does not source $ZSH_CUSTOM/lib; nor does a zshrc seeded before it.
[[ -n ${_MO_PLATFORM_LOADED-} ]] || source "${0:h}/../../lib/platform.zsh"

source "${0:h}/requirements.zsh" || return

alias vim="nvim"

export EDITOR="nvim"
export VISUAL="nvim"
export SUDO_EDITOR="nvim"
