#!/usr/bin/env bash
# Crucible — SessionStart hook.
# Initializes plugin context and seals a session-receipt to evidence/.
#
# Per cc-hooks docs: ${CLAUDE_PLUGIN_ROOT} may be unset during SessionStart.
# This script handles that with a script-dir fallback.
#
# Reads: stdin JSON event payload (per cc-hooks).
# Writes: evidence/session-receipts/session-start-<timestamp>.json
# Exit codes:
#   0 — receipt sealed
#   2 — invariant violation (currently never; SessionStart is non-blocking)

set -euo pipefail

# Fallback for unset CLAUDE_PLUGIN_ROOT (per documented hook behavior at SessionStart)
: "${CLAUDE_PLUGIN_ROOT:=$(cd "$(dirname "$0")/.." && pwd)}"
: "${CLAUDE_PROJECT_DIR:=$(pwd)}"

EVIDENCE="${CLAUDE_PROJECT_DIR}/evidence/session-receipts"
mkdir -p "$EVIDENCE" 2>/dev/null || true

# Read stdin JSON event (capped at 64KB — never block the session)
# Use head -c rather than `read -t 0.1` since fractional read timeouts are
# not portable across bash versions (notably bash 3.x on macOS).
INPUT=$(head -c 65536 2>/dev/null || true)

TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
RECEIPT="$EVIDENCE/session-start-${TIMESTAMP}.json"

# Idempotent — if a receipt for this exact second already exists, skip
if [ -f "$RECEIPT" ]; then
  exit 0
fi

cat > "$RECEIPT" <<EOF
{
  "event": "SessionStart",
  "timestamp": "$TIMESTAMP",
  "plugin_root": "$CLAUDE_PLUGIN_ROOT",
  "project_dir": "$CLAUDE_PROJECT_DIR",
  "stdin_bytes": ${#INPUT}
}
EOF

exit 0
