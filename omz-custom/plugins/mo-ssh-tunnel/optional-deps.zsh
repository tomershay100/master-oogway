# Soft deps for mo-ssh-tunnel — read by install.sh, never sourced at runtime.
# Without lsof, background tunnels still open — they just can't be tracked for
# `tunnel list` / `tunnel kill` (ss from iproute2 is used as a fallback).
typeset -gA MO_OPTIONAL_DEPS=(
	[lsof]="track background tunnels (ssh -f) so 'tunnel list' / 'tunnel kill' can manage them"
)
typeset -gA MO_OPTIONAL_APT=(
	[lsof]="lsof"
)
