# Soft deps for mo-network — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
	[curl]="external IP lookup in natip"
	[python3]="local HTTP server in serve"
	[fzf]="fuzzy SSH host picker in sshto"
)
typeset -gA MO_OPTIONAL_APT=(
	[curl]="curl"
	[python3]="python3"
	[fzf]="fzf"
)
