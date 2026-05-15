# Provides: file management helpers — extract, bak, sizeof, fp.
# Requires: fp also requires fzf (skipped with an error if not installed).

# Tool name → apt package hint, used by extract() when a tool is missing.
typeset -gA _MO_EXTRACT_HINTS=(
    [tar]="tar"
    [bunzip2]="bzip2"
    [gunzip]="gzip"
    [unzip]="unzip"
    [7z]="p7zip-full"
    [unrar]="unrar"
    [xz]="xz-utils"
    [zstd]="zstd"
)

# Internal: returns 0 if `$1` is on PATH, else prints a clean install hint and returns 1.
_mo_extract_check() {
    command -v "$1" &>/dev/null && return 0
    echo "extract: '$1' not installed (try: sudo apt install ${_MO_EXTRACT_HINTS[$1]:-$1})" >&2
    return 1
}

function extract() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: extract <file> [file2 ...]"
        echo "  Extracts archives of any format:"
        echo "  .tar.gz  .tar.bz2  .tar.xz  .tar.zst  .tar"
        echo "  .gz  .bz2  .xz  .zst  .zip  .7z  .rar"
        return
    fi
    if [[ $# -eq 0 ]]; then
        echo "Usage: extract <file> [file2 ...]  (use -h for details)" >&2
        return 1
    fi
    local failed=0
    for file in "$@"; do
        if [[ ! -f "$file" ]]; then
            echo "extract: '$file' not found" >&2
            failed=1
            continue
        fi
        local _tar_flags="--no-overwrite-dir --no-same-owner --no-same-permissions"
        case "$file" in
            *.tar.bz2)  _mo_extract_check tar     && tar xjf "$file"        ${=_tar_flags} || failed=1 ;;
            *.tar.gz)   _mo_extract_check tar     && tar xzf "$file"        ${=_tar_flags} || failed=1 ;;
            *.tar.xz)   _mo_extract_check tar     && tar xJf "$file"        ${=_tar_flags} || failed=1 ;;
            *.tar.zst)  _mo_extract_check tar     && tar --zstd -xf "$file" ${=_tar_flags} || failed=1 ;;
            *.tar)      _mo_extract_check tar     && tar xf  "$file"        ${=_tar_flags} || failed=1 ;;
            *.bz2)      _mo_extract_check bunzip2 && bunzip2 "$file"        || failed=1 ;;
            *.gz)       _mo_extract_check gunzip  && gunzip  "$file"        || failed=1 ;;
            *.zip)      _mo_extract_check unzip   && unzip -K "$file"       || failed=1 ;;
            *.7z)       _mo_extract_check 7z      && 7z x    "$file"        || failed=1 ;;
            *.rar)      _mo_extract_check unrar   && unrar x "$file"        || failed=1 ;;
            *.xz)       _mo_extract_check xz      && xz -d   "$file"        || failed=1 ;;
            *.zst)      _mo_extract_check zstd    && zstd -d "$file"        || failed=1 ;;
            *) echo "extract: unknown format '$file'" >&2; failed=1 ;;
        esac
    done
    return $failed
}

function bak() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: bak <file> [file ...]"
        echo "  Copy each file to <file>.bak.YYYYMMDD_HHMMSS"
        return
    fi
    local ts
    ts=$(date +%Y%m%d_%H%M%S_%N)
    for f in "$@"; do
        [[ -e "$f" ]] || { echo "bak: not found: $f" >&2; continue; }
        cp -v "$f" "${f}.bak.${ts}"
    done
}

function sizeof() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: sizeof <path> [path2 ...]"
        echo "  Print the disk usage of each path, sorted by size."
        return
    fi
    if [[ $# -eq 0 ]]; then
        echo "Usage: sizeof <path> [path2 ...]  (use -h for details)" >&2
        return 1
    fi
    du -sh "$@" | sort -h
}

fp() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: fp [base-dir]"
        echo "  Interactively select a file and copy its full path to clipboard."
        echo "  base-dir — where to search (default: current directory)"
        echo "  Copies path to clipboard (wl-copy or xclip), or prints it if neither is available."
        echo "  Tip: CTRL+T (fzf plugin) inserts a file path inline at the prompt."
        return
    fi
    _mo_require fzf fp || return
    local base="${1:-.}"
    local preview_cmd
    if command -v bat &>/dev/null; then
        preview_cmd='bat --color=always --style=plain {}'
    elif command -v batcat &>/dev/null; then
        preview_cmd='batcat --color=always --style=plain {}'
    else
        preview_cmd='cat {}'
    fi
    local file
    file=$(find "$base" -type f 2>/dev/null \
        | grep -v '\.git' \
        | fzf --height=40% --reverse --preview-window=right:60%:wrap --preview "$preview_cmd") \
    || return
    local fullpath="${file:a}"
    if command -v wl-copy &>/dev/null; then
        echo -n "$fullpath" | wl-copy
        echo "Copied: $fullpath"
    elif command -v xclip &>/dev/null; then
        echo -n "$fullpath" | xclip -selection clipboard
        echo "Copied: $fullpath"
    else
        echo "$fullpath"
    fi
}
