# configure/pick.zsh — preset picker (dragon-configure / --pick)
#
# The picker is fzf-driven: fzf handles fuzzy search, scrolling, and the
# alternate screen; a standalone invoker (preview_preset.zsh) renders the
# live preview in its subprocess. The custom TUI that used to live here
# (stty raw-key loop, viewport math, /-search) is gone.

# zshrc's lib/*.zsh loop normally loads this before the theme does, but that
# loop is seeded once at install and never rewritten on update — guard-source
# so _mo_pkg_hint is available even on an install that predates it.
[[ -n ${_MO_PLATFORM_LOADED-} ]] || source "${0:a:h}/../../../lib/platform.zsh"

# One-question Nerd-Font check. Asked before the picker opens every time so the
# answer is written to conf.zsh (USE_NERD_FONT) and preserved by every apply
# path. Sets _DRAGON_CURRENT[USE_NERD_FONT].
_dragon_ask_nerd_font() {
	clear
	print -P "%B%F{cyan}── dragon: Font check ───────────────────────────────────────────────%f%b"
	print ""
	print -P "  dragon uses special characters for a richer look."
	# \u escapes so the glyph bytes survive editing: U+E0B0 powerline
	# right-arrow, U+F07B nerd folder.
	print "  Powerline arrow:  "$'\uE0B0'
	print "  Nerd Font icon:   "$'\uF07B'
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

# Build the preset list — one alphabetical sort across built-ins and personal
# presets, with personal presets tagged "(personal)" in the description. A
# personal preset shadowing a built-in name replaces the built-in row
# (matches apply-time semantics where the personal file wins). fzf has no
# mid-list divider, so a single merged sort replaces the old two-list layout.
# Populates three global parallel arrays:
#   _DRAGON_PICK_NAMES[i]  — preset name
#   _DRAGON_PICK_TYPE[i]   — builtin | user
#   _DRAGON_PICK_DESC[i]   — description ("(personal)" for user presets)
_dragon_pick_build_list() {
	# (#qN) nullglob qualifier needs extended_glob; set it locally so the
	# glob works regardless of the caller's options (matches prompt.zsh).
	setopt local_options extended_glob
	typeset -ga _DRAGON_PICK_NAMES=() _DRAGON_PICK_TYPE=() _DRAGON_PICK_DESC=()
	local f name desc

	# Collect personal preset names from disk first so a shadowing personal
	# file can replace its built-in in the merged list.
	local -a _unames=()
	local -A _is_user=()
	for f in "${_DRAGON_STATE_DIR}"/presets/*.conf.zsh(#qN); do
		name="${f##*/}"; name="${name%.conf.zsh}"
		# Names created through --export are already restricted to this set;
		# a file dropped in by hand (or a restored backup) is not — reject
		# anything else rather than embed it unvalidated into fzf's
		# tab-delimited input.
		[[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || continue
		_unames+=("$name")
		_is_user[$name]=1
	done

	# Merge built-ins and personal into one name→desc map, then sort by name.
	# (o) sorts alphabetically. A personal preset shadowing a built-in wins,
	# so it's added after (overwrites) the built-in entry.
	local -A _name2desc=() _name2type=()
	for name in "${_DRAGON_PRESET_NAMES[@]}"; do
		_name2desc[$name]="${_DRAGON_PRESET_DESC[$name]:-}"
		_name2type[$name]="builtin"
	done
	for name in "${_unames[@]}"; do
		_name2desc[$name]="(personal)"
		_name2type[$name]="user"
	done

	for name in "${(o@k)_name2desc}"; do
		_DRAGON_PICK_NAMES+=("$name")
		_DRAGON_PICK_TYPE+=("${_name2type[$name]}")
		_DRAGON_PICK_DESC+=("${_name2desc[$name]}")
	done
}

# Return all preset names (built-ins + personal, deduped — a personal preset
# shadowing a built-in wins) on stdout. Used by completion (_dragon-configure)
# so it shares the picker's candidate source. _dragon_cleanup unsets
# _DRAGON_PRESET_NAMES after a wizard run, so re-init presets when empty —
# _dragon_init_presets is idempotent.
_dragon_preset_names() {
	(( ${#_DRAGON_PRESET_NAMES} == 0 )) && _dragon_init_presets
	_dragon_pick_build_list
	local i
	for (( i = 1; i <= ${#_DRAGON_PICK_NAMES}; i++ )); do
		print -r -- "${_DRAGON_PICK_NAMES[$i]}"
	done
}

_dragon_pick_preset() {
	command -v fzf &>/dev/null || {
		print -P "%F{red}✗%f dragon-configure --pick requires %Bfzf%b (try: $(_mo_pkg_hint fzf))" >&2
		return 1
	}

	# Initialise schema if not already done (supports standalone --pick call).
	(( ${#_DRAGON_PRESET_NAMES} == 0 )) && {
		_dragon_init_defaults
		_dragon_init_types
		_dragon_init_hints
		_dragon_init_groups
		_dragon_init_presets || return 1
		_dragon_load_current_conf
	}

	# Ask the Nerd-Font question before entering fzf (writes USE_NERD_FONT
	# into _DRAGON_CURRENT so the apply preserves it). The answer is passed
	# to the preview subprocess, which can't see this process's _DRAGON_CURRENT.
	_dragon_ask_nerd_font
	local nf="${_DRAGON_CURRENT[USE_NERD_FONT]}"

	_dragon_pick_build_list
	local n=${#_DRAGON_PICK_NAMES}
	(( n == 0 )) && { print -P "%F{red}✗%f No presets found."; return 1; }

	# fzf input: name \t description. {1} in the preview template = the name.
	# --with-nth=1,2 displays both columns; --nth=1 restricts fuzzy search to
	# the name only, so descriptions don't pollute matches (e.g. "cap" wouldn't
	# otherwise narrow to capsule/catppuccin — every desc with c…a…p matches).
	local i name desc input=""
	for (( i = 1; i <= ${#_DRAGON_PICK_NAMES}; i++ )); do
		name="${_DRAGON_PICK_NAMES[$i]}"
		desc="${_DRAGON_PICK_DESC[$i]}"
		input+="${name}"$'\t'"${desc}"$'\n'
	done

	local preview="${_DRAGON_THEMES_DIR}/configure/preview_preset.zsh"
	# Preview context is bound to Alt- combos, not bare letters: fzf binds
	# consume their keystroke, so binding s/S/p would make those letters
	# untypeable in the search query (e.g. "capsule" needs the p). Alt- keeps
	# every printable char free for fzf's fuzzy search.
	#   Alt-s = SSH preview, Alt-S = fail preview, Alt-p = plain preview.
	# No --query seed: fzf has no native "highlight without filter", and a
	# seeded query narrows the list to the active preset's letters, which
	# hides the other presets the user came to browse.
	# Pass the preview script path via env to avoid shell-quoting issues when
	# _DRAGON_THEMES_DIR contains single quotes (fzf --preview is a shell
	# snippet; env vars sidestep the quoting minefield).
	local chosen
	chosen=$(printf '%s' "$input" | DRAGON_PREVIEW="${preview}" fzf \
		--reverse \
		--ansi \
		--delimiter=$'\t' \
		--with-nth=1,2 \
		--nth=1 \
		--preview-window=down:70%:wrap \
		--height=100% \
		--header="Enter: apply  Alt-s: ssh preview  Alt-S: fail  Alt-p: plain  Esc: cancel" \
		--preview='zsh "$DRAGON_PREVIEW" {1} plain '"${(q)nf}" \
		--bind='alt-s:change-preview(zsh "$DRAGON_PREVIEW" {1} ssh '"${(q)nf}"')' \
		--bind='alt-S:change-preview(zsh "$DRAGON_PREVIEW" {1} fail '"${(q)nf}"')' \
		--bind='alt-p:change-preview(zsh "$DRAGON_PREVIEW" {1} plain '"${(q)nf}"')')
	local rc=$?

	# fzf prints the full selected line "name\tdesc"; extract the name.
	local preset="${chosen%%$'\t'*}"

	# 130 = Esc/Ctrl-C, matching _mo_color_pick's convention for a cancelled
	# pick; anything else empty (no matches, etc.) stays a plain success exit.
	[[ -z "$preset" ]] && { print -P "  %F{245}Cancelled.%f"; (( rc == 130 )) && return 130; return 0; }

	# Apply the chosen preset with the same flow as --preset.
	print ""
	print -P "%B%F{cyan}── dragon: Switch to '${preset}' preset ─────────────────────────────%f%b"
	print ""
	print -P "  This will reset your theme config to the %B${preset}%b preset."
	if ! _dragon_warn_preset_reset "Switch to ${preset} preset now?"; then
		print ""
		print -P "  %F{245}Aborted. Your conf.zsh is unchanged.%f"
		return 0
	fi

	_dragon_apply_and_save "$preset" || return 1

	print ""
	print -P "  %F{green}✓ Switched to %B${preset}%b%F{green} preset.%f"
	print -P "  %F{245}Reload to apply: %Brezsh%b%f"
	print -P "  %F{245}Fine-tune with:  %Bdragon-configure --edit%b%f"
	print ""
}
