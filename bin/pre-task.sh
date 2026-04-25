#!/usr/bin/env bash
# Crucible — PreToolUse hook (matcher: Write|Edit|Bash).
# Records task intent and detects mock-pattern violations BEFORE the tool runs.
#
# Reads: stdin JSON event payload with tool_name + tool_input.
# Writes: evidence/session-receipts/pre-task-<timestamp>-<tool>.json
# Exit codes:
#   0 — task intent recorded; allow tool to proceed
#   2 — mock-pattern detected in tool input; block tool + surface stderr to Claude

set -uo pipefail

: "${CLAUDE_PLUGIN_ROOT:=$(cd "$(dirname "$0")/.." && pwd)}"
: "${CLAUDE_PROJECT_DIR:=$(pwd)}"

EVIDENCE="${CLAUDE_PROJECT_DIR}/evidence/session-receipts"
mkdir -p "$EVIDENCE" 2>/dev/null || true

# Read all stdin (with cap — never read indefinitely)
INPUT=$(head -c 65536 || true)

TIMESTAMP=$(date -u +%Y%m%dT%H%M%S%NZ 2>/dev/null || date -u +%Y%m%dT%H%M%SZ)

# Extract tool_name from JSON without requiring jq (fallback if jq unavailable)
TOOL_NAME=""
if command -v jq >/dev/null 2>&1; then
  TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
else
  TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | head -1 | cut -d'"' -f4)
fi
TOOL_NAME="${TOOL_NAME:-unknown}"

RECEIPT="$EVIDENCE/pre-task-${TIMESTAMP}-${TOOL_NAME}.json"

# Mock-pattern detection (per build-prompt §2 Mock Detection Protocol)
# Only flag for Write/Edit on test-file paths or mock-library imports
VIOLATION=""
if [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ]; then
  # Check file_path field for test-file patterns
  FILE_PATH=""
  if command -v jq >/dev/null 2>&1; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
  fi
  case "$FILE_PATH" in
    *.test.*|*_test.*|*Tests.*|*/tests/*|*/__tests__/*|*/spec/*)
      VIOLATION="test-file-creation: $FILE_PATH"
      ;;
  esac
fi

# Always write receipt (block or pass)
cat > "$RECEIPT" <<EOF
{
  "event": "PreToolUse",
  "timestamp": "$TIMESTAMP",
  "tool_name": "$TOOL_NAME",
  "stdin_bytes": ${#INPUT},
  "violation": "$VIOLATION"
}
EOF

if [ -n "$VIOLATION" ]; then
  echo "BLOCKED by Crucible pre-task hook: $VIOLATION" >&2
  echo "Iron Rule: no test files. Validate against the real system instead. See plugin skills/validation/SKILL.md." >&2
  exit 2
fi

exit 0
