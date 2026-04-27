# Phase 4 — Welcome

Setup is complete. Print the welcome banner and persist the per-user sentinel.

## Persist the sentinel

```bash
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_DIR/.crucible-config.json" <<JSON
{
  "setupCompleted": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "setupVersion": "0.2.0",
  "target": "$TARGET"
}
JSON
```

## Clear progress state

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-progress.sh" clear
```

## Welcome banner

```
═══════════════════════════════════════════════════════════
  CRUCIBLE READY — Evidence-gated execution active
═══════════════════════════════════════════════════════════

What survives the test, ships.

Next steps:
  /crucible:forge <task>    End-to-end pipeline (most common)
  /crucible:autopilot       Forge in a refusal-driven loop
  /crucible:status          Current gate state
  /crucible:doctor          Re-run health checks anytime
  /crucible:explain         Show which skills/agents/hooks fire

Iron Rule: validation runs against real systems only.
No mocks. No stubs. No silent retries past the gate.

To deactivate later: /crucible:disable
Kill switch:         touch .crucible/disabled
Per-shell escape:    CRUCIBLE_DISABLE=1 claude
```

Stop here. The session continues normally.
