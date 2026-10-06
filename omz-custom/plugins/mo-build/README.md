# mo-build

Parallel make wrapper. Accepts all standard make arguments (`m -C dir`, `m all`, etc.).

| Command | Description |
|---------|-------------|
| `m [args]` | build using all CPU cores; colored output if `colormake` installed; prints colored `PASSED ✓` / `FAILED ✗` summary |
| `mc` | `make clean` |
| `mca` | `make clean` then build all — `mc && m all` |

**Dependencies:** `make` (required). `colormake` optional — used for colored compiler output when present.
