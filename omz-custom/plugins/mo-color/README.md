# mo-color

Terminal color preview, palette, and text colorizer.

| Command | Description |
|---------|-------------|
| `color palette` | print all 16 named colors + all 256 xterm swatches |
| `color pick` | interactive 16×16 swatch picker; prints `idx\t#hex\tname` on Enter, exits 130 on cancel |
| `color <c>` | print a background swatch and foreground label for color `<c>` |
| `color <fg>` | stream piped text in `<fg>` foreground |
| `color <fg> <bg>` | stream piped text with `<fg>` foreground on `<bg>` background; no pipe → prints `hello world` |

### `color pick` keys

`←→↑↓` move by 1 · `PgUp/PgDn` ±16 (whole row) · `Home/g` jump to 0 · `End/G` jump to 255 ·
digits then `Enter` jump to that index (e.g. `200⏎`) · `Enter` confirm · `q` / `Esc` cancel.

Output is tab-separated so you can pipe it:

```zsh
read -r idx hex name < <(color pick) || return
echo "picked #$idx — $hex (${name})"
```

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

**Dependencies:** 24-bit truecolor terminal for accurate hex colors (`COLORTERM=truecolor`); gracefully falls back to 256-color ANSI codes in non-truecolor terminals — named colors and the palette display still work.
