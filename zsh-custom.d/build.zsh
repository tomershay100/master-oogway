# Provides: m (parallel make with optional colormake+banner) and mc (make clean).
# Requires: make. colormake and banner are optional — falls back to plain make.

if command -v colormake &>/dev/null && command -v banner &>/dev/null; then
    alias m="colormake -j\$(nproc) && banner PASSED || (banner FAILED; false)"
else
    alias m="make -j\$(nproc)"
fi
alias mc="make clean"
