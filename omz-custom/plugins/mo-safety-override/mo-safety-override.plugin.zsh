# Provides: safety overrides for cp, mv, mkdir, and reboot.
# These change the default behavior of common system commands.
# Remove this file to restore the original behavior of all four commands.
# Escape-hatch aliases (rcp, rmv, rmkdir) bypass the overrides for scripting.

alias cp="cp -i"        # prompt before overwrite
alias mv="mv -i"        # prompt before overwrite
alias mkdir="mkdir -pv" # create parents silently, print each new dir

alias rcp='\cp'
alias rmv='\mv'
alias rmkdir='\mkdir'

_confirm_reboot() {
    echo "This is $(hostname). Are you sure you want to reboot the system? (y/N)"
    read -r ans
    [[ "$ans" =~ ^[Yy]([Ee][Ss])?$ ]] && command reboot
}
alias reboot="_confirm_reboot"
