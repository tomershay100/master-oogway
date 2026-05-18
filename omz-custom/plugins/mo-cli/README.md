# mo-cli

The `master-oogway` command dispatcher — meta CLI for managing the framework.

| Command | Description |
|---------|-------------|
| `master-oogway update` | pull latest master-oogway and re-run `install.sh` |
| `master-oogway uninstall` | run `install.sh --uninstall` (interactive) |
| `master-oogway version` | print the installed dragon version (date + commit) |
| `master-oogway configure [args]` | open `dragon-configure` (forwards args, e.g. `--preset short`) |
| `master-oogway edit` | open `~/.zshrc` in `$EDITOR` |
| `master-oogway path` | print the master-oogway install dir |
| `master-oogway help` | show all subcommands |
