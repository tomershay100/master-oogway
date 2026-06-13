# These change the default behavior of common system commands.
# Remove this file to restore the original behavior of all four commands.

alias cp="cp -i"        # prompt before overwrite
alias mv="mv -i"        # prompt before overwrite
alias mkdir="mkdir -pv" # create parents silently, print each new dir

_confirm_reboot() {
	echo "This is $(hostname). Are you sure you want to reboot the system? (y/N)"
	local ans
	read -r -t 30 ans || { echo "Timed out — reboot cancelled."; return 1; }
	[[ "$ans" =~ ^[Yy]([Ee][Ss])?$ ]] && command reboot "$@"
}
alias reboot="_confirm_reboot"
