
source "${0:h}/requirements.zsh" || return

# ── fzf environment ────────────────────────────────────────────────────────────
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

if command -v bat &>/dev/null; then
    export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=plain {} 2>/dev/null || cat {}' --preview-window=right:60%:wrap"
elif command -v batcat &>/dev/null; then
    export FZF_CTRL_T_OPTS="--preview 'batcat --color=always --style=plain {} 2>/dev/null || cat {}' --preview-window=right:60%:wrap"
else
    export FZF_CTRL_T_OPTS="--preview 'cat {}' --preview-window=right:60%:wrap"
fi

export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always --level=2 {} 2>/dev/null || ls -la {}' --preview-window=right:50%:wrap"

# Default command: fd respects .gitignore and is faster than find.
if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND="fd --type f --hidden --strip-cwd-prefix --exclude .git"
elif command -v fdfind &>/dev/null; then
    export FZF_DEFAULT_COMMAND="fdfind --type f --hidden --strip-cwd-prefix --exclude .git"
fi

unalias grep 2>/dev/null
grep()  { command grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox} --exclude={'*.so','*.apd','*.pd'} "$@"; }
grepi() { grep -i "$@"; }
alias f="find . | grepi"

fhist() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        echo "Usage: fhist"
        echo "  Fuzzy-select a past command and put it in the readline buffer."
        echo "  Tip: CTRL+R (fzf plugin) does the same from any prompt."
        return
    fi
    command -v fzf &>/dev/null || { echo "fhist: fzf not installed" >&2; return 1; }
    local cmd
    cmd=$(fc -ln 1 | fzf --tac --height=40% --reverse --no-sort)
    [[ -n "$cmd" ]] && print -z "$cmd"
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
        echo "Usage: frg"
        echo "  Fuzzy search file contents with ripgrep and open result in \$EDITOR."
        return
    fi
    command -v fzf &>/dev/null || { echo "frg: fzf not installed" >&2; return 1; }
    command -v rg  &>/dev/null || { echo "frg: rg not installed (try: sudo apt install ripgrep)" >&2; return 1; }
    local result
    # rg --null separates filename from "lineno:content" with a NUL byte,
    # so filenames containing ':' are never misparsed. awk (FS="\0") splits
    # on that NUL, strips ANSI from the filename for the security check, then
    # emits TAB-separated "file TAB lineno TAB content" — fzf field {1} is
    # always the bare filename, {2} is always the line number.
    result=$(rg --color=always --line-number --null "" 2>/dev/null \
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
