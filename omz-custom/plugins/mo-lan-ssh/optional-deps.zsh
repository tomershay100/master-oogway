# Soft deps for mo-lan-ssh — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
    [nmap]="LAN host discovery — used by mo-lan-ssh refresh to scan the local network"
    [ssh-copy-id]="auto-copy SSH keys to LAN hosts — used by mo-lan-ssh trust"
)
typeset -gA MO_OPTIONAL_APT=(
    [nmap]="nmap"
    [ssh-copy-id]="openssh-client"
)
