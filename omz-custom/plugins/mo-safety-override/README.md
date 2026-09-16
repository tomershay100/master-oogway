# mo-safety-override

Adds confirmation prompts and safer defaults to destructive commands.

| Command | Behavior |
|---------|----------|
| `cp` | asks before overwriting (`-i`) |
| `mv` | asks before overwriting (`-i`) |
| `mkdir` | always creates parents, prints each new dir (`-pv`) |
| `rm` | prompts once when removing 3+ files or recursing (`-I`). On Linux, if `trash-cli` is installed, `rm` moves to the trash instead — installing it is the opt-in. On macOS the opt-in is enabling the `mo-trash` plugin, since `/usr/bin/trash` ships with the OS and keying on its presence would redirect `rm` for everyone |
| `reboot` | asks "are you sure?" with a 30-second timeout. Runs `reboot` on Linux and `shutdown -r now` on macOS, where `reboot(8)` skips the orderly shutdown |

To bypass: use `\cp`, `\mv`, `\mkdir`, `\rm` (backslash-quoting skips alias expansion). Note this works *because* these are aliases — a function of the same name would swallow the backslash and run anyway. `command rm` bypasses either.
