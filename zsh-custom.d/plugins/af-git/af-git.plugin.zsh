# Provides: git aliases, repo summary, and fuzzy branch/log pickers.
# Requires: git. fbranch and flog also require fzf (skipped if not installed).

alias ga="git add"
alias gaa="git add --all"
alias gs="git status"
alias gd="git difftool -y"
alias gds="gd --staged"
alias glc="git log --graph --pretty='%C(yellow)%h%Creset -%C(auto)%d%Creset %C(auto)%s %C(green)(%ad) %C(bold blue)[%an]%Creset' --date=short"
alias gls="glc --stat"
alias gl="glc --all"
alias gcm="git commit -m"
alias gc="gcm"
alias gco="git checkout"
alias gcb="git checkout -b"
alias gsw="git switch"
alias gswc="git switch -c"
alias grs="git restore"
alias grss="git restore --staged"
alias gb="git branch"
alias gbd="git branch -d"
alias gp="git push"
alias gpl="git pull"
alias gf="git fetch"
alias gst="git stash"
alias grb="git rebase"
alias gcp="git cherry-pick"
alias glog="git log --oneline --decorate --graph"
alias gundo="git reset --soft HEAD~1"
alias gclean="git clean -fd"

function gsum() {
    git rev-parse --git-dir &>/dev/null || { echo "Not a git repo" >&2; return 1; }
    local branch remote ahead behind stashes untracked
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD)
    remote=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
    ahead=$(git rev-list --count '@{u}..HEAD' 2>/dev/null)
    behind=$(git rev-list --count 'HEAD..@{u}' 2>/dev/null)
    stashes=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
    untracked=$(git ls-files --others --exclude-standard | wc -l | tr -d ' ')
    echo "branch : $branch"
    [[ -n "$remote" ]] && echo "remote : $remote  ↑${ahead:-0} ↓${behind:-0}"
    git status --short | head -20
    (( stashes   > 0 )) && echo "stashes: $stashes"
    (( untracked > 0 )) && echo "untracked: $untracked file(s)"
}

fbranch() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: fbranch"
        echo "  Fuzzy-select a git branch and switch to it."
        return
    fi
    command -v fzf &>/dev/null || { echo "fbranch: fzf not installed" >&2; return 1; }
    local branch
    branch=$(git branch -a --color=always 2>/dev/null \
        | grep -v '\->' \
        | fzf --ansi --height=40% --reverse \
              --preview 'git log --oneline --color=always {-1} | head -20') \
    && git switch "${branch##* }"
}

flog() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: flog"
        echo "  Interactively browse git log and copy the selected commit hash."
        echo "  Preview pane shows the commit diff stat."
        echo "  Copies hash to clipboard (xclip), or prints it if xclip is unavailable."
        return
    fi
    command -v fzf &>/dev/null || { echo "flog: fzf not installed" >&2; return 1; }
    local hash
    hash=$(git log --oneline --color=always 2>/dev/null \
        | fzf --ansi --height=60% --reverse \
              --preview 'git show --color=always --stat {1}' \
              --preview-window=right:60% \
        | awk '{print $1}')
    [[ -z "$hash" ]] && return
    if command -v xclip &>/dev/null; then
        echo -n "$hash" | xclip -selection clipboard
        echo "Copied: $hash"
    else
        echo "$hash"
    fi
}
