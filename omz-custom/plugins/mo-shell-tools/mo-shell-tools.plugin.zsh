
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
	for f in "${dir}"/mo-*/*.plugin.zsh(N); do
		plugin="${f:h:t}"
		while IFS= read -r match; do
			printf "%s:%s\n" "$plugin" "$match"
			found=1
		done < <(grep -nE \
			"^alias ['\"]?${name}['\"]?=|^function ${name}([^a-zA-Z0-9_]|\{|$)|^${name}[[:space:]]*\(\)" \
			"$f" 2>/dev/null)
	done
	(( found == 0 )) && { echo "mo-where: '${name}' not found in any mo-* plugin" >&2; return 1; }
}

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
		echo "  epoch 'yesterday'            — date string → unix timestamp"
		echo "  epoch 'last friday 18:00'    — natural language → unix timestamp"
		echo "  epoch '2025-01-15 09:30:00'  — ISO datetime → unix timestamp"
		echo "  epoch 'next monday'          — relative date → unix timestamp"
		echo "  --utc / -u  show result in UTC instead of local timezone"
		return
	fi
	local date_flags=()
	$utc && date_flags=(-u)
	if [[ $# -eq 0 ]]; then
		date "${date_flags[@]}" +%s
	elif [[ "$1" =~ '^[0-9]+$' ]]; then
		date "${date_flags[@]}" -d "@$1"
	else
		date "${date_flags[@]}" -d "$*" +%s
	fi
}

# ${(Q)${(z)...}} splits respecting quoting; strips leading 'sudo' if already present.
# For pipelines, sudo is prepended to the first segment whose lead token is a real
# binary — other segments run in the current shell so functions/aliases still work.
please() {
	local last
	last=$(fc -ln -1 2>/dev/null)
	[[ -z "$last" ]] && { echo "please: no previous command" >&2; return 1; }
	local -a tokens
	tokens=( ${(z)last} )

	# Strip leading sudo from the raw token stream so we don't double-sudo.
	[[ "${tokens[1]:-}" == "sudo" ]] && tokens=( "${tokens[@]:1}" )
	[[ ${#tokens[@]} -eq 0 ]] && { echo "please: no command to run" >&2; return 1; }

	# Check if any pipes are present.
	local has_pipe=false
	local tok
	for tok in "${tokens[@]}"; do
		[[ "$tok" == "|" ]] && { has_pipe=true; break; }
	done

	if ! $has_pipe; then
		# Simple command — strip quoting and exec directly under sudo.
		local -a cmd=( ${(Q)tokens} )
		print -P "  %F{yellow}sudo ${(j: :)cmd}%f"
		printf "  Run as root? [Y/n] "
		local _ans; read -r _ans
		[[ "$_ans" == n* || "$_ans" == N* ]] && return 0
		sudo "${cmd[@]}"
		return
	fi

	# Pipeline: split token stream into segments on | boundaries.
	# Each segment is a space-joined string; we find the first whose
	# lead word is a real binary and prepend sudo to it only.
	local -a segments=()
	local seg=""
	for tok in "${tokens[@]}"; do
		if [[ "$tok" == "|" ]]; then
			segments+=( "$seg" )
			seg=""
		else
			seg="${seg:+$seg }$tok"
		fi
	done
	[[ -n "$seg" ]] && segments+=( "$seg" )

	local -a out_segments=()
	local sudoed=false
	local s lead _lw
	local -a _seg_words
	for s in "${segments[@]}"; do
		# First word of this segment — assign through array to avoid the
		# single-word (z) double-subscript bug where ${${(z)s}[1]} returns
		# the first character instead of the first word.
		_seg_words=( ${(z)s} ); lead="${_seg_words[1]}"
		# Strip any existing sudo prefix within a segment.
		if [[ "$lead" == "sudo" ]]; then
			s="${s#sudo }"; _seg_words=( ${(z)s} ); lead="${_seg_words[1]}"
		fi
		# Accept binaries and builtins; reject functions, aliases, and unknowns.
		# whence -w returns "word: type" — function/alias are shell-only,
		# builtin/command both work under sudo.
		_lw=$(whence -w "$lead" 2>/dev/null)
		if ! $sudoed && [[ -n "$lead" ]] \
			&& [[ "$_lw" != *': function' && "$_lw" != *': alias' \
			   && "$_lw" != *': none' ]]; then
			# This segment's lead is a binary or builtin — sudo it.
			out_segments+=( "sudo $s" )
			sudoed=true
		else
			out_segments+=( "$s" )
		fi
	done

	if ! $sudoed; then
		echo "please: no binary found in pipeline to sudo — write the command explicitly" >&2
		return 1
	fi

	# Reassemble and eval in the current shell so functions in other segments work.
	local pipeline
	pipeline="${(j: | :)out_segments}"
	print -P "  %F{yellow}${pipeline}%f"
	printf "  Run as root? [Y/n] "
	local _ans; read -r _ans
	[[ "$_ans" == n* || "$_ans" == N* ]] && return 0
	eval "$pipeline"
}
