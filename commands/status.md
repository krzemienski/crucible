---
name: status
description: Report the current completion-gate state. Pretty-prints the MSC table, reviewer consensus, Oracle quorum, and overall verdict from evidence/completion-gate/report.json. Read-only. PRD §1.16.2 CMD-4.
allowed-tools: Read, Bash
---

# /crucible:status

Read-only status display per PRD §1.16.2 CMD-4. Sources of truth:
- `evidence/completion-gate/report.json`
- `evidence/reviewer-consensus/decision.md`
- `evidence/final-oracle-evidence-audit/decision.md`

## Output format (PRD §6.8 voice)

```
CRUCIBLE STATUS — <project-name>
================================
PRD VERSION    1.0.1
PLUGIN VERSION 0.2.0
GATE           overall=COMPLETE | REFUSED | (no gate run)

MSC LEDGER (21 criteria)
  PASS    21 / 21
  FAIL     0
  INSUFF.  0

REVIEWERS  3/3 PASS (UNANIMOUS)
ORACLES    2/3 APPROVE  (0 unresolved blockers)

LAST GATE RUN  2026-04-25T19:25:14Z
EVIDENCE TREE  31 INDEX.md files indexed
RECEIPTS       1,247 sealed
```

## Refusal modes

- `report.json` missing → "no gate run yet — run /crucible:completion-gate first"
- `report.json` malformed → display raw JSON with parse error and refuse to summarize
