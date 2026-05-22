# mo-shell-tools

Shell inspection and config helpers.

| Command | Description |
|---------|-------------|
| `h` | last 50 history entries |
| `?` | print the exit code of the last command |
| `cwhich <cmd>` | print the source of a command (syntax-highlighted via bat if installed) |
| `vwhich <cmd>` | open the source of a command in `$EDITOR` |
| `clip` | copy stdin to the system clipboard (`echo foo \| clip`) |
| `vizsh` | open `~/.zshrc` in `$EDITOR` |
| `soursh` | reload `~/.zshrc` |
| `zshtime [n]` | measure zsh startup time over `n` runs (default 5) |
| `please` | re-run the previous command with sudo |
| `mo-where <name>` | show which mo-* plugin defines `<name>` as an alias or function |

**Dependencies:** `wl-clipboard` (`sudo apt install wl-clipboard`) or `xclip` (`sudo apt install xclip`) for `clip` — falls back to printing an error if neither is installed. `bat`/`batcat` for `cwhich` syntax highlighting (optional).
