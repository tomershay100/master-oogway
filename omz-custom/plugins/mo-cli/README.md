# mo-cli

The `master-oogway` meta CLI — manage the framework from the command line.

| Command | Description |
|---------|-------------|
| `master-oogway update` | pull latest master-oogway and re-run `install.sh` |
| `master-oogway uninstall` | run `install.sh --uninstall` (interactive) |
| `master-oogway version` | print the installed version (date + commit) |
| `master-oogway configure [args]` | open `dragon-configure` (forwards args, e.g. `--preset short`) |
| `master-oogway edit` | open `~/.zshrc` in `$EDITOR` |
| `master-oogway diff-zshrc [tool]` | diff the current template against `~/.zshrc` (additions in your file show as `+`; unadopted template changes show as `-`); uses `[tool]`, else git's `diff.tool`, else `diff -u` |
| `master-oogway ssh-forwarding setup` | add `SendEnv DRAGON__*` block to `~/.ssh/config` |
| `master-oogway ssh-forwarding remove` | remove the `SendEnv DRAGON__*` block from `~/.ssh/config` |
| `master-oogway path` | print the master-oogway install directory |
| `master-oogway help` | list all subcommands |
