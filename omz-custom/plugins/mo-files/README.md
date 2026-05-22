# mo-files

File management helpers.

| Command | Description |
|---------|-------------|
| `extract <file>` | extract any archive format — zip, tar, gz, bz2, xz, 7z, rar, and more |
| `bak <file>` | copy file to `<file>.bak.YYYYMMDD_HHMMSS` |
| `sizeof <path>` | disk usage of paths, sorted ascending by size |
| `fp [dir]` | fuzzy-select a file and copy its full path to clipboard |

`extract` runs a path-traversal scan before extracting zip files. `.zip` archives extract into a subdirectory named after the archive to avoid polluting the current directory.

**Dependencies:** `fzf` (fp), plus archive-format tools (`unzip`, `tar`, `7z`, etc.) for `extract` — each checked at call time with an install hint.
