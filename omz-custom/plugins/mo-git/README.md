# mo-git

Git aliases and fuzzy pickers.

| Command | Description |
|---------|-------------|
| `ga` | `git add` |
| `gaa` | `git add --all` |
| `gs` | `git status` |
| `gd` | `git difftool -y` |
| `gds` | `gd --staged` |
| `gl` | pretty graph log (all branches) |
| `glc` | pretty graph log (current branch) |
| `gls` | `glc --stat` |
| `glog` | compact one-line graph log |
| `gcm` / `gc` | `git commit -m` |
| `gca` | `git commit --amend` (opens editor) |
| `gco` | `git checkout` |
| `gcb` | `git checkout -b` |
| `gsw` | `git switch` |
| `gswc` | `git switch -c` |
| `grs` | `git restore` |
| `grss` | `git restore --staged` |
| `gb` | `git branch` |
| `gbd` | `git branch -d` |
| `gp` | `git push` |
| `gpl` | `git pull` |
| `gf` | `git fetch` |
| `gst` | `git stash` |
| `grb` | `git rebase` |
| `gcp` | `git cherry-pick` |
| `gundo` | undo last commit, keep changes staged |
| `gclean` | remove untracked files and dirs |
| `groot` / `cdb` | cd to repo root; if already at root, cd to outer repo root (submodule case); no-op if not in a git repo |
| `gsum` | print branch + staged/unstaged file summary |
| `fbranch` | fuzzy-select a branch and switch to it |
| `flog` | fuzzy-browse git log with diff-stat preview; copies selected hash to clipboard |
| `gtag` | fuzzy-select a tag and check it out |

**Dependencies:** `git` (required). `fzf` for `fbranch`, `flog`, `gtag` — checked at call time.
