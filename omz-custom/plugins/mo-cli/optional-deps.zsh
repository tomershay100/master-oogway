# Soft deps for mo-cli — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
	[nmap]="lan-ssh host discovery — falls back to a slower dig loop (/24 only)"
)
typeset -gA MO_OPTIONAL_APT=(
	[nmap]="nmap"
)
