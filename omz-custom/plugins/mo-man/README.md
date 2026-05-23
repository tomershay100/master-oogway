# mo-man

View the README of any `mo-*` plugin in the terminal. Tab completion groups plugins into **active** (currently loaded) and **available** (installed but not loaded).

| Command | Description |
|---------|-------------|
| `mo-man <plugin>` | open the plugin's README; accepts short name (`git`) or full name (`mo-git`) |

## Examples

```zsh
mo-man git        # opens mo-git/README.md
mo-man mo-files   # opens mo-files/README.md
mo-man build      # opens mo-build/README.md
```

**Dependencies:** `bat` or `batcat` for rendering — falls back to `less` if neither is installed.
