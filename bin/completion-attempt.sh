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
# Sanity: if CLAUDE_PROJECT_DIR resolves to an evidence/ subdir (e.g., subprocess
# launched with cwd=evidence/), walk up so we don't create evidence/evidence/.
if [ "$(basename "$CLAUDE_PROJECT_DIR")" = "evidence" ]; then
  CLAUDE_PROJECT_DIR="$(dirname "$CLAUDE_PROJECT_DIR")"
fi

# === OPT-IN GATE (Layer 1) ===
# Crucible only enforces in projects with ${CLAUDE_PROJECT_DIR}/.crucible/active.
# Without the sentinel, this hook is a silent no-op so user-scope installs do not
# break unrelated projects. To opt in: /crucible:enable (or `mkdir -p .crucible && touch .crucible/active`).
if [ ! -f "${CLAUDE_PROJECT_DIR}/.crucible/active" ]; then
  exit 0
fi

# === ESCAPE HATCHES (Layer 2) ===
# Kill switch: .crucible/disabled overrides .crucible/active.
if [ -f "${CLAUDE_PROJECT_DIR}/.crucible/disabled" ]; then
  exit 0
fi
# Per-shell escape via env var (does not persist across sessions).
if [ "${CRUCIBLE_DISABLE:-0}" = "1" ]; then
  exit 0
fi

# === FAIL-OPEN ON CONTRADICTORY STATE (Layer 3) ===
# If opted in but evidence/completion-gate/ was never created, the user opted in
# and abandoned the workflow. Don't trap them — warn and allow.
if [ ! -d "${CLAUDE_PROJECT_DIR}/evidence/completion-gate" ]; then
  echo "Crucible: .crucible/active exists but evidence/completion-gate/ does not." >&2
  echo "Crucible: assuming abandoned workflow — allowing Stop. To re-enable enforcement," >&2
  echo "Crucible:   /crucible:completion-gate    OR    rm .crucible/active to opt out entirely." >&2
  exit 0
fi

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

# REFUSED — surface the specific reason + ALL escape hatches via stderr, exit 2 to block
echo "REFUSED by Crucible completion-attempt hook." >&2
echo "Reason: $REASON" >&2
echo "" >&2
echo "If you ARE running a Crucible workflow, fix the gate:" >&2
echo "  • /crucible:completion-gate     — evaluate and produce a passing report.json" >&2
echo "  • Address each MSC's REFUSAL.md citation, then re-run the gate" >&2
echo "" >&2
echo "If you are NOT running a Crucible workflow, opt out of enforcement:" >&2
echo "  • /crucible:disable              — slash command (recommended)" >&2
echo "  • rm ${CLAUDE_PROJECT_DIR}/.crucible/active   — manual: deactivate this project" >&2
echo "  • touch ${CLAUDE_PROJECT_DIR}/.crucible/disabled  — kill switch (overrides active)" >&2
echo "  • CRUCIBLE_DISABLE=1 claude      — disable for one shell session only" >&2
echo "" >&2
echo "There is NO --force flag for the gate itself (refusal is a feature). But the opt-out" >&2
echo "above is explicit and reversible — Crucible only enforces where you've activated it." >&2
exit 2
