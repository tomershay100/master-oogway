# mo-safety-override

Adds confirmation prompts and safer defaults to destructive commands.

| Command | Behavior |
|---------|----------|
| `cp` | asks before overwriting (`-i`) |
| `mv` | asks before overwriting (`-i`) |
| `mkdir` | always creates parents, prints each new dir (`-pv`) |
| `reboot` | asks "are you sure?" with a 30-second timeout |

To bypass: use `\cp`, `\mv`, `\mkdir` (backslash-quoting skips aliases in any shell).
