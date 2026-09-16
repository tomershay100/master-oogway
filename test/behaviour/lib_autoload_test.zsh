source "$MO_ROOT/omz-custom/lib/platform.zsh"

# oh-my-zsh never auto-sources lib/platform.zsh: its lib loop consults
# $ZSH_CUSTOM/lib/<name>.zsh only as an override of a file that exists in its
# own lib/, and it has no platform.zsh. The zshrc template does source it, but
# that file is seeded once and never rewritten on update — so an install made
# before the lib existed loads every plugin with the primitives undefined, and
# rm silently stops going to the trash. Each plugin must load the lib itself.

_mo_autoload_probe() {
	zsh -f -c "source ${(q)1} >/dev/null 2>&1
		typeset -f _mo_is_linux >/dev/null && print -r -- defined || print -r -- undefined"
}

_mo_autoload_stderr() {
	zsh -f -c "source ${(q)1} >/dev/null" 2>&1 >/dev/null
}

typeset -g _mo_autoload_noise=""

# requirements.zsh counts: it is sourced by the plugin and calls primitives of
# its own (_mo_pkg_hint in every "missing: ..." message), so a plugin whose
# only primitive use lives there needs the guard just as much.
for _mo_autoload_f in "$MO_ROOT"/omz-custom/plugins/mo-*/mo-*.plugin.zsh(#qN); do
	grep -qs '_mo_' "$_mo_autoload_f" "${_mo_autoload_f:h}/requirements.zsh" || continue

	assert_eq defined "$(_mo_autoload_probe "$_mo_autoload_f")" \
		"${_mo_autoload_f:h:t} has the platform primitives when sourced alone"

	_mo_autoload_noise+="$(_mo_autoload_stderr "$_mo_autoload_f")"
done

# The user-visible symptom of the bug: a wall of command-not-found at every
# shell start, one line per primitive each plugin reaches for.
assert_not_contains "$_mo_autoload_noise" "command not found: _mo_" \
	"no plugin reports a missing primitive when sourced alone"

unset _mo_autoload_f _mo_autoload_noise
unfunction _mo_autoload_probe _mo_autoload_stderr
