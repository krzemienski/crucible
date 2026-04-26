#!/usr/bin/env bash
# Crucible — PostToolUse hook (matcher: Write|Edit|Bash).
# Seals a post-task receipt for each completed step.
# Idempotent: re-running with the same input does not produce duplicate receipts.
#
# Reads: stdin JSON event payload with tool_name + tool_response.
# Writes: evidence/session-receipts/post-task-<timestamp>-<tool>.json
# Exit codes:
#   0 — receipt sealed (always; PostToolUse is non-blocking by Crucible policy)

set -uo pipefail

: "${CLAUDE_PLUGIN_ROOT:=$(cd "$(dirname "$0")/.." && pwd)}"
: "${CLAUDE_PROJECT_DIR:=$(pwd)}"
# Avoid evidence/evidence/ when subprocess cwd is already evidence/.
if [ "$(basename "$CLAUDE_PROJECT_DIR")" = "evidence" ]; then
  CLAUDE_PROJECT_DIR="$(dirname "$CLAUDE_PROJECT_DIR")"
fi

# === OPT-IN GATE (Layer 1) ===
if [ ! -f "${CLAUDE_PROJECT_DIR}/.crucible/active" ]; then
  exit 0
fi
# === ESCAPE HATCHES (Layer 2) ===
if [ -f "${CLAUDE_PROJECT_DIR}/.crucible/disabled" ]; then exit 0; fi
if [ "${CRUCIBLE_DISABLE:-0}" = "1" ]; then exit 0; fi
# === Secret redaction library (Gap 19, NFR-5/SEC-1) ===
# shellcheck source=lib/redact.sh
source "${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/bin/lib/redact.sh"


EVIDENCE="${CLAUDE_PROJECT_DIR}/evidence/session-receipts"
mkdir -p "$EVIDENCE" 2>/dev/null || true

INPUT=$(head -c 65536 || true)

TIMESTAMP=$(date -u +%Y%m%dT%H%M%S%NZ 2>/dev/null || date -u +%Y%m%dT%H%M%SZ)

TOOL_NAME=""
if command -v jq >/dev/null 2>&1; then
  TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
else
  TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | head -1 | cut -d'"' -f4)
fi
TOOL_NAME="${TOOL_NAME:-unknown}"

# Idempotency: derive a stable hash of the input + timestamp-second; skip if seen
HASH=$(printf "%s|%s|%s" "$TOOL_NAME" "$TIMESTAMP" "$INPUT" | shasum -a 256 2>/dev/null | cut -c1-12 || echo "${TIMESTAMP}${TOOL_NAME}")

RECEIPT="$EVIDENCE/post-task-${TIMESTAMP}-${TOOL_NAME}-${HASH}.json"

if [ -f "$RECEIPT" ]; then
  # Already sealed; idempotent skip
  exit 0
fi

cat > "$RECEIPT" <<EOF
{
  "event": "PostToolUse",
  "timestamp": "$TIMESTAMP",
  "tool_name": "$TOOL_NAME",
  "stdin_bytes": ${#INPUT},
  "hash": "$HASH",
  "sealed": true
}
EOF

exit 0
