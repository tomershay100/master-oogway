# mo-serial

Serial console wrapper. `min <device>` opens minicom on `/dev/<device>` with color enabled — bare device name, no `/dev/` prefix. Tab completion lists `/dev/ttyUSB*`/`/dev/ttyACM*` on Linux and `/dev/cu.*`/`/dev/tty.usb*` on macOS.

| Command | Description |
|---------|-------------|
| `min <device> [args...]` | `minicom -D /dev/<device> -c on [args...]` — extra args pass through to minicom |

**Dependencies:** `minicom` (required).
