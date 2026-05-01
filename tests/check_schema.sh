#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# check_schema.sh - Verify schema.zsh and appa-fino.zsh define the same vars
# ------------------------------------------------------------------------------
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEME="${REPO_ROOT}/zsh-custom.d/themes/appa-fino.zsh"
SCHEMA="${REPO_ROOT}/zsh-custom.d/themes/schema.zsh"

# Extract APPA_FINO__* names from set_if_unset calls in the theme (skip the
# function definition line itself and the nerd-font conditional duplicate).
theme_vars=$(grep -oP '(?<=set_if_unset )(APPA_FINO__\S+)' "$THEME" | sort -u)

# Extract keys from _AF_DEFAULTS associative array in schema.zsh.
schema_vars=$(grep -oP '(?<=\[)([A-Z_]+)(?=\])' "$SCHEMA" \
    | sed 's/^/APPA_FINO__/' | sort -u)

diff_output=$(diff \
    <(echo "$theme_vars") \
    <(echo "$schema_vars") || true)

if [[ -z "$diff_output" ]]; then
    echo "ok: schema and theme are in sync ($(echo "$theme_vars" | wc -l | tr -d ' ') variables)"
    exit 0
fi

echo "ERROR: schema/theme drift detected" >&2
echo "" >&2
echo "Lines prefixed with '<' are in the theme but missing from schema." >&2
echo "Lines prefixed with '>' are in schema but missing from the theme." >&2
echo "" >&2
echo "$diff_output" >&2
exit 1
