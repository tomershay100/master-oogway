typeset -gA _DRAGON_COLOR_CACHE=()

__get_xterm_color_by_name()
{
	XTERM_COLOR=""
	local color_name="$1"
	[[ -z "$color_name" ]] && return

	if (( ${+_DRAGON_COLOR_CACHE[$color_name]} )); then
		XTERM_COLOR="${_DRAGON_COLOR_CACHE[$color_name]}"
		return
	fi

	if [[ $color_name =~ ^[0-9]+$ && 10#$color_name -le 255 ]]; then
		XTERM_COLOR="$color_name"
	else
		local fg_code="${_MO_COLORS[${(L)color_name}]}"
		if [[ -n "$fg_code" ]]; then
			XTERM_COLOR="$fg_code"
		else
			print -P "%F{red}[dragon] unknown color: '${color_name}' — check ~/.config/master-oogway/conf.zsh%f" >&2
		fi
	fi

	_DRAGON_COLOR_CACHE[$color_name]="$XTERM_COLOR"
}

__get_xterm_style_format()
{
	local fg_color="$1"
	local bg_color="$2"
	local is_bold="$3"
	local is_underline="$4"

	STYLE_FORMAT=""
	[[ "$is_bold" == "true" ]] && STYLE_FORMAT+="%B" || STYLE_FORMAT+="%b"
	[[ "$is_underline" == "true" ]] && STYLE_FORMAT+="%U" || STYLE_FORMAT+="%u"

	__get_xterm_color_by_name "$fg_color"
	local fg_code="$XTERM_COLOR"
	if [[ -n "$fg_code" ]]; then
		STYLE_FORMAT+="%F{$fg_code}"
	else
		STYLE_FORMAT+="%f"
	fi

	__get_xterm_color_by_name "$bg_color"
	local bg_code="$XTERM_COLOR"
	if [[ -n "$bg_code" ]]; then
		STYLE_FORMAT+="%K{$bg_code}"
	else
		STYLE_FORMAT+="%k"
	fi
}

__dragon__show()
{
	local name="$1"

	local var_content="REAL_DRAGON__${name}_CONTENT"
	local var_prefix="REAL_DRAGON__${name}_PREFIX"
	local var_suffix="REAL_DRAGON__${name}_SUFFIX"

	local var_fg_color="REAL_DRAGON__${name}_FOREGROUND_COLOR"
	local var_bg_color="REAL_DRAGON__${name}_BACKGROUND_COLOR"
	local var_is_bold="REAL_DRAGON__${name}_BOLD"
	local var_is_underline="REAL_DRAGON__${name}_UNDERLINE"

	local curr_content="${(P)var_content}"
	local curr_prefix="${${(P)var_prefix}//\%/%%}"
	local curr_suffix="${${(P)var_suffix}//\%/%%}"

	local curr_fg_color="${(P)var_fg_color}"
	local curr_bg_color="${(P)var_bg_color}"
	local curr_is_bold="${(P)var_is_bold}"
	local curr_is_underline="${(P)var_is_underline}"

	__get_xterm_style_format "$curr_fg_color" "$curr_bg_color" "$curr_is_bold" "$curr_is_underline"

	SHOW_RESULT="$RESET_FORMAT$STYLE_FORMAT$curr_prefix$curr_content$curr_suffix$RESET_FORMAT"
}

# Two helpers used by every segment in segments_left.zsh / segments_right.zsh
# to copy DRAGON__X_* → REAL_DRAGON__X_* and finalize via __dragon__show.

# __dragon_copy_defaults <NAME> [field ...]
#   Copy DRAGON__${NAME}_${field} → REAL_DRAGON__${NAME}_${field} for each
#   field. With no field args, copies all six standard fields. Segments that
#   override a subset (prompt_char uses *_DEFAULT_FOREGROUND_COLOR, not
#   *_FOREGROUND_COLOR; ssh_prefix hardcodes empty PREFIX/SUFFIX) pass an
#   explicit field list and set the rest themselves.
__dragon_copy_defaults()
{
	local name="$1"
	shift
	local -a fields
	if (( $# == 0 )); then
		fields=(PREFIX SUFFIX FOREGROUND_COLOR BACKGROUND_COLOR BOLD UNDERLINE)
	else
		fields=("$@")
	fi
	local f src
	for f in "${fields[@]}"; do
		src="DRAGON__${name}_${f}"
		typeset -g "REAL_DRAGON__${name}_${f}=${(P)src}"
	done
}

# __dragon_finalize <NAME> [final_var]: __dragon__show then store SHOW_RESULT.
# Pass final_var for the legacy prompt_char case (FINAL_PROMPT_CHAR_CONTENT).
__dragon_finalize()
{
	local name="$1"
	local final_var="${2:-FINAL_DRAGON__${name}_CONTENT}"
	__dragon__show "$name"
	typeset -g "$final_var=$SHOW_RESULT"
}
