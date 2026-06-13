
mkscript() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
		echo "Usage: mkscript <path>"
		echo "  Create a new shell script at <path> with the project header template,"
		echo "  make it executable, and open it in \$EDITOR."
		return
	fi

	local path="$1"
	local name="${path:t}"  # basename

	if [[ -e "$path" ]]; then
		echo "mkscript: '$path' already exists" >&2
		return 1
	fi

	local parent="${path:h}"
	if [[ "$parent" != "." && ! -d "$parent" ]]; then
		echo "mkscript: directory '$parent' does not exist" >&2
		return 1
	fi

	local sep='# ------------------------------------------------------------------------------'

	>"$path" print -r -- "#!/usr/bin/env bash
${sep}
# ${name} -
${sep}
set -Eeuo pipefail
"

	chmod +x "$path"
	echo "Created: $path"
	${EDITOR:-vim} "$path"
}
