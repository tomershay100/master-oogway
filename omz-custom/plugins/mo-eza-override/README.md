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

To bypass: use `\ls`, `\ll`, etc. (backslash-quoting skips alias expansion).

This plugin ships commented out in `zshrc.master-oogway`; uncomment it there to
enable.

## Why `ls` is a function

Two eza changes broke the obvious `alias ls="eza -F"`, both on every platform —
Ubuntu 24.04 packages 0.18.2, so neither is macOS-specific:

- **0.18.0** gave `--classify` an optional value. A bare `-F` then swallows the
  next token unless it looks like a flag, so `ls somedir` fails with
  `error: invalid value 'somedir' for '--classify [<WHEN>]'`. Binding the value
  as `--classify=auto` keeps the path positional.
- **0.23.0** made eza read path names from stdin when stdin is not a TTY and no
  path operand was given. In a script, a pipeline, or an fzf preview pane that
  means `ls` lists whatever arrives on stdin instead of the current directory —
  or blocks on a pipe that never closes.

So `ls` binds the value and always passes an operand, which needs a function
rather than an alias.

**Dependencies:** `eza`.
