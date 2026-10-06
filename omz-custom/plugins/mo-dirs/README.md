# mo-dirs

Directory navigation helpers.

| Command | Description |
|---------|-------------|
| `mkcd <dir>` | `mkdir -p` then `cd` into it |
| `up [n]` | go up `n` directory levels (default 1) |
| `tmpcd` | create a temp dir and `cd` into it |
| `fcd [dir]` | fuzzy-select a subdirectory and `cd` into it |
| `n` | open the current directory in the desktop file manager (`xdg-open` on Linux, `open` on macOS) |
| `downloads` | `cd ${HOME}/Downloads` |
| `home-mo` | `cd "${HOME}/.master-oogway"` |
| `cuso-mo` | `cd "$HOME/.config/master-oogway/custom-zsh"` |

**Dependencies:** `fzf` for `fcd` — checked at call time.
