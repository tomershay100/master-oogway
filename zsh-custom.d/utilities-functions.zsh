# Utility functions

############# mkcd: mkdir + cd in one step ##############
function mkcd() {
    if [[ "$1" == "-h" || "$1" == "--help" || $# -eq 0 ]]; then
        echo "Usage: mkcd <dir>"
        echo "  Create <dir> (including parents) and cd into it."
        return
    fi
    mkdir -p "$1" && cd "$1"
}

############# up: go up N levels, or up to a named ancestor directory ##############
function up() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: up [n | dirname]"
        echo "  up          — go up one level (same as cd ..)"
        echo "  up 3        — go up 3 levels"
        echo "  up src      — go up to the nearest ancestor named 'src'"
        return
    fi

    if [[ $# -eq 0 ]]; then
        cd ..
        return
    fi

    if [[ "$1" =~ '^[0-9]+$' ]]; then
        local uppath=""
        for i in {1..$1}; do uppath+="../"; done
        cd "$uppath"
        return
    fi

    # named mode: walk up until basename matches
    local dir=$PWD
    while [[ "$dir" != "/" ]]; do
        dir=$(dirname "$dir")
        if [[ "$(basename "$dir")" == "$1" ]]; then
            cd "$dir"
            return
        fi
    done
    echo "up: '$1' not found in path" >&2
    return 1
}

############# extract: universal archive extractor ##############
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
            *.tar.bz2)  tar xjf "$file"            ;;
            *.tar.gz)   tar xzf "$file"            ;;
            *.tar.xz)   tar xJf "$file"            ;;
            *.tar.zst)  tar --zstd -xf "$file"     ;;
            *.tar)      tar xf  "$file"            ;;
            *.bz2)      bunzip2 "$file"            ;;
            *.gz)       gunzip  "$file"            ;;
            *.zip)      unzip   "$file"            ;;
            *.7z)       7z x    "$file"            ;;
            *.rar)      unrar x "$file"            ;;
            *.xz)       xz -d   "$file"            ;;
            *.zst)      zstd -d "$file"            ;;
            *) echo "extract: unknown format '$file'" >&2; failed=1 ;;
        esac
    done
    return $failed
}

############# port: show what is listening on a given port ##############
function port() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: port <number>"
        echo "  Show which process is listening on the given TCP/UDP port."
        echo "  Falls back to sudo if the port is not visible without elevated permissions."
        return
    fi
    if [[ $# -eq 0 ]]; then
        echo "Usage: port <number>  (use -h for details)" >&2
        return 1
    fi
    # Run lsof, suppress permission errors, deduplicate by PID (column 2)
    local out
    out=$(lsof -iTCP:"$1" -iUDP:"$1" -sTCP:LISTEN -P -n 2>/dev/null)
    if [[ -z "$out" ]]; then
        out=$(sudo lsof -iTCP:"$1" -iUDP:"$1" -sTCP:LISTEN -P -n 2>/dev/null)
    fi
    if [[ -z "$out" ]]; then
        echo "port: nothing listening on $1" >&2
        return 1
    fi
    # Print selected columns (COMMAND, PID, USER, TYPE, NAME), deduplicated by PID
    echo "$out" | awk 'NR==1 || !seen[$2]++' | awk '{printf "%-15s %-7s %-12s %-6s %s\n", $1, $2, $3, $5, $9}'
}

############# serve: quick HTTP server from current directory ##############
function serve() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: serve [port]"
        echo "  Start an HTTP server in the current directory."
        echo "  port — port to listen on (default: 8000)"
        return
    fi
    local port="${1:-8000}"
    echo "Serving $(pwd) on http://localhost:$port"
    python3 -m http.server "$port"
}

############# sizeof: human-readable size of files or directories ##############
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

############# epoch: convert between unix timestamps and human-readable dates ##############
function epoch() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: epoch [timestamp | date-string]"
        echo "  (no args)       — print current unix timestamp"
        echo "  epoch 1700000000 — convert unix timestamp to human-readable date"
        echo "  epoch 'yesterday' — convert date string to unix timestamp"
        return
    fi
    if [[ $# -eq 0 ]]; then
        date +%s
    elif [[ "$1" =~ '^[0-9]+$' ]]; then
        date -d "@$1"
    else
        date -d "$*" +%s
    fi
}

############# calc: evaluate a math expression ##############
function calc() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: calc <expression>"
        echo "  Evaluate a math expression. Supports Python math functions."
        echo "  Examples:"
        echo "    calc '2 ** 10'"
        echo "    calc 'sqrt(2)'"
        echo "    calc 'sin(pi / 4)'"
        return
    fi
    if [[ $# -eq 0 ]]; then
        echo "Usage: calc <expression>  (use -h for details)" >&2
        return 1
    fi
    python3 -c "from math import *; print($*)"
}

############# md2pdf: convert Markdown to PDF via pandoc ##############
function md2pdf() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: md2pdf <file.md> [file2.md ...]"
        echo "  Convert Markdown files to PDF using pandoc + xelatex."
        echo "  Output is placed alongside the source file (<name>.pdf)."
        echo ""
        echo "  Options:"
        echo "  MD2PDF_THEME=<name>  — pandoc highlight theme (default: zenburn)"
        return
    fi
    if [[ $# -eq 0 ]]; then
        echo "Usage: md2pdf <file.md> [file2.md ...]  (use -h for details)" >&2
        return 1
    fi

    local failed=0

    for src in "$@"; do
        if [[ "${src##*.}" != "md" ]]; then
            echo "Skipping '$src': not a .md file" >&2
            failed=1
            continue
        fi

        if [[ ! -f "$src" ]]; then
            echo "Skipping '$src': file not found" >&2
            failed=1
            continue
        fi

        local dst="${src%.md}.pdf"
        local theme="${MD2PDF_THEME:-zenburn}"

        echo "Converting '$src' → '$dst' ..."
        if pandoc "$src" \
            --output "$dst" \
            --pdf-engine=xelatex \
            --highlight-style="$theme" \
            -V mainfont="Latin Modern Roman" \
            -V sansfont="Latin Modern Sans" \
            -V monofont="JetBrains Mono" \
            -V monofontoptions="Scale=0.88" \
            -V geometry:margin=2cm \
            -V fontsize=11pt \
            -V linestretch=1.25 \
            -V colorlinks=true \
            -V linkcolor="NavyBlue" \
            -V urlcolor="NavyBlue"; then
            echo "  ✓ $dst"
        else
            echo "  ✗ Failed: $src" >&2
            failed=1
        fi
    done

    return $failed
}
