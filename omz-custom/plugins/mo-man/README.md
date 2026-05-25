# mo-man

View the README of any `mo-*` plugin in the terminal. Tab completion groups plugins into **active** (currently loaded) and **available** (installed but not loaded).

| Command | Description |
|---------|-------------|
| `mo-man` | fzf picker — browse all plugins with live preview |
| `mo-man <plugin>` | open directly; accepts short name (`git`) or full name (`mo-git`) |

## Examples

```zsh
mo-man            # fzf picker with README preview on the right
mo-man git        # opens mo-git/README.md
mo-man mo-files   # opens mo-files/README.md
```

**Dependencies:** `fzf` for the picker (falls back to requiring a name argument); `bat` or `batcat` for rendering — falls back to `less`.
