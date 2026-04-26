---
name: resume
description: Resume a halted /crucible:forge or /crucible:autopilot run by inspecting the evidence tree and continuing from the first missing phase artifact. Evidence-tree-as-state — no separate state file required.
allowed-tools: Read, Bash, Glob, Grep, Task, Skill
---

# /crucible:resume

A forge or autopilot run can halt mid-pipeline (network blip, manual interrupt,
context overflow). Resume picks up where the last run left off by inspecting
the evidence tree itself — the evidence IS the state.

## Pipeline

### Step 1 — Identify the most recent run
Find the most recent run-id directory across:
- `evidence/oracle-plan-reviews/`
- `evidence/validation-artifacts/`
- `evidence/robust-trials/`

Use the latest mtime as the active run. Print:
```
Active run: <run-id> (started <iso timestamp>)
```

### Step 2 — Probe each forge phase artifact
Walk the 10 forge phases and check for the expected artifact:

| Phase | Artifact path | Expected content |
|-------|---------------|------------------|
| 1 | `evidence/codebase-analysis/<run>/SUMMARY.md` | non-empty |
| 2 | `evidence/documentation-research/SUMMARY.md` | non-empty |
| 3 | `evidence/oracle-plan-reviews/<run>/plan.md` | non-empty + has `MSC-` lines |
| 4 | `evidence/oracle-plan-reviews/<run>/oracle-1-verdict.md` | contains `APPROVE` or `BLOCK` |
| 5 | `evidence/session-receipts/` (latest) | recent receipts for this run |
| 6 | `evidence/validation-artifacts/<run>.md` | non-empty |
| 7 | `evidence/INDEX.md` | mtime ≥ Phase 6 artifact |
| 8 | `evidence/reviewer-consensus/decision.md` | contains `UNANIMOUS PASS` or FAIL |
| 9 | `evidence/final-oracle-evidence-audit/decision.md` | contains `APPROVED` or BLOCK |
| 10 | `evidence/completion-gate/report.json` | parses; has `overall` key |

### Step 3 — Determine first missing phase
The first phase whose expected artifact is missing or empty is the resume point.

### Step 4 — Continue forge from that phase
Invoke the forge pipeline starting at the resume phase. Skip earlier phases
(their artifacts are already valid). Continue through Phase 10.

If no phase is missing (all 10 artifacts present), check the gate report:
- `overall=COMPLETE`: report "already complete; nothing to resume." Stop.
- `overall=REFUSED`: invoke `/crucible:remediate`, then re-run forge from Phase 5.

## Output

```
CRUCIBLE RESUME
===============
Active run:       <run-id>
Phases complete:  1, 2, 3, 4
Resuming at:      Phase 5 (Execute)
Reason:           evidence/session-receipts/ has no entries newer than plan.md
```

After completion, output mirrors `/crucible:forge` (COMPLETE or REFUSED).

## Caveats

- Resume does NOT re-validate phases marked complete. Trust the evidence tree.
- If a phase's artifact is malformed (e.g., plan.md has no MSCs), resume treats
  it as missing and re-runs that phase.
- If multiple recent run-ids exist (overlapping forge attempts), the most-recent
  by mtime wins. Older runs are left untouched.
