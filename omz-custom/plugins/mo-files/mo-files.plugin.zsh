
# Tool name → apt package hint, shared by extract() and compress().
typeset -gA _MO_EXTRACT_HINTS=(
    [tar]="tar"
    [bunzip2]="bzip2"
    [gunzip]="gzip"
    [gzip]="gzip"
    [bzip2]="bzip2"
    [unzip]="unzip"
    [zip]="zip"
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

# Internal: safe zip extraction. unzip has no built-in path-traversal defense
# (unlike modern GNU tar which refuses '..' by default), so we:
#   1. Pre-scan entries with `unzip -Z1`. Refuse if any entry is absolute
#      (starts with /) or contains '..' as a path component.
#   2. Extract into a named subdir derived from the archive name to contain
#      damage and avoid clobbering files already present in CWD.
#   3. Refuse if the destination subdir already exists, so re-running extract
#      on the same archive doesn't silently merge into an existing tree.
_mo_extract_zip() {
    local f="$1"
    local entries
    entries=$(unzip -Z1 "$f" 2>/dev/null) \
        || { echo "extract: cannot list entries in '$f'" >&2; return 1; }
    if grep -qE '(^/|(^|/)\.\.(/|$))' <<< "$entries"; then
        echo "extract: refusing '$f' — contains absolute or traversal paths" >&2
        echo "  inspect with: unzip -Z1 '$f'" >&2
        return 1
    fi
    local outdir="${f:t:r}"
    if [[ -e "$outdir" ]]; then
        echo "extract: refusing — '$outdir' already exists; remove it first or extract manually" >&2
        return 1
    fi
    unzip -K -d "$outdir" "$f"
}

extract() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
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
        # .gz/.bz2/.xz/.zst (bare, not .tar.*) decompress in-place, replacing the source file.
        # A symlink here would silently mutate the symlink target rather than the file in CWD.
        if [[ -L "$file" ]]; then
            case "$file" in
                *.tar.*) ;; # tar reads non-destructively — symlinks are fine
                *.gz|*.bz2|*.xz|*.zst)
                    echo "extract: '$file' is a symlink — in-place decompression would modify the symlink target" >&2
                    echo "  Run on the real file: $(realpath "$file")" >&2
                    failed=1
                    continue
                    ;;
            esac
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
            *.zip)      _mo_extract_check unzip   && _mo_extract_zip "$file"    || failed=1 ;;
            *.7z)       _mo_extract_check 7z      && 7z x    "$file"        || failed=1 ;;
            *.rar)      _mo_extract_check unrar   && unrar x "$file"        || failed=1 ;;
            *.xz)       _mo_extract_check xz      && xz -d   "$file"        || failed=1 ;;
            *.zst)      _mo_extract_check zstd    && zstd -d "$file"        || failed=1 ;;
            *) echo "extract: unknown format '$file'" >&2; failed=1 ;;
        esac
    done
    return $failed
}

bak() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        echo "Usage: bak <file> [file ...]"
        echo "  Copy each file to <file>.bak.YYYYMMDD_HHMMSS"
        return
    fi
    local ts
    ts=$(date +%Y%m%d_%H%M%S_%N)
    for f in "$@"; do
        [[ -e "$f" ]] || { echo "bak: not found: $f" >&2; continue; }
        # -a preserves mode/owner/timestamps/xattrs/symlinks so a later
        # restore reproduces the original file faithfully (including +x).
        cp -av "$f" "${f}.bak.${ts}"
    done
}

sizeof() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
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
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        echo "Usage: fp [base-dir]"
        echo "  Interactively select a file and copy its full path to clipboard."
        echo "  base-dir — where to search (default: current directory)"
        echo "  Copies path to clipboard (wl-copy or xclip), or prints it if neither is available."
        echo "  Tip: CTRL+T (fzf plugin) inserts a file path inline at the prompt."
        return
    fi
    command -v fzf &>/dev/null || { echo "fp: fzf not installed" >&2; return 1; }
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
    file=$(find "$base" -type f -not -path '*/.git/*' -print0 2>/dev/null \
        | fzf --read0 --height=40% --reverse --preview-window=right:60%:wrap --preview "$preview_cmd") \
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

_mo_compress_check() {
    command -v "$1" &>/dev/null && return 0
    echo "compress: '$1' not installed (try: sudo apt install ${_MO_EXTRACT_HINTS[$1]:-$1})" >&2
    return 1
}

compress() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        cat <<'EOF'
Usage: compress [<archive>] <file|dir> [file2 ...]

  Format is chosen by the archive extension:
    .tar.zst  .tar.gz  .tar.bz2  .tar.xz  .tar  .zip  .7z

  If no archive name is given, uses the current directory name and
  creates a .tar.zst in the current directory.

Examples:
  compress backup.tar.gz src/ config/
  compress archive.zip *.txt
  compress src/                        # → <dirname>.tar.zst in cwd
EOF
        return
    fi

    if [[ $# -eq 0 ]]; then
        echo "Usage: compress [<archive>] <file|dir> [file2 ...]  (use -h for details)" >&2
        return 1
    fi

    local archive=""
    local -a sources

    case "$1" in
        *.tar.zst|*.tar.gz|*.tar.bz2|*.tar.xz|*.tar|*.zip|*.7z)
            archive="$1"; shift ;;
    esac

    if [[ $# -eq 0 ]]; then
        echo "compress: no source files specified" >&2
        return 1
    fi

    sources=( "$@" )

    [[ -z "$archive" ]] && archive="${PWD:t}.tar.zst"

    if [[ -e "$archive" ]]; then
        echo "compress: '$archive' already exists — remove it first" >&2
        return 1
    fi

    local src
    for src in "${sources[@]}"; do
        [[ -e "$src" ]] || { echo "compress: '$src' not found" >&2; return 1; }
    done

    case "$archive" in
        *.tar.zst)  _mo_compress_check tar  && _mo_compress_check zstd  \
                        && tar --zstd -cf "$archive" "${sources[@]}" ;;
        *.tar.gz)   _mo_compress_check tar  && _mo_compress_check gzip  \
                        && tar czf "$archive" "${sources[@]}" ;;
        *.tar.bz2)  _mo_compress_check tar  && _mo_compress_check bzip2 \
                        && tar cjf "$archive" "${sources[@]}" ;;
        *.tar.xz)   _mo_compress_check tar  && _mo_compress_check xz    \
                        && tar cJf "$archive" "${sources[@]}" ;;
        *.tar)      _mo_compress_check tar  \
                        && tar cf  "$archive" "${sources[@]}" ;;
        *.zip)      _mo_compress_check zip  \
                        && zip -r  "$archive" "${sources[@]}" ;;
        *.7z)       _mo_compress_check 7z   \
                        && 7z a    "$archive" "${sources[@]}" ;;
        *)
            echo "compress: unknown format for '$archive'" >&2
            echo "  Supported: .tar.zst .tar.gz .tar.bz2 .tar.xz .tar .zip .7z" >&2
            return 1
            ;;
    esac && echo "Created: $archive"
}
