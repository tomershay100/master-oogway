# Provides: calc, epoch, serve, md2pdf — developer utility functions.
# Requires: python3 for serve. bc for calc. pandoc + xelatex for md2pdf.

function calc() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: calc <expression>"
        echo "  Evaluate a math expression using bc -l."
        echo "  Examples:"
        echo "    calc '2 ^ 10'"
        echo "    calc 'sqrt(2)'"
        echo "    calc 's(3.14159/4)'   # sin"
        return
    fi
    if [[ $# -eq 0 ]]; then
        echo "Usage: calc <expression>  (use -h for details)" >&2
        return 1
    fi
    command -v bc &>/dev/null || { echo "calc: bc not installed" >&2; return 1; }
    local expr="$*"
    # Whitelist: digits, math operators, parens, bc function names (a-z_), spaces.
    # Blocks bc's system() and shell metacharacters.
    if [[ ! "$expr" =~ ^[0-9a-z_\ \+\-\*/\^\(\)\.\,\%]+$ ]]; then
        echo "calc: expression contains invalid characters" >&2
        return 1
    fi
    bc -l <<< "$expr"
}

function epoch() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: epoch [timestamp | date-string]"
        echo "  (no args)         — print current unix timestamp"
        echo "  epoch 1700000000  — convert unix timestamp to human-readable date"
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

function serve() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: serve [port]"
        echo "  Start an HTTP server in the current directory."
        echo "  port — port to listen on (default: 8000)"
        return
    fi
    command -v python3 &>/dev/null || { echo "serve: python3 not installed" >&2; return 1; }
    local port="${1:-8000}"
    echo "Serving $(pwd) on http://localhost:$port"
    python3 -m http.server "$port"
}

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
