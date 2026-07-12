# configure/state.zsh — conf loading and preset apply

# Read the `# preset: <name>` header from conf.zsh (the sole source of truth for
# the active preset since the state file was removed). Empty if absent.
_dragon_active_preset() {
	[[ -f "${_DRAGON_CONF_FILE}" ]] || return
	grep -m1 '^# preset: ' "${_DRAGON_CONF_FILE}" 2>/dev/null | cut -d' ' -f3
}

_dragon_load_current_conf_from() {
	local src="$1"
	[[ -f "$src" ]] || return
	local line varname raw q=\'
	while IFS= read -r line; do
		[[ "$line" == '#'* || "$line" =~ ^[[:space:]]*$ ]] && continue
		# Plain single-quoted: export DRAGON__VAR='value'
		if [[ "$line" =~ "^[[:space:]]*export DRAGON__([A-Z_]+)='(.*)'[[:space:]]*(#.*)?$" ]]; then
			varname="${match[1]}"
			raw="${match[2]}"
			raw="${raw//$q\\$q$q/$q}"
			_DRAGON_CURRENT[$varname]="$raw"
		# Dollar-quote form: export DRAGON__VAR=$'...' — used in preset files for
		# Nerd Font PUA glyphs. eval the assignment in a subshell, then capture via
		# printf so no arbitrary code can escape into the current shell.
		elif [[ "$line" =~ "^[[:space:]]*export DRAGON__([A-Z_]+)=(\\\$'[^']*')[[:space:]]*(#.*)?$" ]]; then
			varname="${match[1]}"
			raw="$(eval "printf '%s' ${match[2]}")"
			_DRAGON_CURRENT[$varname]="$raw"
		fi
	done < "$src"
}

_dragon_load_current_conf() {
	# Start from defaults
	typeset -gA _DRAGON_CURRENT=()
	local var
	for var in "${(@k)_DRAGON_DEFAULTS}"; do
		_DRAGON_CURRENT[$var]="${_DRAGON_DEFAULTS[$var]}"
	done

	[[ -f "${_DRAGON_CONF_FILE}" ]] || return

	# Override with any active (uncommented) settings from the conf file
	local line varname raw q=\'
	while IFS= read -r line; do
		[[ "$line" == '#'* || "$line" =~ ^[[:space:]]*$ ]] && continue

		# Current format (single-quoted, since 2026-05-16): immune to shell
		# expansion of $, `, and \ in user-provided values. The greedy (.*)
		# captures up to the LAST ' before optional trailing whitespace +
		# comment, so values containing the escape sequence '\'' round-trip
		# cleanly.
		if [[ "$line" =~ "^[[:space:]]*export DRAGON__([A-Z_]+)='(.*)'[[:space:]]*(#.*)?$" ]]; then
			varname="${match[1]}"
			raw="${match[2]}"
			raw="${raw//$q\\$q$q/$q}"       # unescape '\'' → '
			_DRAGON_CURRENT[$varname]="$raw"
		# Legacy format (double-quoted, pre-2026-05-16): read-only — we no
		# longer emit it, but existing users' conf.zsh files still parse.
		# Greedy (.*)" matches up to LAST " before optional comment, so this
		# also fixes the old reader's '" #'-substring truncation bug.
		elif [[ "$line" =~ "^[[:space:]]*export DRAGON__([A-Z_]+)=\"(.*)\"[[:space:]]*(#.*)?$" ]]; then
			varname="${match[1]}"
			raw="${match[2]}"
			raw="${raw//\\\"/\"}"           # unescape \" → "
			raw="${raw//\\\\/\\}"           # unescape \\ → \
			_DRAGON_CURRENT[$varname]="$raw"
		fi
	done < "${_DRAGON_CONF_FILE}"

	# Validate integer-typed vars; reset to default + warn on bad value.
	local val
	for varname in "${(@k)_DRAGON_TYPE}"; do
		[[ "${_DRAGON_TYPE[$varname]}" == "integer" ]] || continue
		val="${_DRAGON_CURRENT[$varname]}"
		if [[ -n "$val" && ! "$val" =~ ^[0-9]+$ ]]; then
			print -P "%F{yellow}[dragon]%f conf.zsh: DRAGON__${varname}='${val}' is not a valid integer — using default (${_DRAGON_DEFAULTS[$varname]})" >&2
			_DRAGON_CURRENT[$varname]="${_DRAGON_DEFAULTS[$varname]}"
		fi
	done
}

# Reset _DRAGON_CURRENT to defaults, then load overrides from the preset file.
_dragon_apply_preset() {
	local preset="$1"
	local var
	for var in "${(@k)_DRAGON_DEFAULTS}"; do
		_DRAGON_CURRENT[$var]="${_DRAGON_DEFAULTS[$var]}"
	done
	_dragon_load_current_conf_from "${_DRAGON_THEMES_DIR}/presets/${preset}.conf.zsh"
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

# Apply a preset (built-in or personal) into _DRAGON_CURRENT and persist it.
# Preserves USE_NERD_FONT (terminal capability, not style). Writes conf.zsh
# (with the `# preset:` header); returns non-zero if the write fails, so callers
# skip their success message. Assumes the preset name is already validated as an
# existing built-in or personal preset.
_dragon_apply_and_save() {
	local preset="$1"
	local user_file="${_DRAGON_STATE_DIR}/presets/${preset}.conf.zsh"
	local saved_nerd_font="${_DRAGON_CURRENT[USE_NERD_FONT]-}"

	if [[ -n "${_DRAGON_PRESET_DESC[$preset]:-}" ]]; then
		_dragon_apply_preset "$preset"
	else
		local var
		for var in "${(@k)_DRAGON_DEFAULTS}"; do
			_DRAGON_CURRENT[$var]="${_DRAGON_DEFAULTS[$var]}"
		done
		_dragon_load_current_conf_from "$user_file"
	fi

	[[ -n "$saved_nerd_font" ]] && _DRAGON_CURRENT[USE_NERD_FONT]="$saved_nerd_font"
	_dragon_write_conf "$preset" || return 1
}
