# lib/optdeps.zsh — optional dependency detection, run once at framework load.
#
# Plugins query _MO_OPT_BIN instead of calling `command -v` at source time,
# saving one fork per check. For tools with alternate package names (bat/batcat,
# fd/fdfind) the map stores the actual available command so plugins get the right
# binary without a second lookup.
#
# Usage:
#   (( $+_MO_OPT_BIN[fzf] ))     — boolean: is fzf installed?
#   cmd=$_MO_OPT_BIN[bat]         — get the real bat command (bat or batcat)
#   [[ -n $_MO_OPT_BIN[bat] ]]    — same boolean check via string

typeset -gA _MO_OPT_BIN=()

# Tools with a single canonical name — present = "1", absent = key not set.
for _mo_tool in fzf rg eza colormake wl-copy xclip nvim \
                trash-put pandoc xelatex lsof pgrep arp-scan nmap \
                dig 7z unrar zstd bc curl; do
    (( $+commands[$_mo_tool] )) && _MO_OPT_BIN[$_mo_tool]=1
done
unset _mo_tool

# Tools with alternate package names — value is the actual command to use.
# bat: Ubuntu packages it as 'batcat' to avoid conflict with 'moo' (old package).
if   (( $+commands[bat]    )); then _MO_OPT_BIN[bat]=bat
elif (( $+commands[batcat] )); then _MO_OPT_BIN[bat]=batcat
fi
# fd: Ubuntu packages it as 'fdfind'.
if   (( $+commands[fd]     )); then _MO_OPT_BIN[fd]=fd
elif (( $+commands[fdfind] )); then _MO_OPT_BIN[fd]=fdfind
fi
