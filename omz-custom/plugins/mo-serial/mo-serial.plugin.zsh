
# oh-my-zsh does not source $ZSH_CUSTOM/lib; nor does a zshrc seeded before it.
[[ -n ${_MO_PLATFORM_LOADED-} ]] || source "${0:h}/../../lib/platform.zsh"
source "${0:h}/requirements.zsh" || return

min() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
		echo "Usage: min <device> [minicom args...]"
		echo "  Open minicom on /dev/<device> with color enabled."
		echo "  device: bare name under /dev/ (e.g. ttyUSB0 on Linux, cu.usbserial-* on macOS)"
		echo "  extra args pass through to minicom."
		return
	fi
	minicom -D "/dev/$1" -c on "${@:2}"
}
