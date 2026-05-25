
# Resolve the projects directory: honour MO_PROJECTS_PROJ_DIR if set,
# otherwise fall back to ~/projects or ~/Projects (whichever exists first).
_mo_projects_dir() {
    if [[ -n "${MO_PROJECTS_PROJ_DIR:-}" ]]; then
        echo "$MO_PROJECTS_PROJ_DIR"
        return
    fi
    if [[ -d "$HOME/projects" ]]; then
        echo "$HOME/projects"
    elif [[ -d "$HOME/Projects" ]]; then
        echo "$HOME/Projects"
    fi
}

_mo_projects_register_aliases() {
    local proj_dir
    proj_dir="$(_mo_projects_dir)"
    [[ -z "$proj_dir" || ! -d "$proj_dir" ]] && return

    local name
    for name in "$proj_dir"/*(N/); do
        name="${name:t}"
        # Skip if already taken by a builtin, command, function, or alias.
        (( $+builtins[$name] || $+commands[$name] || $+functions[$name] || $+aliases[$name] )) && continue
        # shellcheck disable=SC2139
        alias "$name"="cd ${(q)proj_dir}/${(q)name}"
    done
}

_mo_projects_register_aliases

p() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        echo "Usage: p"
        echo "  fzf-pick a project from \$MO_PROJECTS_PROJ_DIR and cd into it."
        return
    fi
    if ! command -v fzf &>/dev/null; then
        echo "p: fzf not installed (try: sudo apt install fzf)" >&2
        return 1
    fi
    local proj_dir
    proj_dir="$(_mo_projects_dir)"
    if [[ -z "$proj_dir" || ! -d "$proj_dir" ]]; then
        echo "p: no projects directory found (set MO_PROJECTS_PROJ_DIR or create ~/projects)" >&2
        return 1
    fi
    # {} is unquoted so fzf substitutes the bare name; sh assembles the path.
    # proj_dir is baked in at call time with quotes around it.
    local preview_cmd="MO_PDIR=\"$proj_dir\"; item={}; dir=\"\$MO_PDIR/\$item\"
if git -C \"\$dir\" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=\$(git -C \"\$dir\" symbolic-ref --short HEAD 2>/dev/null || git -C \"\$dir\" rev-parse --short HEAD 2>/dev/null)
    printf 'branch: %s\n---\n' \"\$branch\"
    git -C \"\$dir\" status --short 2>/dev/null
else
    ls \"\$dir\"
fi"

    local names=()
    local _n
    for _n in "${proj_dir}"/*(N/); do
        names+=( "${_n:t}" )
    done
    local selected
    selected=$(printf '%s\0' "${names[@]}" | fzf \
        --read0 \
        --prompt="Project> " \
        --height=60% \
        --preview="$preview_cmd" \
        --preview-window=right:40%:wrap) || return 0
    cd "${proj_dir}/${selected}"
}
