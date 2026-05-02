#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# check_schema.sh - Verify dragon entry point sources schema.zsh for its defaults
# ------------------------------------------------------------------------------
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEME="${REPO_ROOT}/zsh-custom.d/themes/dragon.zsh-theme"
SCHEMA="${REPO_ROOT}/zsh-custom.d/themes/schema.zsh"

# Verify theme sources schema rather than duplicating defaults inline.
if ! grep -q 'source.*schema\.zsh' "$THEME"; then
    echo "ERROR: dragon.zsh-theme does not source schema.zsh" >&2
    exit 1
fi

# Verify schema defines _DRAGON_DEFAULTS.
if ! grep -q '_DRAGON_DEFAULTS' "$SCHEMA"; then
    echo "ERROR: schema.zsh does not define _DRAGON_DEFAULTS" >&2
    exit 1
fi

var_count=$(grep -oP '(?<=\[)([A-Z_]+)(?=\])' "$SCHEMA" | sort -u | wc -l | tr -d ' ')
echo "ok: schema has ${var_count} variables; dragon.zsh-theme sources schema.zsh"
