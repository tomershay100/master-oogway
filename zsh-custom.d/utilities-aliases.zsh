# Utilities

############# bat/batcat: cat replacement  ##############
if command -v batcat &> /dev/null; then
	_bat_cmd="batcat"
elif command -v bat &> /dev/null; then
	_bat_cmd="bat"
fi

if [[ -n "${_bat_cmd:-}" ]]; then
	alias rcat='\cat'   # \ bypasses aliases, calls the real binary
	alias cat="${_bat_cmd} --theme Coldark-Dark --paging never --style=plain"
	alias pcat="cat --style=full"

	alias rless='\less' # \ bypasses aliases, calls the real binary
	alias less="${_bat_cmd} --theme Coldark-Dark --paging always"
	alias pless="less --style=plain"
fi
unset _bat_cmd

############# eza: ls replacement ##############
if command -v eza &> /dev/null; then
	alias rls='\ls'     # \ bypasses aliases, calls the real binary
	alias ls="eza -F" # --hyperlink has known bug when pipeing
	alias lsa="ls -A"
	alias ll="lsa -l --smart-group --time-style=long-iso"
	alias l="ls -l --no-user --smart-group --time-style=long-iso"
	alias la="l -A"
	alias lg="ls --git --git-ignore"
	alias rtree='\tree' # \ bypasses aliases, calls the real binary
	alias tree="lg --tree"
else
	alias ls="ls --file-type --color=tty"
	alias lsa="ls -A"
	alias l="ls -goth --time-style=long-iso"
	alias la="l -A"
	alias ll="lsa -lth --time-style=long-iso"
fi

############# neovim: vim improved ##############
if command -v nvim &> /dev/null; then
	alias rvim='\vim'   # \ bypasses aliases, calls the real binary
	alias vim="nvim"
fi

_ls_after_cd()
{
	ls
}

[[ ${chpwd_functions[(Ie)_ls_after_cd]:-0} -eq 0 ]] && chpwd_functions+=(_ls_after_cd)

############# grep ##############
alias grep="grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox} --exclude={'*.so','*.apd','*.pd'}"
alias grepi="grep -i"

############# find ##############
alias f="find . | grepi"

############# other utilities ##############
alias vizsh="vim ~/.zshrc"
alias soursh="source ~/.zshrc"

_cwhich()
{
	cat "$(which "$1")"
}
alias cwhich=_cwhich

_vwhich()
{
	vim "$(which "$1")"
}
alias vwhich=_vwhich

_echo_ret()
{
	echo $?
}
alias '?'="_echo_ret"

_confirm_reboot()
{
	echo "This is $(hostname). Are you sure you want to reboot the system? (y/N)"
	read -r ans
	[[ "$ans" =~ ^[Yy]([Ee][Ss])?$ ]] && command reboot
}
alias reboot="_confirm_reboot"

alias natip="curl -s ifconfig.me"

command -v flatpak &>/dev/null && alias gnucash="WEBKIT_DISABLE_COMPOSITING_MODE=1 flatpak run org.gnucash.GnuCash"

############# build ##############
if command -v colormake &>/dev/null && command -v banner &>/dev/null; then
    alias m="colormake -j\$(nproc) && banner PASSED || (banner FAILED; false)"
else
    alias m="make -j\$(nproc)"
fi
alias mc="make clean"

############# general quality-of-life ##############
alias cp="cp -i"              # prompt before overwrite
alias mv="mv -i"              # prompt before overwrite
alias mkdir="mkdir -pv"       # create parents silently, print each new dir
alias ip="ip --color=auto"    # colorize ip addr / ip route output
alias diff="diff --color=auto"
alias h="history 50"
