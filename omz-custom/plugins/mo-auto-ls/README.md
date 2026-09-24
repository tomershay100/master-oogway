# mo-auto-ls

Runs `ls` automatically after every `cd`. No commands to invoke — behaviour is always-on. Comment out this plugin in `~/.zshrc` to disable entirely.

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `MO_AUTO_LS_COMMAND` | `ls` | Command (with flags) run after each `cd`, e.g. `ls -la`, `ls -lA` |
| `MO_AUTO_LS_THRESHOLD` | `40` | Entry count above which only a count is printed instead of listing |

Set in `~/.zshrc` before `plugins=(…)`:

```zsh
MO_AUTO_LS_COMMAND='ls -la'
MO_AUTO_LS_THRESHOLD=20
```
