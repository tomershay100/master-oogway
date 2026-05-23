# mo-color

Color preview and palette tool.

| Command | Description |
|---------|-------------|
| `color palette` | print all 16 named colors + all 256 xterm swatches (BG swatch + FG label each) |
| `color <c>` | print `<c>` as a BG swatch and a FG label |
| `color <fg>` | print piped text in `<fg>` foreground |
| `color <fg> <bg>` | print piped text with `<fg>` foreground on `<bg>` background; no pipe → prints `hello world` |

**Color formats:** `0xRRGGBB` · `#RRGGBB` · `0–255` (xterm index) · named (`black` `navy` `fuchsia` `aqua` `silver` `maroon` `lime` `olive` `gray` `red` `green` `yellow` `blue` `magenta` `cyan` `white`)

**Examples:**

```zsh
color palette
color 0xff0080
color navy
color 200
color 0xff0080 0xf0f0f0
echo "danger" | color white red
color 0x00ff88 0x1a1a2e
```

**Dependencies:** a terminal with 24-bit (truecolor) support for accurate hex colors; xterm-256 named colors work in any 256-color terminal.
