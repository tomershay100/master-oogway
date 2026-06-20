# configure/wizard.zsh — interactive wizard steps and menus

_dragon_edit_var() {
	local var="$1"
	local type="${_DRAGON_TYPE[$var]:-string}"
	local current="${_DRAGON_CURRENT[$var]}"
	local default="${_DRAGON_DEFAULTS[$var]:-}"
	local hint="${_DRAGON_HINT[$var]:-}"
	local current_display="${current:-(empty string)}"

	print ""
	print -P "  %BEditing%b: DRAGON__${var}"
	[[ -n "$hint" ]] && print -P "  %F{245}${hint}%f"
	print -P "  %F{yellow}Current value%f: ${current_display}"
	print -P "  %F{245}Default%f: ${default:-(empty string)}"
	print ""

	case "$type" in
		bool)
			print -P "  [t] true   [f] false   [d] reset to default   [c] cancel"
			local key
			while true; do
				printf "  > "
				_dragon_read_key key
				case "$key" in
					t|T) _DRAGON_CURRENT[$var]="true";     return ;;
					f|F) _DRAGON_CURRENT[$var]="false";    return ;;
					d|D) _DRAGON_CURRENT[$var]="$default"; return ;;
					$'\x03'|c|C|$'\e'|$'\n') return ;;
				esac
			done
			;;
		enum:*)
			local options
			options=( ${(s:|:)${type#enum:}} )
			local i=1
			for opt in "${options[@]}"; do
				local marker=""
				[[ "$opt" == "$current" ]] && marker=" %B← current%b"
				print -P "  [${i}] ${opt}${marker}"
				(( i++ ))
			done
			print -P "  [d] reset to default (${default})   [c] cancel"
			printf "  > "
			local key
			_dragon_read_key key
			case "$key" in
				[1-9])
					local idx=$(( key ))
					(( idx >= 1 && idx <= ${#options} )) && _DRAGON_CURRENT[$var]="${options[$idx]}"
					;;
				d|D) _DRAGON_CURRENT[$var]="$default" ;;
			esac
			;;
		color)
			print -P "  %F{245}Color names: black red green yellow blue magenta cyan white%f"
			print -P "  %F{245}             grey maroon lime olive navy fuchsia aqua silver%f"
			print -P "  %F{245}Or 0–255 for extended 256 colors. Leave empty for no color.%f"
			print -P "  %F{245}To browse all 256 colors, run:%f"
			print "  for i in {0..255}; do print -Pn \"%K{\$i}  %k%F{\$i}\${(l:3::0:)i}%f \" \${\${(M)\$((i%6)):#3}:+\$'\\n'}; done"
			print ""
			if [[ -n "$current" ]]; then
				print -P "  %F{245}[e] erase → empty   [Enter] keep current   or type new value%f"
			else
				print -P "  %F{245}[Enter] keep empty   or type new value%f"
			fi
			local val
			while true; do
				printf "  New value (Enter = keep '%s'): " "${current:-(empty)}"
				read -r val
				if [[ "$val" == e || "$val" == E ]]; then
					_DRAGON_CURRENT[$var]=""; break
				elif [[ -z "$val" ]]; then
					break  # keep current
				elif [[ "$val" =~ '^[0-9]+$' && 10#$val -le 255 ]]; then
					_DRAGON_CURRENT[$var]="$val"; break
				elif [[ -n "${_MO_COLORS[${(L)val}]:-}" ]]; then
					_DRAGON_CURRENT[$var]="${(L)val}"; break
				else
					print -P "  %F{red}Invalid color '%F{white}${val}%F{red}' — enter a name or 0-255.%f"
				fi
			done
			;;
		integer)
			print -P "  %F{245}Enter a whole number. [Enter] keeps current. [d] resets to default.%f"
			local val
			while true; do
				printf "  New value (Enter = keep '%s'): " "${current:-(empty)}"
				IFS= read -r val
				if [[ -z "$val" ]]; then
					break  # keep current
				elif [[ "$val" == d || "$val" == D ]]; then
					_DRAGON_CURRENT[$var]="$default"; break
				elif [[ "$val" =~ '^[0-9]+$' ]]; then
					_DRAGON_CURRENT[$var]="$val"; break
				else
					print -P "  %F{red}Invalid value '%F{white}${val}%F{red}' — enter a non-negative integer.%f"
				fi
			done
			;;
		string)
			if [[ -n "$current" ]]; then
				print -P "  %F{245}[e] erase → empty   [Enter] keep current   or type new value%f"
			else
				print -P "  %F{245}[Enter] keep empty   or type new value%f"
			fi
			printf "  New value (Enter = keep '%s'): " "${current:-(empty)}"
			local val
			IFS= read -r val
			if [[ "$val" == e || "$val" == E ]]; then
				_DRAGON_CURRENT[$var]=""
			elif [[ -n "$val" ]]; then
				_DRAGON_CURRENT[$var]="$val"
			fi
			;;
	esac
}

# Returns 0=next, 1=back, 2=quit+save
_dragon_run_step() {
	local group="$1"
	local step_num="$2"
	local total="$3"
	local vars
	vars=( ${(z)_DRAGON_GROUP_VARS[$group]} )

	local title pad_len dashes var val default val_trimmed val_display marker type_hint vtype i key idx key2 _stty2

	while true; do
		clear

		# ── Header
		title="${_DRAGON_GROUP_TITLE[$group]}"
		pad_len=$(( 72 - 4 - ${#title} - 1 ))
		(( pad_len < 2 )) && pad_len=2
		dashes="${(r:$pad_len::─:):-}"
		print -P "%B%F{cyan}── Step ${step_num}/${total}: ${title} ${dashes}%f%b"
		print -P "   %F{245}${_DRAGON_GROUP_DESC[$group]}%f"
		print ""

		# ── Preview
		print -P "  %BPrompt preview%b (git: main ✔  exit: 0):"
		_dragon_render_preview --group="${group}"
		# Show a second contextual preview where relevant.
		case "$group" in
			username_ssh|hostname_ssh|ssh_prefix)
				_dragon_render_preview --ssh --group="${group}" ;;
			prompt_char_exit|exit_status)
				_dragon_render_preview --fail --group="${group}" ;;
			transient)
				_dragon_render_preview --transient --group="${group}" ;;
		esac
		print ""

		# ── Variable list
		print -P "  %BVariables:%b"
		i=1
		for var in "${vars[@]}"; do
			val="${_DRAGON_CURRENT[$var]}"
			default="${_DRAGON_DEFAULTS[$var]:-}"
			# Show quoted form for values with leading/trailing whitespace so they're visible.
			val_trimmed="${${val#"${val%%[! ]*}"}%"${val##*[! ]}"}"
			val_display="${val:-(empty)}"
			[[ -n "$val" && "$val" != "$val_trimmed" ]] && val_display="\"${val}\""
			marker=""
			[[ "$val" != "$default" ]] && marker=" %B%F{yellow}★%f%b"
			type_hint=""
			vtype="${_DRAGON_TYPE[$var]:-string}"
			[[ "$vtype" == enum:* ]] && type_hint=" %F{245}[${vtype#enum:}]%f"
			printf "  %3d. %-52s" "$i" "DRAGON__${var}"
			print -P "%F{yellow}${val_display}%f${marker}${type_hint}"
			(( i++ ))
		done
		print ""

		# ── Navigation
		print -P "  %F{245}[number] edit var   [b] back   [Enter/n] next   [q] save & quit   [d] reset group to defaults%f"
		printf "  > "
		key=""
		_dragon_read_key key

		case "$key" in
			''|$'\n'|n|N) return 0 ;;
			b|B)           return 1 ;;
			$'\x03'|q|Q)  return 2 ;;
			d|D)
				for var in "${vars[@]}"; do
					_DRAGON_CURRENT[$var]="${_DRAGON_DEFAULTS[$var]:-}"
				done
				;;
			[0-9])
				idx="$key"
				if (( ${#vars} > 9 )); then
					key2="" _stty2=""
					_stty2=$(stty -g 2>/dev/null)
					stty -echo -icanon min 0 time 5 2>/dev/null
					IFS= read -k1 key2 2>/dev/null || key2=""
					stty "$_stty2" 2>/dev/null
					[[ "$key2" == [0-9] ]] && idx="${key}${key2}"
				fi
				idx=$(( idx ))
				if (( idx >= 1 && idx <= ${#vars} )); then
					_dragon_edit_var "${vars[$idx]}"
				fi
				;;
		esac
	done
}

_dragon_guided_tour() {
	clear
	print -P "%B%F{cyan}── Welcome to dragon ────────────────────────────────────────────────%f%b"
	print ""
	print -P "  Here is what your prompt will look like and what each part means."
	print ""
	print -P "  %B%F{green}Left prompt%f%b"
	print ""
	print -P "    %F{green}user%f%F{245}@%f%F{cyan}hostname%f%F{245}:%f%F{yellow}~/projects%f %F{magenta}on main ✔%f"
	print -P "    %F{green}❯%f"
	print ""
	print -P "    %F{245}user@hostname%f   — who and where you are (hidden when not needed)"
	print -P "    %F{245}~/projects%f      — current directory (short, regular, or full path)"
	print -P "    %F{245}main ✔%f          — git branch + clean/dirty indicator"
	print -P "    %F{245}❯%f               — prompt character (green = last command succeeded,"
	print -P "                         red = it failed)"
	print ""
	print -P "  %B%F{blue}Right prompt%f%b"
	print ""
	print -P "    %F{245}1m 5s  2j  14:32:01%f"
	print ""
	print -P "    %F{245}1m 5s%f       — how long the last command took"
	print -P "    %F{245}2j%f          — number of background jobs"
	print -P "    %F{245}14:32:01%f    — current time"
	print -P "    %F{red}✘ 1%f         — exit code of the last command (hidden on success)"
	print ""
	print -P "  %B%F{245}Git status indicators%f%b"
	print ""
	print -P "    %F{green}≡%f  in sync with remote    %F{yellow}↑3%f  3 commits ahead"
	print -P "    %F{red}↓2%f  2 commits behind       %F{yellow}*%f   uncommitted changes"
	print ""
	print -P "  Everything is configurable — the next screen lets you choose a starting"
	print -P "  preset (minimal, balanced, or verbose), then steps through every feature."
	print ""
	print -P "  %B%F{245}Font check%f%b"
	print ""
	print -P "  dragon uses special characters for a richer look."
	print -P "  Powerline arrow:  "
	print -P "  Nerd Font icon:   "
	print ""
	printf "  Do both characters render as a solid arrow and a folder icon? [y/N] "
	local _nf_key
	read -r _nf_key
	if [[ "$_nf_key" == y || "$_nf_key" == Y ]]; then
		print -P "  %F{green}✓ Nerd Font glyphs enabled.%f"
	else
		_DRAGON_CURRENT[USE_NERD_FONT]="false"
		print -P "  %F{yellow}✓ ASCII fallbacks will be used — no special font needed.%f"
		print -P "  %F{245}  (install a Nerd Font later → re-run %Bdragon-configure%b to switch back)%f"
	fi
	print ""
	print -P "  %F{245}Press any key to continue...%f"
	_dragon_read_key _dragon_any
}

_dragon_select_preset() {
	clear
	print -P "%B%F{cyan}── dragon Theme Configurator ────────────────────────────────────────%f%b"
	print ""
	print -P "  Welcome! Choose a %Bstarting point%b for your prompt:"
	print ""

	# The "default" preset is the recommended starting point. By convention it
	# is named "default" — if absent, we fall back to the first registered name.
	local default_idx=1 i=1 name line
	for name in "${_DRAGON_PRESET_NAMES[@]}"; do
		[[ "$name" == "default" ]] && default_idx=$i
		print -P "  %B[${i}] ${name}%b — ${_DRAGON_PRESET_DESC[$name]}"
		while IFS= read -r line; do
			print -- "      ${line}"
		done <<< "${_DRAGON_PRESET_EXAMPLE[$name]}"
		print ""
		(( i++ ))
	done

	print -P "  %F{245}You will step through each feature group and can change anything.%f"
	print -P "  %F{245}Defaults are pre-applied; you only need to change what you want.%f"
	print ""
	local n=${#_DRAGON_PRESET_NAMES}
	printf "  Choice [1-%d, default=%d]: " "$n" "$default_idx"

	local key chosen_preset
	_dragon_read_key key
	if [[ "$key" =~ ^[0-9]$ ]] && (( key >= 1 && key <= n )); then
		chosen_preset="${_DRAGON_PRESET_NAMES[$key]}"
	else
		chosen_preset="${_DRAGON_PRESET_NAMES[$default_idx]}"
	fi
	print -P "\n  %F{green}✓ Starting from ${chosen_preset} preset%f"

	_DRAGON_CHOSEN_PRESET="$chosen_preset"
	_dragon_apply_preset "$chosen_preset"
	sleep 0.6
}

_dragon_filter_changed_groups() {
	local -a changed=()
	local group var
	for group in "${_DRAGON_GROUPS[@]}"; do
		local vars=( ${(z)_DRAGON_GROUP_VARS[$group]} )
		for var in "${vars[@]}"; do
			if [[ "${_DRAGON_CURRENT[$var]}" != "${_DRAGON_DEFAULTS[$var]:-}" ]]; then
				changed+=("$group")
				break
			fi
		done
	done
	_DRAGON_GROUPS=("${changed[@]}")
}

# Shared confirm-and-auto-backup for destructive preset resets. Caller prints
# its own header so the question can be specific. Returns 0 if the user
# accepts (and the backup, if any, succeeded); 1 if they decline.
_dragon_warn_preset_reset() {
	local prompt="${1:-Continue?}"
	if [[ -f "${_DRAGON_CONF_FILE}" ]]; then
		print -P "  Your current settings will be replaced."
		print -P "  %F{245}A timestamped backup will be saved to ${_DRAGON_CONF_FILE}.bak.<ts>%f"
		print ""
	fi
	printf "  %s [y/N] " "$prompt"
	local _confirm
	read -r _confirm
	[[ "$_confirm" == y* || "$_confirm" == Y* ]] || return 1
	if [[ -f "${_DRAGON_CONF_FILE}" ]]; then
		local _bak="${_DRAGON_CONF_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
		cp "${_DRAGON_CONF_FILE}" "$_bak"
		print -P "  %F{green}✓%f Backup saved: %B${_bak}%b"
	fi
	return 0
}

_dragon_show_start_menu() {
	clear
	print -P "%B%F{cyan}── dragon Theme Configurator ────────────────────────────────────────%f%b"
	print ""
	print -P "  Config found at %B${_DRAGON_CONF_FILE}%b"
	print ""
	print -P "  %B[1]%b Edit current config  — step through your non-default settings only"
	print -P "  %B[2]%b Full wizard          — step through all variable groups"
	print -P "  %B[3]%b Reset to preset      — discard current config, start fresh"
	print -P "  %B[4]%b Open in \$EDITOR      — edit the file directly (${EDITOR:-nano})"
	print ""
	printf "  Choice [1/2/3/4, default=1]: "

	local key
	_dragon_read_key key
	print ""

	case "$key" in
		$'\x03')
			_dragon_cleanup
			return 1
			;;
		2)
			# Full wizard: keep current settings, step through ALL groups
			print -P "  %F{green}✓ Full wizard%f"
			sleep 0.4
			_DRAGON_CHOSEN_PRESET="${_DRAGON_STATE[preset]:-default}"
			;;
		3)
			clear
			print -P "%B%F{cyan}── dragon: Reset current config to preset ───────────────────────────%f%b"
			print ""
			print -P "  This will discard your current settings and step you through"
			print -P "  choosing a preset (short / default / verbose)."
			if ! _dragon_warn_preset_reset "Continue with reset?"; then
				print ""
				print -P "  %F{245}Cancelled — your current config is unchanged.%f"
				sleep 0.6
				_dragon_cleanup
				return 1
			fi
			print -P "  %F{green}✓ Reset to preset%f"
			sleep 0.4
			_dragon_select_preset
			;;
		4)
			print -P "  %F{green}✓ Opening in ${EDITOR:-nano}...%f"
			sleep 0.4
			${EDITOR:-nano} "${_DRAGON_CONF_FILE}"
			_dragon_cleanup
			return 1  # signal caller to exit without running wizard
			;;
		*)
			# 1 or Enter — edit current (changed groups only)
			print -P "  %F{green}✓ Editing current config%f"
			sleep 0.4
			_dragon_filter_changed_groups
			if (( ${#_DRAGON_GROUPS} == 0 )); then
				clear
				print -P "  %F{245}All settings are at their defaults — nothing to edit.%f"
				print -P "  Run with %B[2]%b Full wizard to review everything."
				print ""
				printf "  Press any key to exit... "
				_dragon_read_key _dragon_any
				_dragon_cleanup
				return 1
			fi
			_DRAGON_CHOSEN_PRESET="${_DRAGON_STATE[preset]:-default}"
			;;
	esac
	return 0
}
