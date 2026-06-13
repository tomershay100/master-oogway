# lib/optdeps.zsh — removed.
#
# The _MO_OPT_BIN table that used to live here ran command -v for every
# optional tool at shell start. Plugins now use inline per-function checks
# instead, paying the cost only when the function is actually called.
