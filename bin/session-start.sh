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

# === SDK-invocation tagger (HK-4, PRD §1.16.4) ===
# Detect SDK-originated sessions and tag the receipt with origin=sdk|cli.
# Signal sources, in priority order:
#   1. CLAUDE_SESSION_ENTRYPOINT env var (canonical signal)
#   2. CLAUDE_AGENT_SDK_VERSION env var (presence == SDK origin)
#   3. JSON stdin "entrypoint" field (sdk-py, sdk-ts, etc. → SDK origin)
#   4. Fallback: cli
ORIGIN="cli"
if [ -n "${CLAUDE_SESSION_ENTRYPOINT:-}" ]; then
  case "$CLAUDE_SESSION_ENTRYPOINT" in
    sdk*|*-sdk) ORIGIN="sdk" ;;
  esac
elif [ -n "${CLAUDE_AGENT_SDK_VERSION:-}" ]; then
  ORIGIN="sdk"
elif echo "$INPUT" | grep -qE '"entrypoint"[[:space:]]*:[[:space:]]*"sdk[^"]*"'; then
  ORIGIN="sdk"
fi

cat > "$RECEIPT" <<EOF
{
  "event": "SessionStart",
  "timestamp": "$TIMESTAMP",
  "plugin_root": "$CLAUDE_PLUGIN_ROOT",
  "project_dir": "$CLAUDE_PROJECT_DIR",
  "origin": "$ORIGIN",
  "stdin_bytes": ${#INPUT}
}
EOF

exit 0
