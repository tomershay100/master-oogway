# Git
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

############# gundo: undo last commit, keep changes staged ##############
alias gundo="git reset --soft HEAD~1"
alias gclean="git clean -fd"

############# gsum: git repo summary ##############
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
    (( stashes  > 0 )) && echo "stashes: $stashes"
    (( untracked > 0 )) && echo "untracked: $untracked file(s)"
}
