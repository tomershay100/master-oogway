# _mo_color_pick.zsh — interactive 256-color TUI picker (`color pick`)

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
#
# The caller owns the tty mode. This used to set raw mode and restore it around
# every single keystroke, which left ISIG re-enabled in the gap between reads:
# a Ctrl+C arriving in that window was delivered as a real SIGINT and killed
# the shell, instead of being read as \x03 and treated as cancel. Setting it
# once around the whole loop closes that window.
_mo_pick_read_key() {
	local key c2 c3
	{
		read -k1 key
		if [[ "$key" == $'\e' ]]; then
			# zsh's own timeout, not `stty min 0 time 1`: `read -k` calls the
			# shell's setcbreak(), which unconditionally re-applies VMIN=1
			# VTIME=0 from its saved tty state and so undoes the stty on the
			# line before. A bare Esc therefore blocked until some other key
			# arrived — with -isig still in force, so Ctrl+C could not break
			# out either. Affects Linux identically; it is zsh's utils.c.
			c2=''
			read -t 0.05 -k1 c2 2>/dev/null || c2=''
			if [[ -z "$c2" ]]; then
				REPLY=esc
			elif [[ "$c2" == '[' || "$c2" == 'O' ]]; then
				c3=''
				read -k1 c3 2>/dev/null || c3=''
				case "$c3" in
					A) REPLY=up ;;
					B) REPLY=down ;;
					C) REPLY=right ;;
					D) REPLY=left ;;
					H) REPLY=home ;;
					F) REPLY=end ;;
					5) read -k1 _ 2>/dev/null; REPLY=pgup ;;
					6) read -k1 _ 2>/dev/null; REPLY=pgdn ;;
					*) REPLY=unknown ;;
				esac
			else
				REPLY=esc
			fi
		else
			case "$key" in
				$'\x03')           REPLY=q ;;       # Ctrl+C → treat as cancel
				$'\n'|$'\r')       REPLY=enter ;;
				$'\x7f'|$'\b')     REPLY=backspace ;;
				q|Q)               REPLY=q ;;
				g)                 REPLY=home ;;
				G)                 REPLY=end ;;
				[0-9])             REPLY="$key" ;;
				*)                 REPLY=unknown ;;
			esac
		fi
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
		_mo_xterm_to_rgb "$i"
		r=$_MO_RGB_R; g=$_MO_RGB_G; b=$_MO_RGB_B
		printf '\e[%d;%dH %s  %s ' "$row" "$col" "$(_mo_bg "$r" "$g" "$b" "$i")" "$(_mo_reset)"
	done
	footer=$(( grid_top + 17 ))
	printf '\e[%d;1H──────────────────────────────────────────────────────────────' "$footer"
	printf '\e[%d;1H  \e[2m←→↑↓\e[0m move    \e[2mPgUp/PgDn\e[0m ±16    \e[2mHome/End\e[0m 0/255' "$((footer + 1))"
	printf '\e[%d;1H  \e[2mEnter\e[0m confirm    \e[2mq/Esc\e[0m cancel    \e[2mdigits + Enter\e[0m jump' "$((footer + 2))"
}

# Repaint rows 2 + 3: the live "Selected: ... #hex name" line and the preview band.
_mo_pick_draw_header() {
	local idx=$1 buffer="$2" r g b name extra=''
	_mo_xterm_to_rgb "$idx"
	r=$_MO_RGB_R; g=$_MO_RGB_G; b=$_MO_RGB_B
	name=$(_mo_pick_name_for "$idx")
	[[ -n "$buffer" ]] && extra="   (typing: ${buffer})"
	printf '\e[2;1H\e[2K  Selected:  %3d   #%02x%02x%02x   %s%s' \
		"$idx" "$r" "$g" "$b" "$name" "$extra"
	printf '\e[3;1H\e[2K  Preview:   %s            %s  %sThe quick brown fox jumps over the lazy dog%s' \
		"$(_mo_bg "$r" "$g" "$b" "$idx")" "$(_mo_reset)" "$(_mo_fg "$r" "$g" "$b" "$idx")" "$(_mo_reset)"
}

# Repaint a single swatch cell. active=1 wraps in bright yellow [brackets].
_mo_pick_paint_cell() {
	local idx=$1 active=$2 grid_top=$3 r g b
	local row=$(( grid_top + idx / 16 ))
	local col=$(( 3 + (idx % 16) * 4 ))
	_mo_xterm_to_rgb "$idx"
	r=$_MO_RGB_R; g=$_MO_RGB_G; b=$_MO_RGB_B
	if (( active )); then
		printf '\e[%d;%dH\e[1;33m[\e[0m%s  %s\e[1;33m]\e[0m' \
			"$row" "$col" "$(_mo_bg "$r" "$g" "$b" "$idx")" "$(_mo_reset)"
	else
		printf '\e[%d;%dH %s  %s ' \
			"$row" "$col" "$(_mo_bg "$r" "$g" "$b" "$idx")" "$(_mo_reset)"
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
	# Global, not local: zsh tears a function's locals down BEFORE running its
	# EXIT trap, so a trap referring to a local restores `stty ""` and leaves
	# the terminal with no echo and no Ctrl+C. Verified:
	#   f(){ local S=x; trap 'print "[$S]"' EXIT; return 7 }; f   ->  []
	typeset -g _MO_PICK_STTY
	{
		_MO_PICK_STTY=$(stty -g 2>/dev/null)
		tput smcup; tput civis
		# Raw mode once, for the whole session. -isig makes Ctrl+C arrive as a
		# literal \x03 that the key reader turns into "cancel"; the restore is
		# in the trap as well as at the end, so an unexpected exit cannot leave
		# the terminal without echo.
		stty -echo -icanon -isig min 1 time 0 2>/dev/null
		trap 'stty "$_MO_PICK_STTY" 2>/dev/null; tput cnorm; tput rmcup' EXIT TERM HUP

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

		stty "$_MO_PICK_STTY" 2>/dev/null
		tput cnorm; tput rmcup
		trap - EXIT TERM HUP
	} always {
		stty "$_MO_PICK_STTY" 2>/dev/null
		tput cnorm 2>/dev/null; tput rmcup 2>/dev/null
	} >/dev/tty </dev/tty

	(( cancelled )) && return 130

	local r g b name
	_mo_xterm_to_rgb "$idx"
	r=$_MO_RGB_R; g=$_MO_RGB_G; b=$_MO_RGB_B
	name=$(_mo_pick_name_for "$idx")
	printf '%d\t#%02x%02x%02x\t%s\n' "$idx" "$r" "$g" "$b" "$name"
}
