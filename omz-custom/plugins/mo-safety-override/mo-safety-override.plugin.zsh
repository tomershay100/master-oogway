# These change the default behavior of common system commands.
# Remove this file to restore the original behavior of all four commands.

# oh-my-zsh does not source $ZSH_CUSTOM/lib; nor does a zshrc seeded before it.
[[ -n ${_MO_PLATFORM_LOADED-} ]] || source "${0:h}/../../lib/platform.zsh"

alias cp="cp -i"        # prompt before overwrite
alias mv="mv -i"        # prompt before overwrite
alias mkdir="mkdir -pv" # create parents silently, print each new dir

# mo-trash owns the rm-to-trash redirect and loads after this plugin, so its
# alias wins when enabled. This is the fallback for when it is not — and it is
# not by default, since mo-trash is commented out in the shipped plugin list.
#
# Linux only, deliberately. Upstream keyed this on trash-cli being present,
# which is an opt-in: installing trash-cli says "I want rm to trash". macOS
# ships /usr/bin/trash on every machine, so the same test there would silently
# redirect rm for everyone who never asked. On macOS the opt-in is enabling
# mo-trash. Dropping this branch entirely — as the port first did — cost Linux
# users with trash-cli a behaviour they already had.
# platform-lint: allow — guarded by _mo_is_linux on the line above.
if _mo_is_linux && command -v trash-put &>/dev/null; then
	alias rm="trash-put"
else
	alias rm="rm -I"    # prompt when removing 3+ files or recursing
fi

_confirm_reboot() {
	echo "This is $(hostname). Are you sure you want to reboot the system? (y/N)"
	local ans
	read -r -t 30 ans || { echo "Timed out — reboot cancelled."; return 1; }
	if [[ "$ans" =~ ^[Yy]([Ee][Ss])?$ ]]; then
		# Linux reboot(8) is a systemd unit that stops services in order;
		# macOS reboot(8) just SIGTERMs everything, so the graceful
		# equivalent there is shutdown(8), which notifies loginwindow first.
		local -a cmd=( ${=$(_mo_reboot_cmd)} )
		command "${cmd[@]}" "$@"
	else
		echo "Reboot cancelled."
		return 1
	fi
}
alias reboot="_confirm_reboot"
