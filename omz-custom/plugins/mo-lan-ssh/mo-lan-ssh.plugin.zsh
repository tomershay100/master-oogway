# mo-lan-ssh — LAN host auto-discovery + SSH aliases + trust management.
# `s-<hostname>` fallback when the bare name collides with an existing
# command/alias/function/builtin. Tab-completion for ssh/scp/sftp/rsync.
# Managed ~/.ssh/config.d/lan-hosts (Port directive for non-22 listeners).
# CLI: mo-lan-ssh list|refresh|status|setup|add|remove|trust|forget|help.
# An ssh wrapper auto-runs ssh-copy-id on first-password-prompt for LAN
# hosts, and auto-purges changed host keys (LAN trust). Disable wrapper
# with MO_LAN_AUTO_TRUST=false.

source "${0:h}/requirements.zsh" || return

# Parts (startup-critical path separate from CLI so each is easy to audit)
source "${0:h}/_mo_lan_loader.zsh"
source "${0:h}/_mo_lan_cli.zsh"
