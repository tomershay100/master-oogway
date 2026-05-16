# Provides: grep aliases, find shortcut, and fuzzy history/man/ripgrep pickers.
# Requires: fhist, fman, frg also require fzf (skipped with an error if not installed).
# frg also requires rg (ripgrep).

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
    _mo_require fzf fhist || return
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
    _mo_require fzf fman || return
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
    _mo_require fzf frg || return
    _mo_require rg  frg || return
    local result
    # fzf substitutes {1} (path field) into the preview shell literally —
    # a file named ';rm;.txt' would execute on cursor-move. Filter unsafe
    # paths before they reach fzf. awk strips ANSI from the path field for
    # the check; the original colorized line still goes to fzf for display.
    result=$(rg --color=always --line-number "" 2>/dev/null \
        | awk -F: '{ p=$1; gsub(/\033\[[0-9;]*m/, "", p); if (p ~ /[$`();|&<>"\x27\\]/) next; print }' \
        | fzf --ansi --height=60% --reverse \
              --delimiter ':' --nth='1,3..' \
              --preview 'bat --color=always --highlight-line {2} {1} 2>/dev/null || batcat --color=always --highlight-line {2} {1} 2>/dev/null || cat {1}')
    if [[ -n "$result" ]]; then
        local file linenum
        file=$(awk 'match($0, /^(.+):([0-9]+):/, a) { print a[1] }' <<< "$result")
        linenum=$(awk 'match($0, /^(.+):([0-9]+):/, a) { print a[2] }' <<< "$result")
        [[ -n "$file" ]] && ${EDITOR:-vim} "$file" "+${linenum}"
    fi
}
