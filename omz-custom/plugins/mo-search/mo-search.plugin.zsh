
source "${0:h}/requirements.zsh" || return

# -- fzf environment ------------------------------------------------------------
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

_mo_search_bat=""
command -v bat    &>/dev/null && _mo_search_bat="bat"
command -v batcat &>/dev/null && _mo_search_bat="${_mo_search_bat:-batcat}"

if [[ -n "$_mo_search_bat" ]]; then
	export FZF_CTRL_T_OPTS="--preview '${_mo_search_bat} --color=always --style=plain {} 2>/dev/null || cat {}' --preview-window=right:60%:wrap"
else
	export FZF_CTRL_T_OPTS="--preview 'cat {}' --preview-window=right:60%:wrap"
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
		# awk emits "num\tdate elapsed\tcmd" so fzf can search only the cmd (--nth=2..).
		selected=$(fc -rflD 1 \
			| awk 'BEGIN{FS="  "} {
				num=$1; gsub(/ /,"",num)
				cmd=$4; for(i=5;i<=NF;i++) cmd=cmd"  "$i
				print num "\t" $2 " " $3 "\t" cmd
			}' \
			| FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} ${FZF_DEFAULT_OPTS-} \
				--scheme=history --bind=ctrl-r:toggle-sort,ctrl-z:ignore \
				${FZF_CTRL_R_OPTS-} --query=${(qqq)LBUFFER} +m" \
				fzf --delimiter $'\t' --nth='3..' --with-nth='2,3..')
		local ret=$?
		if [[ -n "$selected" ]]; then
			num="${selected%%$'\t'*}"
			zle vi-fetch-history -n "$num"
		fi
		zle reset-prompt
		return $ret
	}
	zle -N fzf-history-widget
fi

alias grep='noglob command grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox} --exclude={*.so,*.apd,*.pd}'
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

fman() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: fman"
		echo "  Fuzzy-select a man page and open it."
		return
	fi
	command -v fzf &>/dev/null || { echo "fman: fzf not installed" >&2; return 1; }
	local page
	page=$(man -k '' 2>/dev/null \
		| fzf --height=50% --reverse --preview 'man {1}' \
		| awk '{print $1}')
	[[ -n "$page" ]] && man "$page"
}

frg() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: frg [DIR]"
		echo "  Fuzzy search file contents with ripgrep and open result in \$EDITOR."
		echo "  DIR defaults to the current directory."
		return
	fi
	command -v fzf &>/dev/null || { echo "frg: fzf not installed" >&2; return 1; }
	command -v rg  &>/dev/null || { echo "frg: rg not installed (try: sudo apt install ripgrep)" >&2; return 1; }
	local dir="${1:-.}"
	[[ -d "$dir" ]] || { echo "frg: not a directory: $dir" >&2; return 1; }
	local result
	# rg --null separates filename from "lineno:content" with a NUL byte,
	# so filenames containing ':' are never misparsed. awk (FS="\0") splits
	# on that NUL, strips ANSI from the filename for the security check, then
	# emits TAB-separated "file TAB lineno TAB content" — fzf field {1} is
	# always the bare filename, {2} is always the line number.
	result=$(rg --color=always --line-number --null "" "$dir" 2>/dev/null \
		| awk 'BEGIN { FS="\0" }
			   NF == 2 {
				   f = $1; rest = $2
				   gsub(/\033\[[0-9;]*m/, "", f)
				   if (f ~ /[$`();|&<>"\x27\\]/) next
				   n = index(rest, ":")
				   if (n == 0) next
				   print f "\t" substr(rest, 1, n-1) "\t" substr(rest, n+1)
			   }' \
		| fzf --ansi --height=60% --reverse \
			  --delimiter '\t' --nth='1,3..' \
			  --preview 'bat --color=always --highlight-line {2} {1} 2>/dev/null \
						 || batcat --color=always --highlight-line {2} {1} 2>/dev/null \
						 || cat {1}')
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
				local open_cmd="${EDITOR_LINENO_FMT//%f/$file}"
				open_cmd="${open_cmd//%l/$linenum}"
				eval "$open_cmd"
			elif [[ "${EDITOR:-}" == *code* ]]; then
				code -g "${file}:${linenum}"
			else
				${EDITOR:-vim} "+${linenum}" "$file"
			fi
		fi
	fi
}
