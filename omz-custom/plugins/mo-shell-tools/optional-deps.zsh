# Soft deps for mo-shell-tools — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
	[bat]="syntax-highlighted file preview in cwhich"
	[wl-copy]="clipboard copy on Wayland in copy-to-clipboard helpers"
	[xclip]="clipboard copy on X11 in copy-to-clipboard helpers"
	[bc]="math evaluation in calc"
)
typeset -gA MO_OPTIONAL_APT=(
	[bat]="bat"
	[wl-copy]="wl-clipboard"
	[xclip]="xclip"
	[bc]="bc"
)
