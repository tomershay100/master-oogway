# Provides: welcome banner — system snapshot printed on every shell open.

# Wrapped in an anonymous function so locals don't leak into the shell.
() {
    local kernel up_secs up_str date_line
    local NAME= PRETTY_NAME= os_name=
    kernel="$(uname -r)"
    IFS=. read -r up_secs _ < /proc/uptime
    up_str="$(( up_secs / 86400 ))d $(( up_secs % 86400 / 3600 ))h $(( up_secs % 3600 / 60 ))m"
    zmodload zsh/datetime
    strftime -s date_line '%a, %d %b %Y · %H:%M' $EPOCHSECONDS
    [[ -r /etc/os-release ]] && . /etc/os-release 2>/dev/null
    os_name="${PRETTY_NAME:-${NAME:-$(uname -s)}}"

    print -P ""
    print -P "  %F{245}host%f   %F{cyan}%B${USER}%b%F{245} @ %f%F{green}%B${HOST%%.*}%b%f"
    print -P "  %F{245}os  %f   %F{magenta}${os_name}%f"
    print -P "  %F{245}sys %f   %F{blue}${kernel}%f"
    print -P "  %F{245}now %f   %F{yellow}${date_line}%f"
    print -P "  %F{245}up  %f   %F{green}${up_str}%f"
    print -P ""
}
