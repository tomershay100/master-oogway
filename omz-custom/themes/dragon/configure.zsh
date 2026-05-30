# -----------------------------------------------------------------------------
# configure.zsh
# Provides `dragon-configure [--new-only]` — interactive theme wizard.
# Sourced by dragon.zsh (not OMZ directly); no side effects at top level.
# -----------------------------------------------------------------------------

# -- File-level constants ------------------------------------------------------

typeset -g _DRAGON_CONF_FILE="${HOME}/.config/master-oogway/conf.zsh"
typeset -g _DRAGON_THEMES_DIR="${0:a:h}"   # .../dragon/ — derived from script location
typeset -g _DRAGON_STATE_DIR="${HOME}/.config/master-oogway"
typeset -g _DRAGON_STATE_FILE="${_DRAGON_STATE_DIR}/state"

# -- Schema (defaults, types, hints, groups) ----------------------------------

source "${0:a:h}/schema.zsh"

# -- Parts (split from this file for maintainability) -------------------------

source "${0:a:h}/configure/state.zsh"
source "${0:a:h}/configure/preview.zsh"
source "${0:a:h}/configure/pick.zsh"
source "${0:a:h}/configure/wizard.zsh"
source "${0:a:h}/configure/writer.zsh"

# -----------------------------------------------------------------------------
# Main entry point
# -----------------------------------------------------------------------------

dragon-configure() {
	if [[ "${1-}" == "--help" || "${1-}" == "-h" ]]; then
		cat <<'EOF'
Usage: dragon-configure [options]

Options:
  (none)              Full interactive wizard — step through every setting
  --pick              TUI preset browser — arrow keys, live preview, Enter to apply
  --new-only          Only configure variables added since the last run
  --preset <name>     Instantly switch to a preset (built-in or personal)
  --export <name>     Save current config as a personal preset
  --gallery           Print every preset stacked, with a labeled banner
  --diff <preset>     Show what would change if you switched to <preset>
  --dismiss           Silence the "new variables" notifier until next update
  --version, -v       Print the installed dragon version
  --help, -h          Show this help

Config file:    ~/.config/master-oogway/conf.zsh
Personal presets: ~/.config/master-oogway/presets/<name>.conf.zsh
EOF
		return 0
	fi

	if [[ "${1-}" == "--version" || "${1-}" == "-v" ]]; then
		local version
		version=$(git -C "${HOME}/.master-oogway" log -1 --format="%cd-%h" --date=format:"%Y-%m-%d_%H%M%S" 2>/dev/null \
			|| echo "unknown")
		echo "dragon ${version}"
		return 0
	fi

	if [[ "${1-}" == "--dismiss" ]]; then
		local current_hash current_mtime
		current_hash=$(_dragon_vars_hash)
		current_mtime=$(stat -c '%Y' "${_DRAGON_THEMES_DIR}/schema.zsh" 2>/dev/null)
		mkdir -p "${_DRAGON_STATE_DIR}"
		local tmp_state="${_DRAGON_STATE_FILE}.tmp"
		grep -v -e '^dismissed_hash=' -e '^themes_mtime=' "${_DRAGON_STATE_FILE}" \
			2>/dev/null > "${tmp_state}" || true
		printf 'dismissed_hash=%s\nthemes_mtime=%s\n' "${current_hash}" "${current_mtime}" \
			>> "${tmp_state}"
		command mv "${tmp_state}" "${_DRAGON_STATE_FILE}"
		print -P "%F{green}✓%f Dragon notifier dismissed until next update."
		return 0
	fi

	# ── TUI preset picker: dragon-configure --pick
	if [[ "${1-}" == "--pick" ]]; then
		if [[ "${ZSH_THEME:-}" != "dragon" ]]; then
			print -P "%F{yellow}[dragon] Warning: ZSH_THEME is '${ZSH_THEME:-<unset>}', not 'dragon'.%f"
		fi
		_dragon_init_defaults
		_dragon_init_types
		_dragon_init_hints
		_dragon_init_groups
		_dragon_init_presets
		typeset -g _DRAGON_CHOSEN_PRESET="default"
		typeset -gA _DRAGON_STATE=()
		_dragon_load_current_conf
		_dragon_pick_preset
		_dragon_cleanup
		return 0
	fi

	if [[ "${ZSH_THEME:-}" != "dragon" ]]; then
		print -P "%F{yellow}[dragon] Warning: ZSH_THEME is '${ZSH_THEME:-<unset>}', not 'dragon' — conf.zsh changes will have no effect until you switch themes.%f"
	fi

	local new_only=false
	[[ "${1-}" == "--new-only" ]] && new_only=true

	# Init all data
	_dragon_init_defaults
	_dragon_init_types
	_dragon_init_hints
	_dragon_init_groups
	_dragon_init_presets
	typeset -g _DRAGON_CHOSEN_PRESET="default"
	typeset -gA _DRAGON_STATE=()

	# Load existing conf (sets _DRAGON_CURRENT from defaults + active conf values)
	_dragon_load_current_conf

	# ── Export current config as a personal preset
	if [[ "${1-}" == "--export" ]]; then
		local _export_name="${2:-}"
		if [[ -z "$_export_name" ]]; then
			print -P "%F{red}✗%f Usage: dragon-configure --export <name>"
			_dragon_cleanup
			return 1
		fi
		if [[ ! "$_export_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
			print -P "%F{red}✗%f Invalid name '${_export_name}' — use letters, numbers, hyphens, underscores only."
			_dragon_cleanup
			return 1
		fi
		if [[ -z "${_DRAGON_CONF_FILE}" || ! -f "${_DRAGON_CONF_FILE}" ]]; then
			print -P "%F{red}✗%f No conf.zsh found — run %Bdragon-configure%b first."
			_dragon_cleanup
			return 1
		fi
		local _presets_dir="${_DRAGON_STATE_DIR}/presets"
		local _export_dst="${_presets_dir}/${_export_name}.conf.zsh"
		mkdir -p "$_presets_dir"
		if [[ -f "$_export_dst" ]]; then
			printf "  '%s' already exists — overwrite? [y/N] " "$_export_name"
			local _ow; read -r _ow
			[[ "$_ow" == y* || "$_ow" == Y* ]] || { print -P "  %F{245}Aborted.%f"; _dragon_cleanup; return 0; }
		fi
		# Write only the non-default values as a compact, sourceable conf fragment.
		{
			printf '# dragon personal preset: %s\n' "$_export_name"
			printf '# Created: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
			printf '# Load with: dragon-configure --preset %s\n\n' "$_export_name"
			local var val default q=\'
			for var val in "${(@kv)_DRAGON_CURRENT}"; do
				default="${_DRAGON_DEFAULTS[$var]:-}"
				[[ "$val" == "$default" ]] && continue
				local safe_val="${val//$q/$q\\$q$q}"
				printf "export DRAGON__%s='%s'\n" "$var" "$safe_val"
			done
		} > "$_export_dst"
		print ""
		print -P "  %F{green}✓ Saved preset '%B${_export_name}%b%F{green}' to:%f"
		print -P "    %B${_export_dst}%b"
		print ""
		print -P "  %F{245}Reload it any time with: %Bdragon-configure --preset ${_export_name}%f"
		print ""
		print -P "  %F{245}Love it? Consider submitting it as a PR to the master-oogway repo.%f"
		print ""
		_dragon_cleanup
		return 0
	fi

	# ── Gallery: dragon-configure --gallery
	if [[ "${1-}" == "--gallery" ]]; then
		print -P "%B%F{cyan}── dragon: Preset gallery ───────────────────────────────────────────%f%b"
		_dragon_render_gallery
		print ""
		print -P "  %F{245}Apply one with: %Bdragon-configure --preset <name>%b%f"
		_dragon_cleanup
		return 0
	fi

	# ── Diff against a preset: dragon-configure --diff <name>
	if [[ "${1-}" == "--diff" ]]; then
		local _diff_preset="${2:-}"
		if [[ -z "$_diff_preset" ]]; then
			print -P "%F{red}✗%f Usage: dragon-configure --diff <preset>"
			_dragon_cleanup
			return 1
		fi
		if [[ ! "$_diff_preset" =~ ^[a-zA-Z0-9_-]+$ ]]; then
			print -P "%F{red}✗%f Invalid preset name '${_diff_preset}' — use letters, numbers, hyphens, underscores only."
			_dragon_cleanup
			return 1
		fi
		local _diff_user_file="${_DRAGON_STATE_DIR}/presets/${_diff_preset}.conf.zsh"
		local _diff_is_builtin=false _diff_is_user=false
		[[ -n "${_DRAGON_PRESET_DESC[$_diff_preset]:-}" ]] && _diff_is_builtin=true
		[[ -f "$_diff_user_file" ]]                        && _diff_is_user=true
		if ! ( $_diff_is_builtin || $_diff_is_user ); then
			print -P "%F{red}✗%f Unknown preset '${_diff_preset}'"
			print -P "  Built-in presets: %B${(j:%b  %B:)_DRAGON_PRESET_NAMES[@]}%b"
			local _user_presets=( "${_DRAGON_STATE_DIR}"/presets/*.conf.zsh(N) )
			if (( ${#_user_presets} > 0 )); then
				local _unames=( "${_user_presets[@]##*/}" )
				_unames=( "${_unames[@]%.conf.zsh}" )
				print -P "  Personal presets: %B${(j:%b  %B:)_unames[@]}%b"
			fi
			_dragon_cleanup
			return 1
		fi

		# Snapshot the current conf before we clobber _DRAGON_CURRENT.
		local -A _diff_current=( "${(@kv)_DRAGON_CURRENT}" )

		# Load preset into _DRAGON_CURRENT.
		if $_diff_is_builtin; then
			_dragon_apply_preset "$_diff_preset"
		else
			local var
			for var in "${(@k)_DRAGON_DEFAULTS}"; do
				_DRAGON_CURRENT[$var]="${_DRAGON_DEFAULTS[$var]}"
			done
			_dragon_load_current_conf_from "$_diff_user_file"
		fi

		print -P "%B%F{cyan}── dragon: diff current → ${_diff_preset} ─────────────────────────────%f%b"
		print ""

		local _changed=0
		for var in "${(@ko)_DRAGON_DEFAULTS}"; do
			local cur="${_diff_current[$var]:-}"
			local preset_val="${_DRAGON_CURRENT[$var]:-}"
			[[ "$cur" == "$preset_val" ]] && continue
			(( _changed++ ))
			print -P "  %B${var}%b"
			print -P "    %F{red}− ${cur:-(empty)}%f"
			print -P "    %F{green}+ ${preset_val:-(empty)}%f"
		done

		if (( _changed == 0 )); then
			print -P "  %F{green}✓ Your config already matches the '${_diff_preset}' preset — no differences.%f"
		else
			print ""
			print -P "  %F{245}${_changed} variable(s) differ. Apply with: %Bdragon-configure --preset ${_diff_preset}%b%f"
		fi
		print ""
		_dragon_cleanup
		return 0
	fi

	# ── Preset switcher: dragon-configure --preset <name>
	if [[ "${1-}" == "--preset" ]]; then
		local _preset="${2:-}"
		if [[ -n "$_preset" && ! "$_preset" =~ ^[a-zA-Z0-9_-]+$ ]]; then
			print -P "%F{red}✗%f Invalid preset name '${_preset}' — use letters, numbers, hyphens, underscores only."
			_dragon_cleanup
			return 1
		fi
		local _user_preset_file="${_DRAGON_STATE_DIR}/presets/${_preset}.conf.zsh"
		local _is_builtin=false _is_user=false
		[[ -n "${_DRAGON_PRESET_DESC[$_preset]:-}" ]] && _is_builtin=true
		[[ -f "$_user_preset_file" ]]                 && _is_user=true

		if [[ -z "$_preset" ]] || ! ( $_is_builtin || $_is_user ); then
			print -P "%F{red}✗%f Invalid preset: '${_preset:-<none>}'"
			print -P "  Built-in presets: %B${(j:%b  %B:)_DRAGON_PRESET_NAMES[@]}%b"
			local _user_presets=( "${_DRAGON_STATE_DIR}"/presets/*.conf.zsh(N) )
			if (( ${#_user_presets} > 0 )); then
				local _unames=( "${_user_presets[@]##*/}" )
				_unames=( "${_unames[@]%.conf.zsh}" )
				print -P "  Personal presets: %B${(j:%b  %B:)_unames[@]}%b"
			fi
			print -P "  Usage: dragon-configure --preset <name>"
			_dragon_cleanup
			return 1
		fi

		clear
		print -P "%B%F{cyan}── dragon: Switch to '${_preset}' preset ────────────────────────────%f%b"
		print ""
		if $_is_user && ! $_is_builtin; then
			print -P "  Personal preset from: %B${_user_preset_file}%b"
		fi
		print -P "  This will reset your theme config to the %B${_preset}%b preset."
		if ! _dragon_warn_preset_reset "Switch to ${_preset} preset now?"; then
			print ""
			print -P "  %F{245}Aborted. Your conf.zsh is unchanged.%f"
			_dragon_cleanup
			return 0
		fi

		# Preserve USE_NERD_FONT — it reflects terminal capability, not style preference.
		local _saved_nerd_font="${_DRAGON_CURRENT[USE_NERD_FONT]-}"
		if $_is_builtin; then
			_dragon_apply_preset "$_preset"
		else
			# User preset: reset to defaults then source the preset file into _DRAGON_CURRENT.
			local var
			for var in "${(@k)_DRAGON_DEFAULTS}"; do
				_DRAGON_CURRENT[$var]="${_DRAGON_DEFAULTS[$var]}"
			done
			_dragon_load_current_conf_from "$_user_preset_file"
		fi
		[[ -n "$_saved_nerd_font" ]] && _DRAGON_CURRENT[USE_NERD_FONT]="$_saved_nerd_font"
		_dragon_write_conf
		_dragon_write_state "$_preset"
		print ""
		print -P "  %F{green}✓ Switched to ${_preset} preset.%f"
		print -P "  %F{245}Reload to apply: %Brezsh%b"
		print -P "  %F{245}Fine-tune with:  %Bdragon-configure%b%f"
		_dragon_cleanup
		return 0
	fi

	# ── New-only mode: check for new vars
	if $new_only; then
		_dragon_read_state
		local stored_hash="${_DRAGON_STATE[vars_hash]:-}"
		local current_hash
		current_hash=$(_dragon_vars_hash)
		if [[ "$stored_hash" == "$current_hash" ]]; then
			print -P "%F{green}✓ No new dragon theme variables detected.%f"
			print -P "  Run %Bdragon-configure%b (without --new-only) to reconfigure everything."
			_dragon_cleanup
			return 0
		fi
		clear
		print -P "%B%F{cyan}── dragon: New Theme Features ───────────────────────────────────────%f%b"
		print ""
		print -P "  New theme variables have been added since you last configured."
		print -P "  Default values have been applied for them."
		print -P "  Stepping through all groups — your existing settings are preserved."
		print ""
		print -P "  %F{245}Press any key to start...%f"
		_dragon_read_key _dragon_any
		_DRAGON_CHOSEN_PRESET="${_DRAGON_STATE[preset]:-default}"
	elif [[ -f "${_DRAGON_CONF_FILE}" ]]; then
		_dragon_read_state
		_dragon_show_start_menu || return 0
	else
		# First run — guided tour then preset selection
		_dragon_guided_tour
		_dragon_select_preset
	fi

	# ── Step through all groups
	local step=0
	local total=${#_DRAGON_GROUPS}
	while (( step < total )); do
		_dragon_run_step "${_DRAGON_GROUPS[$((step + 1))]}" $((step + 1)) $total
		local rc=$?
		case $rc in
			0) (( step++ )) ;;
			1) (( step > 0 )) && (( step-- )) ;;
			2) break ;;
		esac
	done

	# ── Final preview
	clear
	print -P "%B%F{cyan}── Final Result ─────────────────────────────────────────────────────────%f%b"
	print ""
	print -P "  Your configured prompt:"
	_dragon_render_preview
	print ""
	printf "  Save configuration? [Y/n]: "
	local confirm
	read -r confirm
	if [[ "$confirm" == n* || "$confirm" == N* ]]; then
		print -P "  %F{yellow}Discarded. No changes were saved.%f"
		_dragon_cleanup
		return 0
	fi

	# ── Write conf and state
	_dragon_write_conf
	_dragon_write_state "${_DRAGON_CHOSEN_PRESET}"

	# Apply directly to the current shell — export every chosen value so the
	# already-set DRAGON__ vars are overwritten (set_if_unset won't help here).
	local var val
	for var val in "${(@kv)_DRAGON_CURRENT}"; do
		export "DRAGON__${var}=${val}"
	done
	dragon__update_zsh_prompt 2>/dev/null

	print ""
	print -P "  %F{green}✓ Saved to %B${_DRAGON_CONF_FILE}%b%F{green} — prompt updated immediately.%f"
	print -P "  %F{245}Edit that file directly to change individual settings without re-running the wizard.%f"
	print ""

	_dragon_cleanup
}

_dragon_cleanup() {
	unset _DRAGON_DEFAULTS _DRAGON_CURRENT _DRAGON_TYPE _DRAGON_HINT _DRAGON_STATE _DRAGON_CHOSEN_PRESET
	unset _DRAGON_GROUP_TITLE _DRAGON_GROUP_DESC _DRAGON_GROUP_VARS _DRAGON_GROUPS
	unset _DRAGON_PRESET_NAMES _DRAGON_PRESET_DESC _DRAGON_PRESET_EXAMPLE
}
