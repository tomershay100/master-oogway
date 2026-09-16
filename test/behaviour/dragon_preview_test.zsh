# The preview cds into a throwaway tree under $TMPDIR so %~ renders the demo
# path. That tree is created inside a child zsh, so only a trap in that child
# can remove it — a caller-side trap never fires for it. Without one, every
# preview left a directory behind and one --gallery run leaked 43 of them.

_mo_preview_tmp="$(mktemp -d "${${TMPDIR:-/tmp}%/}/mo-preview-test.XXXXXX")"

# A trailing slash, as macOS sets TMPDIR: a HOME containing // is never a
# prefix of PWD, and %~ silently stops abbreviating.
_mo_preview_out="$(TMPDIR="$_mo_preview_tmp/" zsh -f -c "
	source ${(q)MO_ROOT}/omz-custom/themes/dragon/configure.zsh
	_dragon_render_preview
	_dragon_render_preview --ssh >/dev/null
	_dragon_render_preview --fail >/dev/null
	dragon-configure --gallery >/dev/null" 2>&1)"

# Rendering must actually have happened for the leak assertion to mean anything.
assert_contains "$_mo_preview_out" "~/projects/myapp/src/components" \
	"dragon preview renders the demo path abbreviated under the fake HOME"

_mo_preview_left=("$_mo_preview_tmp"/.dragon-preview-*(N))
assert_eq 0 "${#_mo_preview_left}" \
	"dragon preview removes its temp tree (left ${#_mo_preview_left} behind)"

command rm -rf "$_mo_preview_tmp"
unset _mo_preview_tmp _mo_preview_out _mo_preview_left
