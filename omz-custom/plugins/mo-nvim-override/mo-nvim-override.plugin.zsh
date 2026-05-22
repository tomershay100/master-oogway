# Remove this file to use the system vim as-is.

if command -v nvim &>/dev/null; then
    alias rvim='\vim'   # escape hatch: rvim bypasses this override
    alias vim="nvim"
fi
