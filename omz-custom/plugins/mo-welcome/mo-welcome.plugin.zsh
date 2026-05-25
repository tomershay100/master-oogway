_mo_welcome_field_host() {
    print -P "  %F{245}host%f   %F{cyan}%B${USER}%b%F{245} @ %f%F{green}%B${HOST%%.*}%b%f"
}

_mo_welcome_field_os() {
    local NAME= PRETTY_NAME= os_name=
    [[ -r /etc/os-release ]] && . /etc/os-release 2>/dev/null
    os_name="${PRETTY_NAME:-${NAME:-$(uname -s)}}"
    print -P "  %F{245}os  %f   %F{magenta}${os_name}%f"
}

_mo_welcome_field_sys() {
    print -P "  %F{245}sys %f   %F{blue}$(uname -r)%f"
}

_mo_welcome_field_now() {
    local date_line
    zmodload zsh/datetime
    strftime -s date_line '%a, %d %b %Y · %H:%M' $EPOCHSECONDS
    print -P "  %F{245}now %f   %F{yellow}${date_line}%f"
}

_mo_welcome_field_up() {
    local up_secs up_str
    IFS=. read -r up_secs _ < /proc/uptime
    up_str="$(( up_secs / 86400 ))d $(( up_secs % 86400 / 3600 ))h $(( up_secs % 3600 / 60 ))m"
    print -P "  %F{245}up  %f   %F{green}${up_str}%f"
}

_mo_welcome_field_ip() {
    local ip
    ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')
    [[ -n "$ip" ]] && print -P "  %F{245}ip  %f   %F{cyan}${ip}%f"
}

_mo_welcome_field_shell() {
    print -P "  %F{245}sh  %f   %F{blue}zsh ${ZSH_VERSION}%f"
}

_mo_welcome_field_load() {
    local load1 cores pct color
    read -r load1 _ < /proc/loadavg
    cores=$(nproc)
    printf -v pct "%.0f" "$(( load1 * 100 / cores ))"
    if   (( pct >= 80 )); then color=red
    elif (( pct >= 50 )); then color=yellow
    else                       color=green
    fi
    printf -v load1 "%.2f" "$load1"
    print -P "  %F{245}load%f   %F{${color}}${load1} load  ·  ${cores} cores  ·  ${pct}%% busy%f"
}

_mo_welcome_field_mem() {
    local total avail used_kb pct
    total=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
    avail=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
    used_kb=$(( total - avail ))
    pct=$(( used_kb * 100 / total ))
    local used_gb total_gb
    printf -v used_gb  "%.1f" "$(( used_kb  / 1024.0 / 1024.0 ))"
    printf -v total_gb "%.1f" "$(( total / 1024.0 / 1024.0 ))"
    print -P "  %F{245}mem %f   %F{magenta}${used_gb} / ${total_gb} GB (${pct}%%)%f"
}

_mo_welcome_field_tmux() {
    [[ -n "${TMUX:-}" ]] || return 0
    local session
    session=$(tmux display-message -p '#S' 2>/dev/null) || return 0
    print -P "  %F{245}tmux%f   %F{green}${session}%f"
}

_mo_welcome_field_ssh() {
    [[ -n "${SSH_CONNECTION:-}" ]] || return 0
    print -P "  %F{245}ssh %f   %F{yellow}${USER}@${HOST%%.*} (remote)%f"
}

() {
    local field
    local -a fields
    fields=(${(z)${MO_WELCOME_FIELDS:-host os sys now up}})
    print -P ""
    for field in "${fields[@]}"; do
        if (( ${+functions[_mo_welcome_field_${field}]} )); then
            _mo_welcome_field_${field}
        fi
    done
    print -P ""
}
