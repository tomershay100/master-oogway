# mo-projects

Project directory hub. Every subdirectory of your projects root gets its own alias — type the project name to `cd` into it instantly.

| Command | Description |
|---------|-------------|
| `<project-name>` | `cd` into that project directory |
| `p` | fzf-pick a project and `cd` into it |

Aliases are registered at shell startup. If a name collides with an existing builtin, command, function, or alias, it is silently skipped — no clobbering. Load order in `~/.zshrc` controls collision priority.

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `MO_PROJECTS_PROJ_DIR` | `~/projects` (or `~/Projects`) | directory whose subdirectories become aliases |

Set in `~/.config/master-oogway/conf.zsh` to override:

```zsh
MO_PROJECTS_PROJ_DIR=~/work
```

**Dependencies:** `fzf` for `p` — checked at call time.
