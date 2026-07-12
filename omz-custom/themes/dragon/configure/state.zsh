# configure/state.zsh — state-file I/O and conf loading

_dragon_vars_hash() {
	# Hash the sorted list of _DRAGON_DEFAULTS keys — the authoritative schema
	# source of truth. Immune to grep over-matching comments/docs.
	# Must match notifier.zsh and install.sh — change all three together.
	printf '%s\n' "${(@k)_DRAGON_DEFAULTS}" | sort | md5sum | cut -d' ' -f1
}

_dragon_read_state() {
	typeset -gA _DRAGON_STATE=()
	[[ -f "${_DRAGON_STATE_FILE}" ]] || return
	while IFS= read -r line; do
		[[ "$line" == '#'* || -z "$line" ]] && continue
		# %%=* strips up to the first = for the key (keys are DRAGON__[A-Z_]+ — no = possible).
		# #*=  strips only the first = and keeps everything after, so values like "foo=bar" survive.
		local key="${line%%=*}" val="${line#*=}"
		_DRAGON_STATE[$key]="$val"
	done < "${_DRAGON_STATE_FILE}"
}

_dragon_write_state() {
	local preset="${1:-default}"
	local hash mtime
	hash=$(_dragon_vars_hash)
	mtime=$(stat -c '%Y' "${_DRAGON_THEMES_DIR}/schema.zsh" 2>/dev/null)
	_dragon_read_state   # load current state so we can preserve dismissed_hash
	mkdir -p "${_DRAGON_STATE_DIR}"
	{
		echo "configured=true"
		echo "preset=${preset}"
		echo "vars_hash=${hash}"
		echo "themes_mtime=${mtime}"
		# Preserve dismissed_hash across configure runs so --dismiss stays effective
		[[ -n "${_DRAGON_STATE[dismissed_hash]:-}" ]] \
			&& echo "dismissed_hash=${_DRAGON_STATE[dismissed_hash]}"
	} > "${_DRAGON_STATE_FILE}"
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
# then the state file; returns non-zero without touching state if the conf
# write fails, so callers skip their success message. Assumes the preset name
# is already validated as an existing built-in or personal preset.
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
	_dragon_write_conf || return 1
	_dragon_write_state "$preset"
}
