# dragon theme aliases

function reset_theme_variables {
    for var in "${(@k)_AF_DEFAULTS}"; do
        unset "DRAGON__${var}"
    done
}

alias rezsh="reset_theme_variables && soursh"