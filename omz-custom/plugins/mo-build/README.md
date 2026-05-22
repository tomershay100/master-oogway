# mo-build

Parallel make aliases.

**Dependencies:** `make` (required). `colormake` + `banner` are optional — falls back to plain `make` if absent.

| Command | Description |
|---------|-------------|
| `m` | `make -j$(nproc)` — build using all CPU cores |
| `mc` | `make clean` |
