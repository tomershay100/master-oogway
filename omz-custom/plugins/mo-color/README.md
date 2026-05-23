# mo-color

Terminal color preview, palette, and text colorizer.

| Command | Description |
|---------|-------------|
| `color palette` | print all 16 named colors + all 256 xterm swatches |
| `color <c>` | print a background swatch and foreground label for color `<c>` |
| `color <fg>` | print piped text in `<fg>` foreground |
| `color <fg> <bg>` | print piped text with `<fg>` foreground on `<bg>` background; no pipe → prints `hello world` |

**Color formats:** `0xRRGGBB` · `#RRGGBB` · `0–255` (xterm index) · named (`black` `red` `green` `yellow` `blue` `magenta` `cyan` `white` `navy` `olive` `maroon` `lime` `fuchsia` `aqua` `silver` `gray`)

## Examples

```zsh
color palette
color 0xff0080
color navy
color 200
echo "danger" | color white red
color 0x00ff88 0x1a1a2e
```

**Dependencies:** a terminal with 24-bit (truecolor) support for accurate hex colors; xterm-256 named colors work in any 256-color terminal.
