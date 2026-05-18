# mo-safety-override

Adds confirmation prompts to destructive commands.

| Command | Behavior |
|---------|----------|
| `cp` | asks before overwriting (passes `-i` to system cp) |
| `mv` | asks before overwriting (passes `-i` to system mv) |
| `mkdir` | always creates parents and prints each dir created (passes `-pv`) |
| `reboot` | asks "are you sure?" with a 30-second timeout before rebooting |

| Escape hatch | Bypasses to |
|---|---|
| `rcp` or `\cp` | system `cp` (no prompt) |
| `rmv` or `\mv` | system `mv` (no prompt) |
| `rmkdir` or `\mkdir` | system `mkdir` |
