# Remove this file to use the system ls as-is.

if command -v eza &>/dev/null; then
    alias ls="eza -F"   # --hyperlink has a known bug when piping
    alias lsa="ls -A"
    alias ll="lsa -l --smart-group --time-style=long-iso"
    alias l="ls -l --no-user --smart-group --time-style=long-iso"
    alias la="l -A"
    alias lg="ls --git --git-ignore"
    alias tree="lg --tree"
else
    alias ls="ls --file-type --color=tty"
    alias lsa="ls -A"
    alias l="ls -goth --time-style=long-iso"
    alias la="l -A"
    alias ll="lsa -lth --time-style=long-iso"
fi
