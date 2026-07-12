# -----------------------------------------------------------------------------
# configure.zsh
# Provides `dragon-configure` — interactive theme wizard.
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
source "${0:a:h}/configure/writer.zsh"

# -----------------------------------------------------------------------------
# Main entry point
# -----------------------------------------------------------------------------

dragon-configure() {
	if [[ "${1-}" == "--help" || "${1-}" == "-h" ]]; then
		cat <<'EOF'
Usage: dragon-configure [options]

Options:
  (none), --pick      TUI preset browser — arrow keys, live preview, Enter to apply
  --preset <name>     Instantly switch to a preset (built-in or personal)
  --edit              Open conf.zsh in $EDITOR to fine-tune individual settings
  --export <name>     Save current config as a personal preset
  --gallery           Print every built-in preset stacked, with a labeled banner
  --help, -h          Show this help

Config file:    ~/.config/master-oogway/conf.zsh
Personal presets: ~/.config/master-oogway/presets/<name>.conf.zsh
EOF
		return 0
	fi

	if [[ "${ZSH_THEME:-}" != "dragon" ]]; then
		print -P "%F{yellow}[dragon] Warning: ZSH_THEME is '${ZSH_THEME:-<unset>}', not 'dragon' — conf.zsh changes will have no effect until you switch themes.%f"
	fi

	# ── Edit the config file directly: dragon-configure --edit
	if [[ "${1-}" == "--edit" ]]; then
		if [[ ! -f "${_DRAGON_CONF_FILE}" ]]; then
			print -P "%F{red}✗%f No conf.zsh found — run %Bdragon-configure%b first to pick a preset."
			return 1
		fi
		${EDITOR:-nano} "${_DRAGON_CONF_FILE}"
		print -P "  %F{245}Reload to apply: %Brezsh%b%f"
		return 0
	fi

	# Init all data
	_dragon_init_defaults
	_dragon_init_types
	_dragon_init_hints
	_dragon_init_groups
	_dragon_init_presets || return 1
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

		_dragon_apply_and_save "$_preset" || return 1
		print ""
		print -P "  %F{green}✓ Switched to ${_preset} preset.%f"
		print -P "  %F{245}Reload to apply: %Brezsh%b"
		print -P "  %F{245}Fine-tune with:  %Bdragon-configure%b%f"
		_dragon_cleanup
		return 0
	fi

	# ── Bare / --pick: front door is the TUI preset picker.
	_dragon_pick_preset
	_dragon_cleanup
}

_dragon_cleanup() {
	unset _DRAGON_DEFAULTS _DRAGON_CURRENT _DRAGON_TYPE _DRAGON_HINT _DRAGON_STATE _DRAGON_CHOSEN_PRESET
	unset _DRAGON_GROUP_TITLE _DRAGON_GROUP_DESC _DRAGON_GROUP_VARS _DRAGON_GROUPS
	unset _DRAGON_PRESET_NAMES _DRAGON_PRESET_DESC _DRAGON_PRESET_EXAMPLE
	unset _DRAGON_PICK_NAMES _DRAGON_PICK_TYPE _DRAGON_PICK_DESC
}
