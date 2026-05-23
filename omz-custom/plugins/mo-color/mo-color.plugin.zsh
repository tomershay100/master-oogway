
# ── Named colors (matches dragon theme COLORS map) ────────────────────────────
typeset -gA _MO_COLORS=(
    [black]=0     [red]=1       [green]=2     [yellow]=3
    [blue]=4      [magenta]=5   [cyan]=6      [white]=7
    [gray]=8      [grey]=8      [maroon]=9    [lime]=10
    [olive]=11    [navy]=12     [fuchsia]=13  [aqua]=14
    [silver]=15
)

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

# ── Main ──────────────────────────────────────────────────────────────────────
color() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
        cat <<'EOF'
Usage:
  color palette                     print named colors + all 256 xterm swatches
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

    # Text mode: read from pipe or use "hello world"
    local text
    if [[ -t 0 ]]; then
        text="hello world"
    else
        text="$(command cat)"
    fi

    _mo_parse_color "$fg_spec" || return 1
    local fcr=$_MO_COLOR_R fcg=$_MO_COLOR_G fcb=$_MO_COLOR_B

    if [[ -n "$bg_spec" ]]; then
        _mo_parse_color "$bg_spec" || return 1
        local bcr=$_MO_COLOR_R bcg=$_MO_COLOR_G bcb=$_MO_COLOR_B
        printf '%s%s%s%s\n' \
            "$(_mo_fg $fcr $fcg $fcb)" "$(_mo_bg $bcr $bcg $bcb)" \
            "$text" "$(_mo_reset)"
    else
        printf '%s%s%s\n' "$(_mo_fg $fcr $fcg $fcb)" "$text" "$(_mo_reset)"
    fi
}
