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
