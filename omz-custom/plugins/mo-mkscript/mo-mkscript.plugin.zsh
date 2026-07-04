
mkscript() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
		echo "Usage: mkscript <path>"
		echo "  Create a new shell script at <path> with the project header template,"
		echo "  make it executable, and open it in \$EDITOR."
		return
	fi

	local script_path="$1"
	local name="${script_path:t}"  # basename

	if [[ -e "$script_path" ]]; then
		echo "mkscript: '$script_path' already exists" >&2
		return 1
	fi

	local parent="${script_path:h}"
	if [[ "$parent" != "." && ! -d "$parent" ]]; then
		echo "mkscript: directory '$parent' does not exist" >&2
		return 1
	fi

	local sep='# ------------------------------------------------------------------------------'

	>"$script_path" print -r -- "#!/usr/bin/env bash
${sep}
# ${name} -
${sep}
set -Eeuo pipefail
"

	chmod +x "$script_path"
	echo "Created: $script_path"
	${EDITOR:-vim} "$script_path"
}
