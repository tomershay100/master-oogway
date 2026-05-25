
source "${0:h}/../../lib/colors.zsh"

# ── 256-color xterm palette — index → R G B ───────────────────────────────────
# Used to convert xterm-256 indices to 24-bit RGB for terminal output.
_mo_xterm_to_rgb() {
    local idx="$1"
    local r g b
    if (( idx < 16 )); then
        # The 16 system colors — well-known approximations.
        # +1 because zsh arrays are 1-indexed.
        local -a sys_r=(0 128 0 128 0 128 0 192 128 255 0 255 0 255 0 255)
        local -a sys_g=(0 0 128 128 0 0 128 192 128 0 255 255 0 0 128 255)
        local -a sys_b=(0 0 0 0 128 128 128 192 128 0 0 0 255 255 255 255)
        r=${sys_r[$((idx+1))]}; g=${sys_g[$((idx+1))]}; b=${sys_b[$((idx+1))]}
    elif (( idx < 232 )); then
        local i=$(( idx - 16 ))
        r=$(( (i / 36) * 51 ))
        g=$(( ((i % 36) / 6) * 51 ))
        b=$(( (i % 6) * 51 ))
    else
        local v=$(( (idx - 232) * 10 + 8 ))
        r=$v; g=$v; b=$v
    fi
    printf '%d %d %d' "$r" "$g" "$b"
}

# ── Parse a color spec → R G B ────────────────────────────────────────────────
# Accepts: 0xRRGGBB / 0XRRGGBB  |  #RRGGBB  |  0-255 (xterm index)  |  named
# Sets _MO_COLOR_R, _MO_COLOR_G, _MO_COLOR_B; returns 1 on parse failure.
_mo_parse_color() {
    local spec="${(L)1}"   # lowercase
    _MO_COLOR_R="" _MO_COLOR_G="" _MO_COLOR_B=""

    # Named color → xterm index → RGB
    if [[ -n "${_MO_COLORS[$spec]:-}" ]]; then
        local idx="${_MO_COLORS[$spec]}"
        read -r _MO_COLOR_R _MO_COLOR_G _MO_COLOR_B < <(_mo_xterm_to_rgb "$idx")
        return 0
    fi

    # Hex: 0xRRGGBB or #RRGGBB
    local hex=""
    if [[ "$spec" =~ ^0x([0-9a-f]{6})$ ]]; then
        hex="${match[1]}"
    elif [[ "$spec" =~ ^#([0-9a-f]{6})$ ]]; then
        hex="${match[1]}"
    fi
    if [[ -n "$hex" ]]; then
        _MO_COLOR_R=$(( 16#${hex[1,2]} ))
        _MO_COLOR_G=$(( 16#${hex[3,4]} ))
        _MO_COLOR_B=$(( 16#${hex[5,6]} ))
        return 0
    fi

    # Decimal xterm index 0–255
    if [[ "$spec" =~ ^[0-9]+$ ]] && (( 10#$spec <= 255 )); then
        read -r _MO_COLOR_R _MO_COLOR_G _MO_COLOR_B < <(_mo_xterm_to_rgb "$(( 10#$spec ))")
        return 0
    fi

    echo "color: unknown color '${1}'" >&2
    return 1
}

_mo_fg() { printf '\e[38;2;%d;%d;%dm' "$1" "$2" "$3"; }
_mo_bg() { printf '\e[48;2;%d;%d;%dm' "$1" "$2" "$3"; }
_mo_reset() { printf '\e[0m'; }

# ── color palette ─────────────────────────────────────────────────────────────
_mo_color_palette() {
    local -a names=(
        black red green yellow blue magenta cyan white
        gray maroon lime olive navy fuchsia aqua silver
    )
    echo "── Named colors ──────────────────────────────────────────"
    local name idx r g b lum cfr cfg cfb col=0
    for name in "${names[@]}"; do
        idx="${_MO_COLORS[$name]}"
        read -r r g b < <(_mo_xterm_to_rgb "$idx")
        lum=$(( r * 299 + g * 587 + b * 114 ))
        if (( lum >= 128000 )); then cfr=0; cfg=0; cfb=0; else cfr=255; cfg=255; cfb=255; fi
        printf '%s %-9s%s%s%-9s%s' \
            "$(_mo_bg "$r" "$g" "$b")$(_mo_fg $cfr $cfg $cfb)"  "$name"  "$(_mo_reset)" \
            "$(_mo_fg "$r" "$g" "$b")"  "$name"  "$(_mo_reset)"
        (( ++col % 4 == 0 )) && echo || printf '  '
    done
    (( col % 4 != 0 )) && echo

    echo ""
    echo "── 256 xterm colors ──────────────────────────────────────"
    local i
    for (( i = 0; i <= 255; i++ )); do
        read -r r g b < <(_mo_xterm_to_rgb "$i")
        lum=$(( r * 299 + g * 587 + b * 114 ))
        if (( lum >= 128000 )); then cfr=0; cfg=0; cfb=0; else cfr=255; cfg=255; cfb=255; fi
        printf '%s %3d %s%s%3d%s' \
            "$(_mo_bg "$r" "$g" "$b")$(_mo_fg $cfr $cfg $cfb)"  "$i"  "$(_mo_reset)" \
            "$(_mo_fg "$r" "$g" "$b")"  "$i"  "$(_mo_reset)"
        (( (i + 1) % 8 == 0 )) && echo || printf '  '
    done
    (( 256 % 8 != 0 )) && echo
}

# ── Interactive picker (`color pick`) ─────────────────────────────────────────
# Reverse lookup: xterm index → first matching named-color, or "-" for none.
_mo_pick_name_for() {
    local idx="$1" name
    for name in "${(@k)_MO_COLORS}"; do
        [[ "${_MO_COLORS[$name]}" == "$idx" ]] && { printf '%s' "$name"; return; }
    done
    printf '%s' '-'
}

# Read one keystroke (or an escape sequence) and set REPLY to a canonical name.
# Recognised: up down left right home end pgup pgdn enter esc q backspace 0-9.
_mo_pick_read_key() {
    local key c2 c3 stty_save
    stty_save=$(stty -g 2>/dev/null)
    {
        stty -echo -icanon min 1 time 0 2>/dev/null
        read -k1 key
        if [[ "$key" == $'\e' ]]; then
            c2=''
            read -k1 -t 0.05 c2 2>/dev/null
            if [[ -z "$c2" ]]; then
                REPLY=esc
            elif [[ "$c2" == '[' || "$c2" == 'O' ]]; then
                c3=''
                read -k1 -t 0.05 c3 2>/dev/null
                case "$c3" in
                    A) REPLY=up ;;
                    B) REPLY=down ;;
                    C) REPLY=right ;;
                    D) REPLY=left ;;
                    H) REPLY=home ;;
                    F) REPLY=end ;;
                    5) read -k1 -t 0.05 _ 2>/dev/null; REPLY=pgup ;;
                    6) read -k1 -t 0.05 _ 2>/dev/null; REPLY=pgdn ;;
                    *) REPLY=unknown ;;
                esac
            else
                REPLY=esc
            fi
        else
            case "$key" in
                $'\n'|$'\r')       REPLY=enter ;;
                $'\x7f'|$'\b')     REPLY=backspace ;;
                q|Q)               REPLY=q ;;
                g)                 REPLY=home ;;
                G)                 REPLY=end ;;
                [0-9])             REPLY="$key" ;;
                *)                 REPLY=unknown ;;
            esac
        fi
    } always {
        stty "$stty_save" 2>/dev/null
    }
}

# Draw the unchanging UI: title, blank header rows, 16×16 swatch grid, footer.
_mo_pick_draw_static() {
    local grid_top=$1 i r g b row col footer
    tput clear
    printf '\e[1;1H\e[1m── color pick ─────────────────────────────────────────────────\e[0m'
    for (( i = 0; i < 256; i++ )); do
        row=$(( grid_top + i / 16 ))
        col=$(( 3 + (i % 16) * 4 ))
        read -r r g b < <(_mo_xterm_to_rgb "$i")
        printf '\e[%d;%dH \e[48;2;%d;%d;%dm  \e[0m ' "$row" "$col" "$r" "$g" "$b"
    done
    footer=$(( grid_top + 17 ))
    printf '\e[%d;1H──────────────────────────────────────────────────────────────' "$footer"
    printf '\e[%d;1H  \e[2m←→↑↓\e[0m move    \e[2mPgUp/PgDn\e[0m ±16    \e[2mHome/End\e[0m 0/255' "$((footer + 1))"
    printf '\e[%d;1H  \e[2mEnter\e[0m confirm    \e[2mq/Esc\e[0m cancel    \e[2mdigits + Enter\e[0m jump' "$((footer + 2))"
}

# Repaint rows 2 + 3: the live "Selected: ... #hex name" line and the preview band.
_mo_pick_draw_header() {
    local idx=$1 buffer="$2" r g b name extra=''
    read -r r g b < <(_mo_xterm_to_rgb "$idx")
    name=$(_mo_pick_name_for "$idx")
    [[ -n "$buffer" ]] && extra="   (typing: ${buffer})"
    printf '\e[2;1H\e[2K  Selected:  %3d   #%02x%02x%02x   %s%s' \
        "$idx" "$r" "$g" "$b" "$name" "$extra"
    printf '\e[3;1H\e[2K  Preview:   \e[48;2;%d;%d;%dm            \e[0m  \e[38;2;%d;%d;%dmThe quick brown fox jumps over the lazy dog\e[0m' \
        "$r" "$g" "$b" "$r" "$g" "$b"
}

# Repaint a single swatch cell. active=1 wraps in bright yellow [brackets].
_mo_pick_paint_cell() {
    local idx=$1 active=$2 grid_top=$3 r g b
    local row=$(( grid_top + idx / 16 ))
    local col=$(( 3 + (idx % 16) * 4 ))
    read -r r g b < <(_mo_xterm_to_rgb "$idx")
    if (( active )); then
        printf '\e[%d;%dH\e[1;33m[\e[0m\e[48;2;%d;%d;%dm  \e[0m\e[1;33m]\e[0m' \
            "$row" "$col" "$r" "$g" "$b"
    else
        printf '\e[%d;%dH \e[48;2;%d;%d;%dm  \e[0m ' \
            "$row" "$col" "$r" "$g" "$b"
    fi
}

_mo_color_pick() {
    # Capture-friendly: UI on /dev/tty (so $(color pick) doesn't swallow it),
    # result on stdout. Stderr must still be a TTY for our usability checks
    # (stdout will be a pipe under command substitution).
    if [[ ! -t 0 || ! -t 2 ]]; then
        printf 'color pick: needs an interactive terminal\n' >&2
        return 1
    fi
    local cols rows
    cols=$(tput cols 2>/dev/null) || cols=80
    rows=$(tput lines 2>/dev/null) || rows=24
    if (( cols < 70 || rows < 23 )); then
        printf 'color pick: terminal too small (need 70×23, got %d×%d)\n' "$cols" "$rows" >&2
        return 1
    fi

    local idx=0 buffer='' grid_top=5 cancelled=1 prev
    {
        tput smcup; tput civis
        trap 'tput cnorm; tput rmcup' EXIT INT TERM HUP

        _mo_pick_draw_static "$grid_top"
        _mo_pick_draw_header "$idx" ""
        _mo_pick_paint_cell "$idx" 1 "$grid_top"

        while true; do
            _mo_pick_read_key
            prev=$idx
            case "$REPLY" in
                up)    (( idx >= 16 ))  && idx=$(( idx - 16 )) ;;
                down)  (( idx <= 239 )) && idx=$(( idx + 16 )) ;;
                left)  (( idx > 0 ))    && idx=$(( idx - 1 )) ;;
                right) (( idx < 255 ))  && idx=$(( idx + 1 )) ;;
                pgup)  idx=$(( idx >= 16 ? idx - 16 : 0 )) ;;
                pgdn)  idx=$(( idx <= 239 ? idx + 16 : 255 )) ;;
                home)  idx=0 ;;
                end)   idx=255 ;;
                [0-9])
                    buffer="${buffer}${REPLY}"
                    (( ${#buffer} > 3 )) && buffer="${buffer:1}"
                    _mo_pick_draw_header "$idx" "$buffer"
                    continue
                    ;;
                backspace)
                    [[ -n "$buffer" ]] && buffer="${buffer:0:-1}"
                    _mo_pick_draw_header "$idx" "$buffer"
                    continue
                    ;;
                enter)
                    if [[ -n "$buffer" ]]; then
                        local n=$(( 10#$buffer ))
                        (( n >= 0 && n <= 255 )) && { prev=$idx; idx=$n; }
                        buffer=''
                    else
                        cancelled=0
                        break
                    fi
                    ;;
                esc|q)
                    if [[ -n "$buffer" ]]; then
                        buffer=''
                        _mo_pick_draw_header "$idx" ""
                        continue
                    fi
                    break
                    ;;
                *) continue ;;
            esac
            (( idx != prev )) && {
                _mo_pick_paint_cell "$prev" 0 "$grid_top"
                _mo_pick_paint_cell "$idx"  1 "$grid_top"
            }
            _mo_pick_draw_header "$idx" "$buffer"
        done

        tput cnorm; tput rmcup
        trap - EXIT INT TERM HUP
    } >/dev/tty </dev/tty

    (( cancelled )) && return 130

    local r g b name
    read -r r g b < <(_mo_xterm_to_rgb "$idx")
    name=$(_mo_pick_name_for "$idx")
    printf '%d\t#%02x%02x%02x\t%s\n' "$idx" "$r" "$g" "$b" "$name"
}

# ── Main ──────────────────────────────────────────────────────────────────────
color() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
        cat <<'EOF'
Usage:
  color palette                     print named colors + all 256 xterm swatches
  color pick                        interactive picker — prints "idx\t#hex\tname" on Enter
  color <c>                         print <c> as a BG swatch and a FG label
  color <fg> [<bg>]                 print piped text (or "hello world") in <fg> on <bg>

Color formats:  0xRRGGBB  |  '#RRGGBB' (quote — # is a shell comment)  |  0-255  |  named (black navy fuchsia…)
EOF
        return
    fi

    # palette
    if [[ "${1:-}" == "palette" ]]; then
        _mo_color_palette
        return
    fi

    # interactive picker
    if [[ "${1:-}" == "pick" ]]; then
        _mo_color_pick
        return
    fi

    local fg_spec="$1"
    local bg_spec="${2:-}"

    # Single-color preview: no bg arg and no piped input → show swatch + label
    if [[ -z "$bg_spec" ]] && [[ -t 0 ]]; then
        _mo_parse_color "$fg_spec" || return 1
        local cr=$_MO_COLOR_R cg=$_MO_COLOR_G cb=$_MO_COLOR_B
        local lum=$(( cr * 299 + cg * 587 + cb * 114 ))
        local cfr cfg cfb
        if (( lum >= 128000 )); then cfr=0; cfg=0; cfb=0
        else cfr=255; cfg=255; cfb=255; fi
        printf '%s  %s  %s    %s%s%s\n' \
            "$(_mo_bg $cr $cg $cb)$(_mo_fg $cfr $cfg $cfb)"  "$fg_spec"  "$(_mo_reset)" \
            "$(_mo_fg $cr $cg $cb)"  "$fg_spec"  "$(_mo_reset)"
        return
    fi

    _mo_parse_color "$fg_spec" || return 1
    local fcr=$_MO_COLOR_R fcg=$_MO_COLOR_G fcb=$_MO_COLOR_B

    if [[ -n "$bg_spec" ]]; then
        _mo_parse_color "$bg_spec" || return 1
        local bcr=$_MO_COLOR_R bcg=$_MO_COLOR_G bcb=$_MO_COLOR_B
        if [[ -t 0 ]]; then
            printf '%s%s%s%s\n' \
                "$(_mo_fg $fcr $fcg $fcb)" "$(_mo_bg $bcr $bcg $bcb)" \
                "hello world" "$(_mo_reset)"
        else
            printf '%s' "$(_mo_fg $fcr $fcg $fcb)$(_mo_bg $bcr $bcg $bcb)"
            command cat
            printf '%s' "$(_mo_reset)"
        fi
    else
        if [[ -t 0 ]]; then
            printf '%s%s%s\n' "$(_mo_fg $fcr $fcg $fcb)" "hello world" "$(_mo_reset)"
        else
            printf '%s' "$(_mo_fg $fcr $fcg $fcb)"
            command cat
            printf '%s' "$(_mo_reset)"
        fi
    fi
}
