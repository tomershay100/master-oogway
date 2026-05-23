# Soft deps for mo-docs — read by install.sh, never sourced at runtime.
typeset -gA MO_OPTIONAL_DEPS=(
    [pandoc]="Markdown converter — required by md2pdf"
    [xelatex]="LaTeX PDF engine — required by md2pdf"
)
typeset -gA MO_OPTIONAL_APT=(
    [pandoc]="pandoc"
    [xelatex]="texlive-xetex"
)
