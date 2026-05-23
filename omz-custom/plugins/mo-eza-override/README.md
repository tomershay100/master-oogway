# mo-eza-override

Replaces `ls`, `ll`, `l`, `la`, `lsa`, `lg`, and `tree` with `eza` equivalents. No-op if `eza` is not installed — the built-in `ls` aliases from oh-my-zsh take effect instead.

| Command | Description |
|---------|-------------|
| `ls` | list with file-type indicators |
| `lsa` | `ls -A` (include hidden files) |
| `l` | long list, no owner, ISO timestamps |
| `la` | `l -A` (include hidden files) |
| `ll` | long list with smart groups and ISO timestamps |
| `lg` | `ls` with git status and `.gitignore` awareness |
| `tree` | `lg --tree` recursive tree view |

To bypass: use `\ls`, `\ll`, etc. (backslash-quoting skips aliases in any shell).

**Dependencies:** `eza` — falls back to system `ls` aliases if not installed.
