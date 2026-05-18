# Requires: make. colormake and banner are optional — falls back to plain make.

if command -v colormake &>/dev/null && command -v banner &>/dev/null; then
    alias m="colormake -j\$(( \$(nproc) > 0 ? \$(nproc) : 1 )) && banner PASSED || (banner FAILED; false)"
else
    alias m="make -j\$(( \$(nproc) > 0 ? \$(nproc) : 1 ))"
fi
alias mc="make clean"
