# dragon theme aliases

# dragon-configure's _dragon_cleanup unsets _DRAGON_DEFAULTS at the end of every
# wizard run, so an `rezsh` later in the same shell would iterate an empty array.
# Re-populate from the schema first; the source + init are both idempotent.
(( ${+_DRAGON_THEME_DIR} )) || typeset -gr _DRAGON_THEME_DIR="${0:a:h}"

reset_theme_variables() {
	source "${_DRAGON_THEME_DIR}/schema.zsh"
	_dragon_init_defaults
	for var in "${(@k)_DRAGON_DEFAULTS}"; do
		unset "DRAGON__${var}"
	done
	# Clear the baked SSH-forwarding payload too, so conf.zsh re-bakes it fresh
	# from the reset values on the next source (soursh).
	unset DRAGON__PAYLOAD
}

alias rezsh="reset_theme_variables && soursh"