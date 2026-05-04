# Provides: welcome banner — system snapshot printed on every shell open.

# Wrapped in an anonymous function so locals don't leak into the shell.
() {
    local kernel up date_line
    kernel="$(uname -smr)"
    up="$(uptime -p 2>/dev/null | sed 's/^up //')"
    date_line="$(date '+%a, %d %b %Y · %H:%M')"
    print -P ""
    print -P "  %F{cyan}╭─%f %B${USER}@${HOST}%b   %F{245}${kernel}%f"
    print -P "  %F{cyan}╰─%f ${date_line}   %F{245}up ${up}%f"
    print -P ""
}
