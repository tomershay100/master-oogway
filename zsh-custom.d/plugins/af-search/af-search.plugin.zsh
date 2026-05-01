# Provides: grep aliases, find shortcut, and fuzzy history/man/ripgrep pickers.
# Requires: fhist, fman, frg also require fzf (skipped with an error if not installed).
# frg also requires rg (ripgrep).

alias grep="grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox} --exclude={'*.so','*.apd','*.pd'}"
alias grepi="grep -i"
alias f="find . | grepi"

fhist() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
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
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
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
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: frg"
        echo "  Fuzzy search file contents with ripgrep and open result in \$EDITOR."
        return
    fi
    command -v fzf &>/dev/null || { echo "frg: fzf not installed" >&2; return 1; }
    command -v rg  &>/dev/null || { echo "frg: rg not installed"  >&2; return 1; }
    local result
    result=$(rg --color=always --line-number "" 2>/dev/null \
        | fzf --ansi --height=60% --reverse \
              --delimiter ':' --nth='1,3..' \
              --preview 'bat --color=always --highlight-line {2} {1} 2>/dev/null || cat {1}')
    [[ -n "$result" ]] && ${EDITOR:-vim} "$(cut -d: -f1 <<< "$result")" "+$(cut -d: -f2 <<< "$result")"
}
