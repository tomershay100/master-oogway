
# oh-my-zsh does not source $ZSH_CUSTOM/lib; nor does a zshrc seeded before it.
[[ -n ${_MO_PLATFORM_LOADED-} ]] || source "${0:h}/../../lib/platform.zsh"

h() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: h [n]"
		echo "  Show last n history entries (default: 50)."
		return
	fi
	fc -l -${1:-50} -1
}

alias '?'='echo $?'

cwhich() {
	local target
	target="$(whence -p "$1")" || { echo "cwhich: '$1' not found as a file" >&2; return 1; }
	if command -v bat &>/dev/null; then
		bat "$target"
	elif command -v batcat &>/dev/null; then
		batcat "$target"
	else
		cat "$target"
	fi
}

vwhich() {
	local target
	target="$(whence -p "$1")" || { echo "vwhich: '$1' not found as a file" >&2; return 1; }
	${EDITOR:-vim} "$target"
}

clip() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: <command> | clip"
		echo "  Copy stdin to the system clipboard."
		return
	fi
	local data
	data=$(command cat)
	_mo_clip "$data" || { printf '%s\n' "$data"; return 1; }
	local chars=${#data}
	local unit; (( chars == 1 )) && unit="char" || unit="chars"
	echo "Copied ${chars} ${unit} to clipboard." >&2
}

vizsh() { ${EDITOR:-vim} ~/.zshrc; }
soursh() { source ~/.zshrc; }

mo-where() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
		echo "Usage: mo-where <name>"
		echo "  Show which mo-* plugin defines <name> as an alias or function."
		return
	fi
	local name="$1"
	local dir="${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins"
	local found=0 f plugin match
	for f in "${dir}"/mo-*/*.plugin.zsh(#qN); do
		plugin="${f:h:t}"
		while IFS= read -r match; do
			printf "%s:%s\n" "$plugin" "$match"
			found=1
		# Anchoring at column 0 missed every definition nested inside an `if`
		# — which is how the platform-conditional plugins define theirs.
		done < <(command grep -nE \
			"^[[:space:]]*alias ['\"]?${name}['\"]?=|^[[:space:]]*function ${name}([^a-zA-Z0-9_]|\{|$)|^[[:space:]]*${name}[[:space:]]*\(\)" \
			"$f" 2>/dev/null)
	done
	if (( found == 0 )); then
		echo "mo-where: '${name}' not found in any mo-* plugin" >&2
		return 1
	fi
	return 0
}

# `unalias` first so re-sourcing this file (source ~/.zshrc) doesn't hit
# "defining function based on alias `calc'": the `noglob calc` alias below
# already exists from the previous load, and zsh expands it while parsing the
# `calc()` line, which is a parse error that aborts the rest of the file.
unalias calc 2>/dev/null
calc() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: calc <expression>"
		echo "  Evaluate a math expression using bc -l."
		echo "  Examples:"
		echo "    calc '2 ^ 10'"
		echo "    calc 'sqrt(2)'"
		echo "    calc 's(3.14159/4)'   # sin"
		return
	fi
	if [[ $# -eq 0 ]]; then
		echo "Usage: calc <expression>  (use -h for details)" >&2
		return 1
	fi
	command -v bc &>/dev/null || { echo "calc: bc not installed" >&2; return 1; }
	local expr="$*"
	if [[ ! "$expr" =~ '^[-0-9a-zA-Z_ +*/^().,%]+$' ]]; then
		echo "calc: expression contains invalid characters" >&2
		return 1
	fi
	bc -l <<< "$expr"
}
alias calc='noglob calc'

epoch() {
	local utc=false
	if [[ "${1:-}" == "--utc" || "${1:-}" == "-u" ]]; then
		utc=true
		shift
	fi
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: epoch [--utc] [timestamp | date-string]"
		echo "  (no args)                    — print current unix timestamp"
		echo "  epoch 1700000000             — unix timestamp → local date"
		echo "  epoch --utc 1700000000       — unix timestamp → UTC date"
		echo "  epoch '2025-01-15 09:30:00'  — ISO datetime → unix timestamp"
		if _mo_date_parses_natural_language; then
			echo "  epoch 'yesterday'            — date string → unix timestamp"
			echo "  epoch 'last friday 18:00'    — natural language → unix timestamp"
			echo "  epoch 'next monday'          — relative date → unix timestamp"
		else
			echo "  epoch 'yesterday'            — relative date → unix timestamp"
			echo "  epoch '3 days ago'           — relative date → unix timestamp"
			echo "  (BSD date has no full grammar; install coreutils for gdate)"
		fi
		echo "  --utc / -u  show result in UTC instead of local timezone"
		return
	fi
	if [[ $# -eq 0 ]]; then
		date +%s
	elif [[ "$1" =~ '^[0-9]+$' ]]; then
		if $utc; then _mo_epoch_to_date "$1" --utc; else _mo_epoch_to_date "$1"; fi
	else
		local -a tzflag=()
		$utc && tzflag=(--utc)
		_mo_date_to_epoch "$*" "${tzflag[@]}" && return 0
		# Not an ISO datetime — try a relative expression ("yesterday").
		_mo_relative_to_epoch "$*" && return 0
		echo "epoch: could not parse '$*'" >&2
		if ! _mo_date_parses_natural_language; then
			echo "  BSD date understands ISO datetimes ('YYYY-MM-DD HH:MM:SS')," >&2
			echo "  plus yesterday/tomorrow/next <day>/N days ago." >&2
			echo "  For the full GNU grammar: brew install coreutils (gdate)." >&2
		fi
		return 1
	fi
}
