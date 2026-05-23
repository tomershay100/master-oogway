# mo-man

Open the README of any `mo-*` plugin in the terminal.

**Dependencies:** `bat` or `batcat` (optional, falls back to `less`).

| Command | Description |
|---------|-------------|
| `mo-man <plugin>` | View the README of the given plugin. Accepts short name (`git`) or full name (`mo-git`). |

## Examples

```zsh
mo-man git        # opens mo-git/README.md
mo-man mo-files   # opens mo-files/README.md
mo-man build      # opens mo-build/README.md
```
