# Soft deps for mo-lan-ssh — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
    [avahi-browse]="mDNS host discovery (primary strategy, fastest)"
    [avahi-daemon]="advertises this machine on the LAN so other master-oogway boxes find you"
    [dig]="DNS AXFR discovery (fallback when avahi is unavailable)"
    [nmap]="ping-sweep + reverse-DNS discovery (fallback)"
    [arp-scan]="ARP-scan discovery (last-resort; needs passwordless sudo for arp-scan)"
)
typeset -gA MO_OPTIONAL_APT=(
    [avahi-browse]="avahi-utils"
    [avahi-daemon]="avahi-daemon"
    [dig]="dnsutils"
    [nmap]="nmap"
    [arp-scan]="arp-scan"
)
