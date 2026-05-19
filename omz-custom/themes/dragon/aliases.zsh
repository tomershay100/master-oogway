# dragon theme aliases

# dragon-configure's _dragon_cleanup unsets _DRAGON_DEFAULTS at the end of every
# wizard run, so an `rezsh` later in the same shell would iterate an empty array.
# Re-populate from the schema first; the source + init are both idempotent.
function reset_theme_variables {
    source "${0:a:h}/schema.zsh"
    _dragon_init_defaults
    for var in "${(@k)_DRAGON_DEFAULTS}"; do
        unset "DRAGON__${var}"
    done
}

alias rezsh="reset_theme_variables && soursh"