# Provides: file management helpers — extract, bak, sizeof, fpath.
# Requires: fpath also requires fzf (skipped with an error if not installed).

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
        case "$file" in
            *.tar.bz2)  tar xjf "$file"        ;;
            *.tar.gz)   tar xzf "$file"        ;;
            *.tar.xz)   tar xJf "$file"        ;;
            *.tar.zst)  tar --zstd -xf "$file" ;;
            *.tar)      tar xf  "$file"        ;;
            *.bz2)      bunzip2 "$file"        ;;
            *.gz)       gunzip  "$file"        ;;
            *.zip)      unzip   "$file"        ;;
            *.7z)       7z x    "$file"        ;;
            *.rar)      unrar x "$file"        ;;
            *.xz)       xz -d   "$file"        ;;
            *.zst)      zstd -d "$file"        ;;
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
    ts=$(date +%Y%m%d_%H%M%S)
    for f in "$@"; do cp -v "$f" "${f}.bak.${ts}"; done
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

fpath() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: fpath [base-dir]"
        echo "  Interactively select a file and copy its full path to clipboard."
        echo "  base-dir — where to search (default: current directory)"
        echo "  Copies path to clipboard (xclip), or prints it if xclip is unavailable."
        echo "  Tip: CTRL+T (fzf plugin) inserts a file path inline at the prompt."
        return
    fi
    command -v fzf &>/dev/null || { echo "fpath: fzf not installed" >&2; return 1; }
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
    if command -v xclip &>/dev/null; then
        echo -n "$fullpath" | xclip -selection clipboard
        echo "Copied: $fullpath"
    else
        echo "$fullpath"
    fi
}
