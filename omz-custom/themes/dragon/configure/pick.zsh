# configure/pick.zsh — TUI preset browser (dragon-configure / --pick)

# One-question Nerd-Font check. Asked before the picker opens every time so the
# answer is written to conf.zsh (USE_NERD_FONT) and preserved by every apply
# path. Sets _DRAGON_CURRENT[USE_NERD_FONT].
_dragon_ask_nerd_font() {
	clear
	print -P "%B%F{cyan}── dragon: Font check ───────────────────────────────────────────────%f%b"
	print ""
	print -P "  dragon uses special characters for a richer look."
	print -P "  Powerline arrow:  "
	print -P "  Nerd Font icon:   "
	print ""
	printf "  Do both characters render as a solid arrow and a folder icon? [y/N] "
	local _nf_key
	read -r _nf_key
	if [[ "$_nf_key" == y* || "$_nf_key" == Y* ]]; then
		_DRAGON_CURRENT[USE_NERD_FONT]="true"
	else
		_DRAGON_CURRENT[USE_NERD_FONT]="false"
	fi
}

# Build the combined preset list (built-ins, then personal with a divider).
# Populates three global parallel arrays consumed by the picker:
#   _DRAGON_PICK_NAMES[i]  — preset name ('' for a divider row)
#   _DRAGON_PICK_TYPE[i]   — builtin | user | divider
#   _DRAGON_PICK_DESC[i]   — description ('' for user/divider)
_dragon_pick_build_list() {
	typeset -ga _DRAGON_PICK_NAMES=() _DRAGON_PICK_TYPE=() _DRAGON_PICK_DESC=()
	local name
	for name in "${_DRAGON_PRESET_NAMES[@]}"; do
		_DRAGON_PICK_NAMES+=("$name")
		_DRAGON_PICK_TYPE+=("builtin")
		_DRAGON_PICK_DESC+=("${_DRAGON_PRESET_DESC[$name]:-}")
	done
	local -a _user=( "${_DRAGON_STATE_DIR}"/presets/*.conf.zsh(N) )
	if (( ${#_user} > 0 )); then
		_DRAGON_PICK_NAMES+=(""); _DRAGON_PICK_TYPE+=("divider"); _DRAGON_PICK_DESC+=("")
		local f
		for f in "${_user[@]}"; do
			name="${f##*/}"; name="${name%.conf.zsh}"
			_DRAGON_PICK_NAMES+=("$name")
			_DRAGON_PICK_TYPE+=("user")
			_DRAGON_PICK_DESC+=("")
		done
	fi
}

# Draw the header bar. $1 = current preview context label.
_dragon_pick_draw_frame() {
	print -P "%B%F{cyan}── dragon: Pick a preset ────────────────────────────────────────────%f%b"
	print -P "  %F{245}↑↓ navigate   Enter apply   s preview: ${1}   Esc/q cancel%f"
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
		if [[ "${_DRAGON_PICK_TYPE[$i]}" == "divider" ]]; then
			printf "  \033[90m ── Personal ─────────────────────────────────────────────\033[m\n"
			continue
		fi
		name="${_DRAGON_PICK_NAMES[$i]}"
		desc="${_DRAGON_PICK_DESC[$i]}"
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

# Render the preview section for the entry at index $1, in context $2
# (plain | ssh | fail). Applies the preset to a local copy so the caller's
# _DRAGON_CURRENT is never mutated. Personal presets are sourced from file.
_dragon_pick_draw_preview() {
	local sel="$1" ctx="$2"
	local name="${_DRAGON_PICK_NAMES[$sel]}"
	print ""
	print -P "  %B%F{cyan}${name}%f%b  %F{245}${_DRAGON_PICK_DESC[$sel]}%f"
	local -A _pick_saved=( "${(@kv)_DRAGON_CURRENT}" )
	if [[ "${_DRAGON_PICK_TYPE[$sel]}" == "user" ]]; then
		local var
		for var in "${(@k)_DRAGON_DEFAULTS}"; do
			_DRAGON_CURRENT[$var]="${_DRAGON_DEFAULTS[$var]}"
		done
		_dragon_load_current_conf_from "${_DRAGON_STATE_DIR}/presets/${name}.conf.zsh"
	else
		_dragon_apply_preset "$name"
	fi
	case "$ctx" in
		ssh)  _dragon_render_preview --ssh ;;
		fail) _dragon_render_preview --fail ;;
		*)    _dragon_render_preview ;;
	esac
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

	# Ask the Nerd-Font question before entering the TUI (writes USE_NERD_FONT
	# into _DRAGON_CURRENT so the apply preserves it).
	_dragon_ask_nerd_font

	_dragon_pick_build_list
	local n=${#_DRAGON_PICK_NAMES}
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

	# Preview context toggled with 's': plain → ssh → fail → plain.
	local ctx="plain"

	# Determine starting selection: match the active preset (from conf.zsh's
	# `# preset:` header), else the first selectable (non-divider) row.
	local sel=1
	local cur_preset
	cur_preset=$(_dragon_active_preset)
	local i
	for (( i = 1; i <= n; i++ )); do
		[[ "${_DRAGON_PICK_TYPE[$i]}" == "divider" ]] && continue
		[[ "${_DRAGON_PICK_NAMES[$i]}" == "$cur_preset" ]] && { sel=$i; break; }
	done
	# If the state preset wasn't found, land on the first selectable row.
	[[ "${_DRAGON_PICK_TYPE[$sel]}" == "divider" ]] && (( sel++ ))

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

	local last_sel=-1 last_ctx=""
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

		if (( sel != last_sel )) || [[ "$ctx" != "$last_ctx" ]]; then
			clear
			_dragon_pick_draw_frame "$ctx"
			_dragon_pick_draw_list "$sel" "$voff" "$vsize" "$n"
			_dragon_pick_draw_preview "$sel" "$ctx"
			last_sel=$sel
			last_ctx="$ctx"
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
			$'\e[A'|$'\eOA'|k|K)                                # up (skip dividers)
				(( sel > 1 )) && (( sel-- ))
				[[ "${_DRAGON_PICK_TYPE[$sel]}" == "divider" ]] && (( sel > 1 )) && (( sel-- ))
				;;
			$'\e[B'|$'\eOB'|j|J)                                # down (skip dividers)
				(( sel < n )) && (( sel++ ))
				[[ "${_DRAGON_PICK_TYPE[$sel]}" == "divider" ]] && (( sel < n )) && (( sel++ ))
				;;
			s|S)                                                # cycle preview context
				case "$ctx" in
					plain) ctx="ssh" ;;
					ssh)   ctx="fail" ;;
					*)     ctx="plain" ;;
				esac
				;;
			$'\e')           chosen=""; break ;;                # bare Esc = cancel
			$'\e'*)          ;;                                  # other escape — ignore
			$'\n'|"")
				chosen="${_DRAGON_PICK_NAMES[$sel]}"
				break
				;;
			$'\x03'|q|Q)     chosen=""; break ;;               # Ctrl+C or q = cancel
			[1-9])
				jump=$(( key ))
				(( jump >= 1 && jump <= n )) \
					&& [[ "${_DRAGON_PICK_TYPE[$jump]}" != "divider" ]] \
					&& sel=$jump
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

	_dragon_apply_and_save "$chosen" || return 1

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
