#!/usr/bin/env bash
# Crucible — Stop hook (completion-attempt enforcement).
# THE GATE. When the agent attempts to stop, this hook decides whether the
# completion claim is permitted by checking that completion-gate/report.json
# exists AND has overall=COMPLETE. Otherwise: exit 2 to block.
#
# Reads: stdin JSON event payload (Stop event).
# Writes: evidence/session-receipts/completion-attempt-<timestamp>.json
# Exit codes:
#   0 — completion permitted (report.json exists and overall=COMPLETE)
#   2 — completion REFUSED (report.json missing OR overall != COMPLETE OR any MSC failing)

set -uo pipefail

: "${CLAUDE_PLUGIN_ROOT:=$(cd "$(dirname "$0")/.." && pwd)}"
: "${CLAUDE_PROJECT_DIR:=$(pwd)}"

EVIDENCE_ROOT="${CLAUDE_PROJECT_DIR}/evidence"
RECEIPTS="${EVIDENCE_ROOT}/session-receipts"
mkdir -p "$RECEIPTS" 2>/dev/null || true

INPUT=$(head -c 65536 || true)
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
RECEIPT="$RECEIPTS/completion-attempt-${TIMESTAMP}.json"

REPORT="${EVIDENCE_ROOT}/completion-gate/report.json"

# Default: REFUSED unless we can prove COMPLETE
DECISION="REFUSED"
REASON="default-refusal-no-gate-evaluation"

# === Explicit exit-2 branch tied to missing-evidence detection ===
if [ ! -f "$REPORT" ]; then
  DECISION="REFUSED"
  REASON="completion-gate/report.json does not exist; gate has not been evaluated"
elif [ ! -s "$REPORT" ]; then
  DECISION="REFUSED"
  REASON="completion-gate/report.json is empty"
else
  # Parse the gate verdict
  if command -v jq >/dev/null 2>&1; then
    OVERALL=$(jq -r '.overall // "REFUSED"' "$REPORT" 2>/dev/null || echo "REFUSED")
  else
    OVERALL=$(grep -o '"overall":"[^"]*"' "$REPORT" | head -1 | cut -d'"' -f4)
    OVERALL="${OVERALL:-REFUSED}"
  fi

  if [ "$OVERALL" = "COMPLETE" ]; then
    DECISION="ALLOW"
    REASON="completion-gate/report.json shows overall=COMPLETE"
  else
    DECISION="REFUSED"
    REASON="completion-gate/report.json shows overall=${OVERALL} (must be COMPLETE)"
  fi
fi

# Always write the receipt (whether allow or refuse)
cat > "$RECEIPT" <<EOF
{
  "event": "Stop",
  "timestamp": "$TIMESTAMP",
  "decision": "$DECISION",
  "reason": "$REASON",
  "report_path": "$REPORT",
  "report_exists": $([ -f "$REPORT" ] && echo "true" || echo "false")
}
EOF

if [ "$DECISION" = "ALLOW" ]; then
  exit 0
fi

# REFUSED — surface the specific reason to Claude via stderr, exit 2 to block
echo "REFUSED by Crucible completion-attempt hook." >&2
echo "Reason: $REASON" >&2
echo "" >&2
echo "Crucible exists to refuse completion claims that lack evidence." >&2
echo "Run /crucible:completion-gate to evaluate and produce report.json." >&2
echo "If gate produces overall=REFUSED, fix the cited gaps and re-run." >&2
echo "There is NO override flag. NO force-complete. Refusal is a feature." >&2
exit 2
