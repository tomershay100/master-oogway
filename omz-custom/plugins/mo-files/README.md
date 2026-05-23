# mo-files

File management helpers.

| Command | Description |
|---------|-------------|
| `extract <file>` | extract any archive — `.tar.gz` `.tar.zst` `.zip` `.7z` `.rar` and more |
| `compress [<archive>] <file\|dir> ...` | create an archive; format by extension; defaults to `<dirname>.tar.zst` |
| `bak <file>` | copy file to `<file>.bak.YYYYMMDD_HHMMSS` |
| `sizeof <path>` | disk usage of paths, sorted ascending by size |
| `fp [dir]` | fuzzy-select a file and copy its full path to clipboard |

`extract` runs a path-traversal scan before extracting zip files — `.zip` archives go into a named subdirectory. `compress` refuses to overwrite an existing archive.

**Dependencies:** `fzf` (`fp`), plus per-format tools (`tar`, `zstd`, `zip`, `7z`, etc.) — each checked at call time with an install hint.
