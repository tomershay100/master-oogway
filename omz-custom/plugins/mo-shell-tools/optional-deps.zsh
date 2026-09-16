# platform-lint: metadata — names Linux package names for the installer, not executed.
# Soft deps for mo-shell-tools — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
	[bat]="syntax-highlighted file preview in cwhich"
	[wl-copy]="clipboard copy on Wayland (Linux only; macOS uses pbcopy)"
	[xclip]="clipboard copy on X11 (Linux only; macOS uses pbcopy)"
	[bc]="math evaluation in calc"
)
typeset -gA MO_OPTIONAL_APT=(
	[bat]="bat"
	[wl-copy]="wl-clipboard"
	[xclip]="xclip"
	[bc]="bc"
)
