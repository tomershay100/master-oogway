# mo-files

File management helpers.

| Command | Description |
|---------|-------------|
| `extract [--force-merge] <file>` | extract any archive — `.tar.gz` `.tar.zst` `.zip` `.7z` `.rar` and more |
| `compress [<archive>] <file\|dir> ...` | create an archive; format inferred from extension; defaults to `<dirname>.tar.zst` |
| `bak <file>` | copy file to `<file>.bak.YYYYMMDD_HHMMSS` |
| `sizeof <path>` | disk usage of paths, sorted ascending by size |
| `fp [dir]` | fuzzy-select a file and copy its full path to clipboard |

`extract` scans zip archives for path traversal before extracting — `.zip` files go into a named subdirectory and refuse to merge into an existing one unless `--force-merge` is passed. `compress` refuses to overwrite an existing archive.

**Dependencies:** `fzf` for `fp`; per-format tools (`tar`, `zstd`, `zip`, `7z`, etc.) for `extract`/`compress` — each checked at call time with an install hint.
