
source "${0:h}/requirements.zsh" || return

alias ga="git add"
alias gaa="git add --all"
alias gac="git add ."
alias gs="git status"
gd() {
	if git config --get diff.tool &>/dev/null; then
		git difftool -y "$@"
	else
		git diff "$@"
	fi
}
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
alias gca="git commit --amend"
alias gclean="git clean -id"
alias gcleanf="git clean -fd"

groot() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: groot"
		echo "  cd to the root of the current git repo."
		echo "  If already at root, cd to the outer repo root (submodule case)."
		echo "  Stays in current directory if not in a git repo."
		return
	fi
	local toplevel
	toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || return 0
	if [[ "$PWD" == "$toplevel" ]]; then
		local outer
		outer=$(git -C "${toplevel}/.." rev-parse --show-toplevel 2>/dev/null) || return 0
		cd "$outer"
	else
		cd "$toplevel"
	fi
}
alias cdb=groot

gsum() {
	git rev-parse --git-dir &>/dev/null || { echo "Not a git repo" >&2; return 1; }
	local branch remote ahead behind
	branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD)
	remote=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
	ahead=$(git rev-list --count '@{u}..HEAD' 2>/dev/null)
	behind=$(git rev-list --count 'HEAD..@{u}' 2>/dev/null)
	# Use zsh array counting — avoids wc -l | tr -d ' ' subprocess chains
	local -a stash_list; stash_list=( ${(f)"$(git stash list 2>/dev/null)"} )
	local stashes=${#stash_list[@]}
	local -a status_lines; status_lines=( ${(f)"$(git status --short 2>/dev/null)"} )
	local -a untracked_lines=( "${(M)status_lines[@]:#\?\?*}" )
	local untracked=${#untracked_lines[@]}
	echo "branch : $branch"
	[[ -n "$remote" ]] && echo "remote : $remote  ↑${ahead:-0} ↓${behind:-0}"
	printf '%s\n' "${status_lines[@]}" | head -20
	(( stashes   > 0 )) && echo "stashes: $stashes"
	(( untracked > 0 )) && echo "untracked: $untracked file(s)"
}

gtag() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: gtag"
		echo "  Fuzzy-select a git tag and check it out."
		echo "  Preview shows the tag's commit and diff stat."
		return
	fi
	command -v fzf &>/dev/null || { echo "gtag: fzf not installed" >&2; return 1; }
	git rev-parse --git-dir &>/dev/null || { echo "gtag: not a git repo" >&2; return 1; }
	local tag
	tag=$(git tag --sort=-version:refname 2>/dev/null \
		| fzf --height=60% --reverse \
			  --preview 'git show --color=always --stat {}' \
			  --preview-window=right:60%:wrap)
	[[ -z "$tag" ]] && return
	git checkout "$tag"
}

fbranch() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: fbranch"
		echo "  Fuzzy-select a git branch and switch to it."
		echo "  Preview shows commits ahead of main and the diff stat."
		return
	fi
	git rev-parse --git-dir &>/dev/null || { echo "fbranch: not inside a git repo" >&2; return 1; }
	command -v fzf &>/dev/null || { echo "fbranch: fzf not installed" >&2; return 1; }
	local default_branch
	default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
		| sed 's|refs/remotes/origin/||')
	[[ -n "$default_branch" ]] || default_branch="main"

	# fzf substitutes {} textually into the preview shell — drop branches with chars that could execute.
	local -a all_branches safe_branches dropped
	all_branches=( ${(f)"$(git branch --format='%(refname:short)' 2>/dev/null)"} )
	local b unsafe_chars=$'$`();|&<>"\'\\'
	for b in "${all_branches[@]}"; do
		if [[ "$b" == *[$unsafe_chars]* ]]; then
			dropped+=("$b")
		else
			safe_branches+=("$b")
		fi
	done
	(( ${#dropped[@]} > 0 )) && print -P "%F{yellow}fbranch: hid %B${#dropped[@]}%b branch(es) with shell-unsafe names — use 'git switch' for those%f" >&2

	local branch
	branch=$(printf '%s\n' "${safe_branches[@]}" \
		| FZF_DEFAULT_BRANCH="$default_branch" \
		  fzf --height=60% --reverse \
			  --preview-window=right:60%:wrap \
			  --preview "
				  commits=\$(git log --oneline --color=always \"\$FZF_DEFAULT_BRANCH\"..'{}' 2>/dev/null | head -15)
				  stat=\$(git diff --stat --color=always \"\$FZF_DEFAULT_BRANCH\"...'{}' 2>/dev/null)
				  if [[ -n \"\$commits\" ]]; then
					  printf '%s\n' \"\$commits\"
					  [[ -n \"\$stat\" ]] && printf '\n─────────────────────────\n%s\n' \"\$stat\"
				  else
					  git log --oneline --color=always '{}' 2>/dev/null | head -20
				  fi
			  ")
	[[ -z "$branch" ]] && return   # user hit Ctrl+C in fzf
	git switch "$branch"
}

flog() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		echo "Usage: flog"
		echo "  Interactively browse git log and copy the selected commit hash."
		echo "  Preview pane shows the commit diff stat."
		echo "  Copies hash to clipboard (wl-copy or xclip), or prints it if neither is available."
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
	_mo_clip "$hash" && echo "Copied: $hash" || echo "$hash"
}
