# mo-shell-tools

Shell inspection and utility helpers.

| Command | Description |
|---------|-------------|
| `h` | last 50 history entries |
| `?` | print the exit code of the last command |
| `cwhich <cmd>` | print the source of a command (syntax-highlighted via bat if available) |
| `vwhich <cmd>` | open the source of a command in `$EDITOR` |
| `clip` | copy stdin to the system clipboard (`echo foo \| clip`) |
| `vizsh` | open `~/.zshrc` in `$EDITOR` |
| `soursh` | reload `~/.zshrc` |
| `calc <expr>` | evaluate a math expression via `bc -l` (supports `sqrt`, `s`, `c`, `l`, `e`) |
| `epoch [ts]` | convert unix timestamp ↔ human date; no arg = current timestamp |
| `please` | re-run the previous command with sudo |
| `mo-where <name>` | show which mo-* plugin defines `<name>` as an alias or function |

**Dependencies:** `wl-clipboard` or `xclip` for `clip`; `bc` for `calc`; `bat`/`batcat` for `cwhich` syntax highlighting — all optional.
