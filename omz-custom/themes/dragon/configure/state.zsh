# configure/state.zsh — conf loading and preset apply

# Read the `# preset: <name>` header from conf.zsh (the sole source of truth for
# the active preset since the state file was removed). Empty if absent.
_dragon_active_preset() {
	[[ -f "${_DRAGON_CONF_FILE}" ]] || return
	# `command grep` bypasses any user grep alias (e.g. one adding --exclude
	# globs, which zsh's nomatch would abort on).
	command grep -m1 '^# preset: ' "${_DRAGON_CONF_FILE}" 2>/dev/null | cut -d' ' -f3
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
	_dragon_reset_current_to_defaults

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

# Reset _DRAGON_CURRENT to the schema defaults. Single source of truth for the
# "clear before applying a preset" prologue. Forgetting to reset leaves stale
# values from a previous apply bleeding into the next one, so every apply path
# goes through this helper.
_dragon_reset_current_to_defaults() {
	(( ${#_DRAGON_DEFAULTS} )) || return 1
	typeset -gA _DRAGON_CURRENT=()
	local var
	for var in "${(@k)_DRAGON_DEFAULTS}"; do
		_DRAGON_CURRENT[$var]="${_DRAGON_DEFAULTS[$var]}"
	done
}

# Resolve a preset name to the file to load. A personal file always shadows the
# built-in of the same name — the picker labels such a row "(personal)", so apply
# and preview must agree or the label lies. Single source of truth for that
# precedence, shared by _dragon_apply_and_save and preview_preset.zsh.
_dragon_preset_file() {
	local preset="$1"
	local user_file="${_DRAGON_STATE_DIR}/presets/${preset}.conf.zsh"
	if [[ -f "$user_file" ]]; then
		print -r -- "$user_file"
	elif [[ -n "${_DRAGON_PRESET_DESC[$preset]:-}" ]]; then
		print -r -- "${_DRAGON_THEMES_DIR}/presets/${preset}.conf.zsh"
	else
		return 1
	fi
}

# Reset _DRAGON_CURRENT to defaults, then load overrides from the preset file.
_dragon_apply_preset() {
	local preset="$1"
	_dragon_reset_current_to_defaults
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

# Re-bake the DRAGON__PAYLOAD at the bottom of conf.zsh from its current visible
# exports. Hand-editing conf.zsh changes the `export DRAGON__*` lines but leaves
# the base64 payload stale — so the edits render locally (the payload is only
# decoded over SSH) but don't travel until something rewrites the payload.
# dragon-configure --edit / --export call this after touching conf.zsh so the
# baked snapshot matches what the file currently says.
#
# Re-reads conf.zsh into _DRAGON_CURRENT (in case it was just edited) and writes
# it back through the writer, preserving the `# preset:` header. Requires the
# schema inits (_DRAGON_DEFAULTS) — both callers run them first. Returns non-zero
# if the write fails.
_dragon_rebake_payload() {
	[[ -n "${_DRAGON_DEFAULTS:-}" ]] || return 1
	_dragon_load_current_conf
	local preset
	preset="$(_dragon_active_preset)"
	_dragon_write_conf "$preset"
}

# Apply a preset (built-in or personal) into _DRAGON_CURRENT and persist it.
# Preserves USE_NERD_FONT (terminal capability, not style). Writes conf.zsh
# (with the `# preset:` header); returns non-zero if the preset name resolves to
# no file or the write fails, so callers skip their success message.
_dragon_apply_and_save() {
	local preset="$1"
	local preset_file
	preset_file="$(_dragon_preset_file "$preset")" || return 1
	local saved_nerd_font="${_DRAGON_CURRENT[USE_NERD_FONT]-}"

	_dragon_reset_current_to_defaults
	_dragon_load_current_conf_from "$preset_file"

	[[ -n "$saved_nerd_font" ]] && _DRAGON_CURRENT[USE_NERD_FONT]="$saved_nerd_font"
	_dragon_write_conf "$preset" || return 1
}
