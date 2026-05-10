# dragon.zsh-theme — OMZ entry point shim
# Sources the theme engine, then the interactive tools (configure + aliases),
# then the notifier (only fires when this file is loaded — i.e. when ZSH_THEME=dragon).
source "${0:a:h}/dragon/dragon.zsh"
source "${0:a:h}/dragon/configure.zsh"
source "${0:a:h}/dragon/aliases.zsh"
source "${0:a:h}/dragon/notifier.zsh"
