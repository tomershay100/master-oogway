# Provides: eza as ls/ll/l/la/lsa/tree replacement.
# Requires: eza (optional — falls back to ls --color if not installed)
# Remove this file to use the system ls as-is.

if command -v eza &>/dev/null; then
    alias rls='\ls'     # escape hatch: rls bypasses this override
    alias ls="eza -F"   # --hyperlink has a known bug when piping
    alias lsa="ls -A"
    alias ll="lsa -l --smart-group --time-style=long-iso"
    alias l="ls -l --no-user --smart-group --time-style=long-iso"
    alias la="l -A"
    alias lg="ls --git --git-ignore"
    alias rtree='\tree'
    alias tree="lg --tree"
else
    alias ls="ls --file-type --color=tty"
    alias lsa="ls -A"
    alias l="ls -goth --time-style=long-iso"
    alias la="l -A"
    alias ll="lsa -lth --time-style=long-iso"
fi
