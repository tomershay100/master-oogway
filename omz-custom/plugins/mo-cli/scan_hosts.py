#!/usr/bin/env python3
"""
scan_hosts.py — reverse-DNS scan of one or more subnets, print short hostnames.

Default discovery engine for lan_scan.sh (called via `master-oogway lan-ssh
refresh` / the daily cron). Pass --list to print discovered hostnames only.

Emits one bare hostname per line on stdout. Filters to names matching
^[A-Za-z0-9_-]+$ and dedups. Collision-with-command filtering (security guard
against hostile LAN hosts naming themselves `ls`/`sudo`) is done downstream in
lan_scan.sh's filter_names — it needs `command -v`, a shell check.

Config (env vars):
  MO_LAN_SUBNETS   comma-separated list of subnets, each either a 3-octet
                   prefix ("192.168.1", read as /24) or a CIDR
                   ("10.0.0.0/22"). Defaults to 192.168.1, the most common
                   home-router LAN. Sweeps wider than /20 are refused.
"""
import ipaddress
import os
import re
import socket
import sys
from concurrent.futures import ThreadPoolExecutor

DEFAULT_SUBNETS = ["192.168.1"]
NAME_RE = re.compile(r"^[A-Za-z0-9_-]+$")
LOOKUP_TIMEOUT = 2  # seconds; one dead resolver must not stall the whole scan
MAX_WORKERS = 64
# A /20 is 4094 reverse lookups. Anything wider is a typo far more often than
# an intent, and would run for minutes.
MIN_PREFIXLEN = 20


def parse_subnet(entry):
    """IPv4Network for entry, or None when it is not a form we sweep.

    A bare address with no prefix stays rejected: as a /32 it would sweep a
    single host, which is a typo far more often than an intent.
    """
    if "/" not in entry:
        if entry.count(".") != 2:
            return None
        entry = f"{entry}.0/24"
    try:
        return ipaddress.IPv4Network(entry, strict=False)
    except ValueError:
        return None


def subnets():
    """The configured networks as IPv4Network objects."""
    raw = os.environ.get("MO_LAN_SUBNETS")
    out = []
    for entry in (raw or ",".join(DEFAULT_SUBNETS)).split(","):
        entry = entry.strip()
        if not entry:
            continue
        net = parse_subnet(entry)
        if net is None:
            # A bad entry would otherwise build strings like "garbage.1" and
            # spend 254 forward-DNS lookups per entry resolving them.
            print(f"scan_hosts: ignoring malformed MO_LAN_SUBNETS entry {entry!r} "
                  "(want a 3-octet IPv4 prefix like 192.168.1, or a CIDR like "
                  "10.0.0.0/22)", file=sys.stderr)
            continue
        if net.prefixlen < MIN_PREFIXLEN:
            print(f"scan_hosts: ignoring MO_LAN_SUBNETS entry {entry!r} — a "
                  f"/{net.prefixlen} sweep is larger than the /{MIN_PREFIXLEN} "
                  "cap; narrow it", file=sys.stderr)
            continue
        out.append(net)
    if not out:
        # Exit non-zero so lan_scan.sh reports the real cause rather than its
        # generic "no hosts found".
        sys.exit("scan_hosts: no usable subnets in MO_LAN_SUBNETS")
    return out


def lookup(ip):
    try:
        return socket.gethostbyaddr(ip)[0]
    except (socket.herror, socket.gaierror, OSError):
        return None


def main():
    socket.setdefaulttimeout(LOOKUP_TIMEOUT)
    # hosts() excludes the network and broadcast addresses, which the old
    # range(1, 255) only got right by hardcoding /24.
    ips = [str(host) for net in subnets() for host in net.hosts()]
    seen = set()
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        for fqdn in pool.map(lookup, ips):
            if fqdn is None:
                continue
            name = fqdn.split(".", 1)[0]  # first dot-segment
            if not NAME_RE.match(name):
                continue
            if name in seen:
                continue
            seen.add(name)
            print(name)


if __name__ == "__main__":
    main()
