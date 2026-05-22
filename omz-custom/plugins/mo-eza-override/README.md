# mo-eza-override

Replaces `ls`, `ll`, `l`, `la`, and `tree` with `eza` (enhanced ls). Falls back to the system commands if `eza` is not installed.

**Dependencies:** `eza` — falls back to system `ls`/`tree` if not installed.

| Escape hatch | Bypasses to |
|---|---|
| `rls` or `\ls` | system `ls` |
| `rtree` or `\tree` | system `tree` |
