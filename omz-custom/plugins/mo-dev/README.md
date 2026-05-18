# mo-dev

Developer utility functions.

| Command | Description |
|---------|-------------|
| `calc <expr>` | evaluate a math expression via `bc -l` (supports `sqrt`, `s`, `c`, `l`, `e`) |
| `epoch [ts]` | convert unix timestamp ↔ human date; no arg = current timestamp |
| `serve [port]` | start a local HTTP file server (default port 8000) |
| `md2pdf <file>` | convert Markdown to PDF via pandoc + xelatex |

**Dependencies:** `bc` (calc), `python3` (serve), `pandoc` + `xelatex` (md2pdf) — each checked at call time.
