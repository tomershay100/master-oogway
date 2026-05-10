#!/usr/bin/env zsh
# ------------------------------------------------------------------------------
# .zshenv - Sourced for ALL zsh invocations (interactive, scripts, cron, etc.)
# Keep this minimal: only variables that non-interactive shells also need.
#
# Sourced by:
#   - Interactive terminals (before .zshrc)
#   - zsh scripts (e.g. any script with #!/usr/bin/env zsh)
#   - cron jobs running under zsh
#   - git hooks if zsh is the login shell
#   - sudoedit / visudo (picks up EDITOR)
#   - Desktop environment launchers that spawn zsh
# ------------------------------------------------------------------------------

# Preferred editor: nvim > vim > vi
if command -v nvim &> /dev/null; then
    export EDITOR="nvim"
    export VISUAL="nvim"
elif command -v vim &> /dev/null; then
    export EDITOR="vim"
    export VISUAL="vim"
else
    export EDITOR="vi"
    export VISUAL="vi"
fi
