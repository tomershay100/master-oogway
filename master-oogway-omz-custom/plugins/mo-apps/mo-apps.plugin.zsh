# Provides: launcher aliases for GUI applications installed via flatpak.
# Requires: flatpak (each alias is skipped silently if flatpak is not installed).

command -v flatpak &>/dev/null && alias gnucash="WEBKIT_DISABLE_COMPOSITING_MODE=1 flatpak run org.gnucash.GnuCash"
