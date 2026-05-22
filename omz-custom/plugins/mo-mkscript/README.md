# mo-mkscript

Scaffold a new shell script with the project's standard header and open it in `$EDITOR`.

| Command | Description |
|---------|-------------|
| `mkscript <path>` | create `<path>` with shebang + header + `set -Eeuo pipefail`, `chmod +x` it, and open in `$EDITOR` |

The generated template:

```bash
#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# script_name.sh -
# ------------------------------------------------------------------------------
set -Eeuo pipefail
```

Refuses to overwrite an existing file. Fails clearly if the parent directory does not exist.
