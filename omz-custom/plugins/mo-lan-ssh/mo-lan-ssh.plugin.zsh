# mo-lan-ssh — LAN host auto-discovery + SSH aliases + tab-completion.
# Two-host-class model: LAN PCs (mDNS/nmap discovery, bare-name aliases) and
# USB gadgets (declarative MO_LAN_GADGET_SUBNETS, wildcard ssh-config block).
# The ssh wrapper is hint-only — never auto-runs ssh-copy-id.
# CLI: mo-lan-ssh list|refresh|status|setup|add|remove|purge|help
# Disable hint wrapper: export MO_LAN_TRUST_HINTS=false in ~/.zshrc

source "${0:h}/requirements.zsh" || return

source "${0:h}/_mo_lan_loader.zsh"
source "${0:h}/_mo_lan_cli.zsh"
