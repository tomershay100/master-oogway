#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# gen_readme.sh - regenerate the additive plugins table in README.md
#
# Reads the first-line "# Provides:" comment from each mo-*.plugin.zsh and
# rewrites README.md between <!-- mo-plugins-start --> and <!-- mo-plugins-end -->.
# Run via: make readme
# ------------------------------------------------------------------------------
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
PLUGINS_DIR="${REPO_ROOT}/master-oogway-omz-custom/plugins"
README="${REPO_ROOT}/README.md"

# ── Build table lines ──────────────────────────────────────────────────────────

lines=()
lines+=("| Plugin | Provides |")
lines+=("|--------|---------|")

for plugin_file in "${PLUGINS_DIR}"/mo-*/mo-*.plugin.zsh; do
    plugin_name=$(basename "$(dirname "$plugin_file")")
    # Override plugins have their own table in README — skip them here
    [[ "$plugin_name" == *-override ]] && continue
    provides=$(head -1 "$plugin_file")
    [[ "$provides" == "# Provides: "* ]] || continue
    description="${provides#\# Provides: }"
    description="${description%.}"
    lines+=("| \`${plugin_name}\` | ${description} |")
done

# ── Splice into README ─────────────────────────────────────────────────────────

start_marker="<!-- mo-plugins-start -->"
end_marker="<!-- mo-plugins-end -->"

if ! grep -qF "$start_marker" "$README"; then
    echo "error: sentinel '${start_marker}' not found in ${README}" >&2
    exit 1
fi

# Build replacement block
block="${start_marker}"$'\n'
for line in "${lines[@]}"; do
    block+="${line}"$'\n'
done
block+="${end_marker}"

# Replace between sentinels (inclusive) using awk
awk -v block="$block" \
    -v start="$start_marker" \
    -v end="$end_marker" \
    'BEGIN { inside=0 }
     $0 == start { print block; inside=1; next }
     $0 == end   { inside=0; next }
     !inside     { print }' \
    "$README" > "${README}.tmp" && mv "${README}.tmp" "$README"

echo "README.md plugin table updated ($(( ${#lines[@]} - 2 )) plugins)."
