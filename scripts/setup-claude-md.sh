#!/usr/bin/env bash
# setup-claude-md.sh — Install / refresh / uninstall the Crucible CLAUDE.md block.
# Modeled after omc-setup's setup-claude-md.sh. Marker-managed, idempotent, with backup.
#
# Usage:
#   setup-claude-md.sh <local|global> [overwrite|preserve]
#   setup-claude-md.sh <local|global> --uninstall
#
# Markers used for the managed block:
#   <!-- CRUCIBLE:START -->
#   ... body ...
#   <!-- CRUCIBLE:END -->

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
. "${SCRIPT_DIR}/lib/config-dir.sh"

MODE="${1:?Usage: setup-claude-md.sh <local|global> [overwrite|preserve|--uninstall]}"
ARG2="${2:-overwrite}"

START_MARKER="<!-- CRUCIBLE:START -->"
END_MARKER="<!-- CRUCIBLE:END -->"
SOURCE_FRAGMENT="${PLUGIN_ROOT}/docs/CRUCIBLE-CLAUDE-MD.md"

# Resolve target CLAUDE.md path.
case "$MODE" in
  local)
    PROJECT_ROOT="$(cd "$PWD" && pwd)"
    TARGET="${PROJECT_ROOT}/.claude/CLAUDE.md"
    mkdir -p "$(dirname "$TARGET")"
    ;;
  global)
    CONFIG_DIR="$(resolve_claude_config_dir)"
    if [ "$ARG2" = "preserve" ]; then
      TARGET="${CONFIG_DIR}/CLAUDE-crucible.md"
    else
      TARGET="${CONFIG_DIR}/CLAUDE.md"
    fi
    mkdir -p "$CONFIG_DIR"
    ;;
  *)
    echo "ERROR: MODE must be 'local' or 'global', got: $MODE" >&2
    exit 1
    ;;
esac

echo "Crucible setup-claude-md: target=$TARGET mode=$MODE"

# Backup existing file once per day.
if [ -f "$TARGET" ]; then
  BACKUP="${TARGET}.backup.$(date +%Y-%m-%d)"
  if [ ! -f "$BACKUP" ]; then
    cp "$TARGET" "$BACKUP"
    echo "  backup: $BACKUP"
  fi
fi

# Uninstall: strip the managed block, leave everything else intact.
if [ "$ARG2" = "--uninstall" ] || [ "${3:-}" = "--uninstall" ]; then
  if [ ! -f "$TARGET" ]; then
    echo "  no target file to uninstall from; nothing to do"
    exit 0
  fi
  if ! grep -qF "$START_MARKER" "$TARGET"; then
    echo "  no CRUCIBLE block found in target; nothing to do"
    exit 0
  fi
  TMP="$(mktemp)"
  awk -v s="$START_MARKER" -v e="$END_MARKER" '
    $0 ~ s {skip=1; next}
    $0 ~ e {skip=0; next}
    !skip {print}
  ' "$TARGET" > "$TMP"
  mv "$TMP" "$TARGET"
  echo "  uninstalled CRUCIBLE block from $TARGET"
  exit 0
fi

# Read canonical fragment.
if [ ! -f "$SOURCE_FRAGMENT" ]; then
  echo "ERROR: canonical fragment missing: $SOURCE_FRAGMENT" >&2
  exit 1
fi
FRAGMENT="$(cat "$SOURCE_FRAGMENT")"

# Strip any existing managed block, then append the new one.
TMP="$(mktemp)"
if [ -f "$TARGET" ] && grep -qF "$START_MARKER" "$TARGET"; then
  awk -v s="$START_MARKER" -v e="$END_MARKER" '
    $0 ~ s {skip=1; next}
    $0 ~ e {skip=0; next}
    !skip {print}
  ' "$TARGET" > "$TMP"
elif [ -f "$TARGET" ]; then
  cp "$TARGET" "$TMP"
else
  : > "$TMP"
fi

# Append fragment with leading blank line if file already has content.
if [ -s "$TMP" ]; then
  printf '\n' >> "$TMP"
fi
printf '%s\n' "$FRAGMENT" >> "$TMP"

mv "$TMP" "$TARGET"

# Validate markers landed.
if ! grep -qF "$START_MARKER" "$TARGET" || ! grep -qF "$END_MARKER" "$TARGET"; then
  echo "ERROR: marker validation failed after write at $TARGET" >&2
  exit 2
fi

echo "  installed CRUCIBLE block in $TARGET"
echo "  markers verified: $START_MARKER ... $END_MARKER"
