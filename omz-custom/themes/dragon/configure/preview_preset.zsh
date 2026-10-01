# configure/preview_preset.zsh — fzf preview invoker.
# Run by fzf's --preview in a fresh subprocess, so it can't see the picker's
# in-memory _DRAGON_CURRENT. It sources the theme config, applies the preset
# the highlighted row names, and renders it. Invoked as:
#   zsh preview_preset.zsh <name> <plain|ssh|fail> <nerd-font:true|false>

emulate -L zsh

local name="${1:-}" ctx="${2:-plain}" nf="${3:-true}"

# configure.zsh sets the file-level constants (_DRAGON_THEMES_DIR etc.) and
# defines the init/apply/render functions. ${0:a:h} is the configure/ dir.
# A failed source here would otherwise fall through to undefined-function
# errors that fzf renders as the preview pane content.
source "${0:a:h}/../configure.zsh" || exit 1

_dragon_init_defaults
_dragon_init_presets || exit 1

# _DRAGON_CURRENT must be an assoc array before _dragon_apply_preset writes to
# it; seed from defaults via the shared helper (same path as the in-process
# picker and _dragon_load_current_conf). A failure here means the schema
# never initialised — better to show nothing than a preview built on an
# empty config.
_dragon_reset_current_to_defaults || exit 1

# Built-in vs personal — shares _dragon_preset_file with _dragon_apply_and_save
# so the preview shows the same file the apply will load.
local preset_src
preset_src="$(_dragon_preset_file "$name")" || exit 1
_dragon_load_current_conf_from "$preset_src"

# Font answer is a terminal capability, not preset style — wins over the
# preset's hardcoded USE_NERD_FONT (same override the in-process picker used).
_DRAGON_CURRENT[USE_NERD_FONT]="$nf"

case "$ctx" in
	ssh)  _dragon_render_preview --ssh ;;
	fail) _dragon_render_preview --fail ;;
	*)    _dragon_render_preview ;;
esac
