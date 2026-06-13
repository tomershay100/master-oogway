# configure/pick.zsh — TUI preset browser (dragon-configure --pick)

# Draw the header bar.
_dragon_pick_draw_frame() {
	print -P "%B%F{cyan}── dragon: Pick a preset ────────────────────────────────────────────%f%b"
	print -P "  %F{245}↑↓ navigate   Enter apply   Esc/q cancel%f"
	print ""
}

# Print a viewport-clipped preset list.
# $1 = selected index (1-based)
# $2 = viewport offset (first visible index, 1-based)
# $3 = viewport size (number of rows to show)
# $4 = total count
_dragon_pick_draw_list() {
	local sel="$1" voff="$2" vsize="$3" n="$4"
	local i name desc
	for (( i = voff; i < voff + vsize && i <= n; i++ )); do
		name="${_DRAGON_PRESET_NAMES[$i]}"
		desc="${_DRAGON_PRESET_DESC[$name]:-}"
		if (( i == sel )); then
			printf "  \033[7m %-24s  %-44s\033[m\n" "$name" "$desc"
		else
			printf "  \033[0m %-24s  %-44s\033[m\n" "$name" "$desc"
		fi
	done
	# Scroll indicator when list is taller than the viewport.
	if (( n > vsize )); then
		printf "  \033[90m  %d–%d of %d\033[m\n" "$voff" "$(( voff + vsize - 1 < n ? voff + vsize - 1 : n ))" "$n"
	fi
}

# Render the preview section for the preset at index $1.
# Applies the preset to _DRAGON_CURRENT in a local copy so the caller's
# _DRAGON_CURRENT is never mutated.
_dragon_pick_draw_preview() {
	local sel="$1"
	local name="${_DRAGON_PRESET_NAMES[$sel]}"
	print ""
	print -P "  %B%F{cyan}${name}%f%b  %F{245}${_DRAGON_PRESET_DESC[$name]:-}%f"
	local -A _pick_saved=( "${(@kv)_DRAGON_CURRENT}" )
	_dragon_apply_preset "$name"
	_dragon_render_preview
	# Restore
	_DRAGON_CURRENT=( "${(@kv)_pick_saved}" )
}

_dragon_pick_preset() {
	# Initialise schema if not already done (supports standalone --pick call).
	(( ${#_DRAGON_PRESET_NAMES} == 0 )) && {
		_dragon_init_defaults
		_dragon_init_types
		_dragon_init_hints
		_dragon_init_groups
		_dragon_init_presets || return 1
		_dragon_load_current_conf
	}

	local n=${#_DRAGON_PRESET_NAMES}
	(( n == 0 )) && { print -P "%F{red}✗%f No presets found."; return 1; }

	# Require a minimum terminal size: 72 cols for the list layout,
	# 16 rows for header (3) + list (≥3) + preview (≥5) + footer (1).
	local _pick_cols _pick_rows
	_pick_cols=$(tput cols  2>/dev/null) || _pick_cols=80
	_pick_rows=$(tput lines 2>/dev/null) || _pick_rows=24
	if (( _pick_cols < 72 || _pick_rows < 16 )); then
		print -P "%F{red}✗%f dragon-configure --pick: terminal too small (need 72×16, got ${_pick_cols}×${_pick_rows})" >&2
		return 1
	fi

	# Determine starting selection: match current preset from state, else 1.
	local sel=1
	_dragon_read_state
	local cur_preset="${_DRAGON_STATE[preset]:-}"
	local i=1
	for _p in "${_DRAGON_PRESET_NAMES[@]}"; do
		[[ "$_p" == "$cur_preset" ]] && { sel=$i; break; }
		(( i++ ))
	done

	local _pick_stty
	_pick_stty=$(stty -g 2>/dev/null)

	_dragon_pick_cleanup() {
		tput cnorm 2>/dev/null
		tput rmcup 2>/dev/null
		stty "$_pick_stty" 2>/dev/null
	}
	# Only use the trap for genuine unexpected exits (TERM, HUP).
	# INT is handled as \x03 in the key loop so we control the exit path.
	trap '_dragon_pick_cleanup' TERM HUP EXIT

	# Alternate screen + hide cursor.
	tput smcup 2>/dev/null
	tput civis 2>/dev/null

	local last_sel=-1
	local chosen=""
	local key seq jump
	# Header = 3 lines (title + hint + blank), preview = ~6 lines, scroll indicator = 1.
	# Reserve 10 lines for the preview + spacing; rest goes to the list viewport.
	local term_lines
	term_lines=$(tput lines 2>/dev/null || echo 24)
	local reserved=10
	local vsize=$(( term_lines - reserved ))
	(( vsize < 3 )) && vsize=3
	local voff=1   # first visible row (1-based)

	while true; do
		# Keep selection visible: scroll viewport to follow sel.
		if (( sel < voff )); then
			voff=$sel
		elif (( sel >= voff + vsize )); then
			voff=$(( sel - vsize + 1 ))
		fi

		if (( sel != last_sel )); then
			clear
			_dragon_pick_draw_frame
			_dragon_pick_draw_list "$sel" "$voff" "$vsize" "$n"
			_dragon_pick_draw_preview "$sel"
			last_sel=$sel
		fi

		# Read a full key sequence in one stty block.
		# -isig prevents Ctrl+C from sending SIGINT so \x03 arrives as a plain
		# byte — we handle it explicitly in the case below, which lets us run
		# cleanup and exit cleanly without the interactive shell intercepting INT.
		key="" seq=""
		{
			stty -echo -icanon -isig min 1 time 0 2>/dev/null
			IFS= read -k1 key
			if [[ "$key" == $'\e' ]]; then
				stty min 0 time 1 2>/dev/null
				IFS= read -k2 seq 2>/dev/null || seq=""
			fi
		} always {
			stty "$_pick_stty" 2>/dev/null
		}

		case "${key}${seq}" in
			$'\e[A'|$'\eOA') (( sel > 1 )) && (( sel-- )) ;;   # up
			$'\e[B'|$'\eOB') (( sel < n )) && (( sel++ )) ;;   # down
			$'\e')           chosen=""; break ;;                # bare Esc = cancel
			$'\e'*)          ;;                                  # other escape — ignore
			$'\n'|"")
				chosen="${_DRAGON_PRESET_NAMES[$sel]}"
				break
				;;
			$'\x03'|q|Q)     chosen=""; break ;;               # Ctrl+C or q = cancel
			k|K) (( sel > 1 )) && (( sel-- )) ;;   # vim up
			j|J) (( sel < n )) && (( sel++ )) ;;   # vim down
			[1-9])
				jump=$(( key ))
				(( jump >= 1 && jump <= n )) && sel=$jump
				;;
		esac
	done

	# Restore terminal before any output.
	trap - INT TERM EXIT
	_dragon_pick_cleanup
	unfunction _dragon_pick_cleanup 2>/dev/null

	[[ -z "$chosen" ]] && { print -P "  %F{245}Cancelled.%f"; return 0; }

	# Apply the chosen preset with the same flow as --preset.
	print ""
	print -P "%B%F{cyan}── dragon: Switch to '${chosen}' preset ─────────────────────────────%f%b"
	print ""
	print -P "  This will reset your theme config to the %B${chosen}%b preset."
	if ! _dragon_warn_preset_reset "Switch to ${chosen} preset now?"; then
		print ""
		print -P "  %F{245}Aborted. Your conf.zsh is unchanged.%f"
		return 0
	fi

	local _saved_nerd_font="${_DRAGON_CURRENT[USE_NERD_FONT]-}"
	_dragon_apply_preset "$chosen"
	[[ -n "$_saved_nerd_font" ]] && _DRAGON_CURRENT[USE_NERD_FONT]="$_saved_nerd_font"
	_dragon_write_conf
	_dragon_write_state "$chosen"

	local var val
	for var val in "${(@kv)_DRAGON_CURRENT}"; do
		export "DRAGON__${var}=${val}"
	done
	dragon__update_zsh_prompt 2>/dev/null

	print ""
	print -P "  %F{green}✓ Switched to %B${chosen}%b%F{green} preset — prompt updated immediately.%f"
	print -P "  %F{245}Fine-tune with: %Bdragon-configure%b%f"
	print ""
}
