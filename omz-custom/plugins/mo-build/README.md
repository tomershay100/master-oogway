# mo-build

Parallel make wrapper. Accepts all make arguments (`m -C dir`, `m all`, etc.).

**Dependencies:** `make` (required). `colormake` and `banner` are optional and independent — each is used when available.

| Command | Description |
|---------|-------------|
| `m [args]` | build using all CPU cores; colored output if `colormake` installed; PASSED/FAILED banner if `banner` installed |
| `mc` | `make clean` |
