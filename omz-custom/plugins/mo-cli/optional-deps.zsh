# Soft deps for mo-cli — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
	[python3]="lan-ssh host discovery (reverse-DNS via scan_hosts.py)"
)
typeset -gA MO_OPTIONAL_APT=(
	[python3]="python3"
)
