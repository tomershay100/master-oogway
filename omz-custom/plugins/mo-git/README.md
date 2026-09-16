# mo-git

Git aliases and fuzzy pickers.

| Command | Description |
|---------|-------------|
| `ga` | `git add` |
| `gaa` | `git add --all` |
| `gac` | `git add .` (current directory only) |
| `gs` | `git status` |
| `gd` | `git difftool -y`, falling back to `git diff` when the configured tool cannot run |
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
| `gclean` | `git clean -id` — interactive menu to remove untracked files and dirs |
| `gcleanf` | `git clean -fd` — remove them without asking |
| `groot` / `cdb` | cd to repo root; if already at root, cd to outer repo root (submodule case); no-op if not in a git repo |
| `gsum` | print branch + staged/unstaged file summary |
| `fbranch` | fuzzy-select a branch and switch to it |
| `flog` | fuzzy-browse git log with diff-stat preview; copies selected hash to clipboard |
| `gtag` | fuzzy-select a tag and check it out |

**Dependencies:** `git` (required). `fzf` for `fbranch`, `flog`, `gtag` — checked at call time.

**`gd` and your diff tool.** `gd` opens whatever `diff.tool` names — the
shipped gitconfig sets `meld`, so on Linux it opens meld, as upstream intended.
It falls back to `git diff` only when that tool cannot actually run, because
`git difftool` reports an unrunnable tool as an empty diff and exit 0, which
looks exactly like "no changes". Two tools hit this on macOS: `meld` has no
macOS build, and `opendiff` — git's default there — exists as an `xcrun` shim
even without Xcode and fails only when invoked. On a Mac with full Xcode,
`opendiff` does run, so `gd` opens FileMerge.

`master-oogway diff-zshrc` applies one further rule: it refuses GUI tools
outright, since it prints a config diff for someone already reading the
terminal.
