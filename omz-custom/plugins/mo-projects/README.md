# mo-projects

Project directory hub. Every subdirectory of your projects root gets its own alias — type the project name to `cd` into it instantly.

| Command | Description |
|---------|-------------|
| `<project-name>` | `cd` into that project directory |
| `p` | fzf-pick a project and `cd` into it |

Aliases are registered at shell startup. If a name is already taken (builtin, command, function, or alias defined by an earlier plugin), it is silently skipped — no clobbering.

**Load order matters:** `mo-projects` should be listed *before* any plugin whose names you want to take precedence over project names, and *after* any plugin whose names should win on collision.

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `MO_PROJECTS_PROJ_DIR` | `~/projects` (or `~/Projects`) | Path to the directory whose subdirectories become aliases. |

Set in `conf.zsh` to override:

```zsh
MO_PROJECTS_PROJ_DIR=~/work
```

**Dependencies:** `fzf` (`sudo apt install fzf`) for `p`.
