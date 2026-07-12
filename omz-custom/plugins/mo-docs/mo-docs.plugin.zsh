
md2pdf() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
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
	command -v pandoc   &>/dev/null || { echo "md2pdf: pandoc not installed (try: sudo apt install pandoc)" >&2; return 1; }
	command -v xelatex  &>/dev/null || { echo "md2pdf: xelatex not installed (try: sudo apt install texlive-xetex)" >&2; return 1; }
	fc-list 'JetBrains Mono' 2>/dev/null | command grep -qi 'JetBrains' \
		|| echo "md2pdf: warning: JetBrains Mono font not found — output will use a fallback monospace font" >&2
	local failed=0 src
	for src in "$@"; do
		if [[ "${src##*.}" != (md|MD|markdown|MARKDOWN) ]]; then
			echo "Skipping '$src': not a .md file" >&2
			failed=1
			continue
		fi
		if [[ ! -f "$src" ]]; then
			echo "Skipping '$src': file not found" >&2
			failed=1
			continue
		fi
		local dst="${src%.*}.pdf"
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
