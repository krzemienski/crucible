---
name: forge
description: End-to-end Crucible pipeline. One command: codebase-analysis → docs-research → planning → oracle-plan-review → execute → validation → evidence-indexing → 3-reviewer consensus → 3-oracle quorum → completion-gate. Refuses on any cited blocker. The conductor that PRD §1.16.2 implied but never named.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task, Skill
---

# /crucible:forge

The single end-to-end pipeline. Inputs: a task description. Output: an
`evidence/completion-gate/report.json` with `overall=COMPLETE` (success) or
a structured `REFUSAL.md` (refusal). No silent retries. No mock substitutes.

## Required activation

Before forge runs, `.crucible/active` MUST exist. If not, refuse with:

```
REFUSED: Crucible is not active in this project.
Run /crucible:enable (or /crucible:setup) first.
```

## Pipeline (10 phases, fail-closed)

### Phase 1 — Codebase Analysis
Invoke skill `crucible:codebase-analysis`.
Required output: `evidence/codebase-analysis/<run-id>/SUMMARY.md` exists, non-empty.
Refuse forge if missing.

### Phase 2 — Documentation Research
Invoke skill `crucible:documentation-research` for every external dependency in scope.
Required output: `evidence/documentation-research/SUMMARY.md` with ≥3 cited facts per source.
Refuse forge if SUMMARY cites <3 facts or any source has only `(none)` placeholder.

### Phase 3 — Planning
Invoke skill `crucible:planning` (delegates to the `planner` subagent).
Required output: `evidence/oracle-plan-reviews/<run-id>/plan.md` with explicit MSCs and PASS/FAIL criteria per item.
Refuse forge if plan.md is empty or has no MSC list.

### Phase 4 — Oracle Plan Review
Invoke skill `crucible:oracle-review` in plan-review mode. The skill spawns
`oracle-auditor-1` via the Task tool with the plan as input.
Required output: `evidence/oracle-plan-reviews/<run-id>/oracle-1-verdict.md` with literal
keyword `APPROVE` or `BLOCK`. The verdict timestamp MUST precede any execution edit.

If `BLOCK`: write `REFUSAL.md` listing cited blockers from the verdict; stop.
If `APPROVE`: continue.

### Phase 5 — Execute
Execute every plan step. Each step:
- Attributed in evidence (which skill/subagent/hook produced it)
- Sealed via `bin/post-task.sh` PostToolUse hook → `evidence/session-receipts/`
- Cites the skill/agent/hook responsible

If a step's tool call fails, do NOT silently retry. Capture stderr verbatim under
`evidence/session-receipts/` and continue OR refuse per the plan's PASS/FAIL spec.

### Phase 6 — Validation
Invoke skill `crucible:validation` against the executed system.
Required output: `evidence/validation-artifacts/<run-id>.md` with per-item PASS/FAIL +
cited evidence paths.

### Phase 7 — Evidence Indexing
Invoke skill `crucible:evidence-indexing`.
Required output: every `evidence/<subdir>/INDEX.md` regenerated; root `evidence/INDEX.md` lists all subdirs.

### Phase 8 — Three-Reviewer Consensus
Spawn 3 reviewers IN PARALLEL via the Task tool with these subagent_types:
- `crucible:reviewer-a` (Completeness)
- `crucible:reviewer-b` (Integrity)
- `crucible:reviewer-c` (Iron-Rule Compliance)

Each reviewer writes to:
- `evidence/reviewer-consensus/reviewer-a.md`
- `evidence/reviewer-consensus/reviewer-b.md`
- `evidence/reviewer-consensus/reviewer-c.md`

After all three return, synthesize `evidence/reviewer-consensus/decision.md`
containing the literal string `UNANIMOUS PASS` (the gate searches for this exact
substring). If any reviewer FAILs, the decision is FAIL — do not write `UNANIMOUS PASS`.

If FAIL: write `REFUSAL.md` citing the failing reviewer paths; stop.

### Phase 9 — Three-Oracle Quorum
Spawn 3 oracles IN PARALLEL via the Task tool with these subagent_types:
- `crucible:oracle-auditor-1` (Completeness + Citation)
- `crucible:oracle-auditor-2` (Structural Integrity)
- `crucible:oracle-auditor-3` (Adversarial Skepticism)

Each oracle writes to:
- `evidence/final-oracle-evidence-audit/oracle-1.md`
- `evidence/final-oracle-evidence-audit/oracle-2.md`
- `evidence/final-oracle-evidence-audit/oracle-3.md`

Quorum rule: ≥2 APPROVE AND zero unresolved blockers. Critical blockers from any
oracle MUST be resolved before quorum is granted.

Synthesize `evidence/final-oracle-evidence-audit/decision.md` with literal keyword
`APPROVED` if quorum met. If any oracle filed an unresolved blocker, decision is
NOT APPROVED — file the blocker under `evidence/final-oracle-evidence-audit/blockers/`.

If NOT APPROVED: write `REFUSAL.md` citing the blocker paths; stop.

### Phase 10 — Completion Gate
Invoke skill `crucible:completion-gate`. The skill runs `gate.py` which:
1. Walks every MSC and verifies cited paths exist + are non-empty
2. Verifies `reviewer-consensus/decision.md` contains `UNANIMOUS PASS`
3. Verifies `final-oracle-evidence-audit/decision.md` contains `APPROVED`
4. Writes `evidence/completion-gate/report.json`

If `overall=COMPLETE`: report success and exit normally. The Stop hook will allow
session end.

If `overall=REFUSED`: gate.py wrote `REFUSAL.md` with the failing MSCs cited. Stop
hook will exit 2 and refuse session end.

## Output (success)

```
CRUCIBLE FORGE — COMPLETE
=========================
Task:        <task description>
Run ID:      <iso timestamp>
Plan:        evidence/oracle-plan-reviews/<run>/plan.md
Validation:  evidence/validation-artifacts/<run>.md
Reviewers:   3/3 PASS (UNANIMOUS)
Oracles:     ≥2/3 APPROVE (0 unresolved blockers)
Gate:        evidence/completion-gate/report.json (overall=COMPLETE)

Done. The Stop hook will allow session end.
```

## Output (refused)

```
CRUCIBLE FORGE — REFUSED
========================
Task:        <task description>
Run ID:      <iso timestamp>
Refused at:  Phase <N>
Reason:      <one-sentence summary>
Blockers:    evidence/<phase-specific-path>
Refusal:     REFUSAL.md (cites failing MSCs / blockers)

To remediate: read REFUSAL.md, fix the cited gaps, re-run /crucible:forge.
For an automated retry loop: /crucible:autopilot.
```

## Refusal modes (summary table)

| Phase | Refusal trigger |
|-------|-----------------|
| 0 | `.crucible/active` missing |
| 1 | codebase-analysis SUMMARY.md missing/empty |
| 2 | documentation-research has <3 facts per source |
| 3 | plan.md missing or has no MSC list |
| 4 | oracle plan-review BLOCK |
| 5 | execution step failed without proper plan-spec'd PASS/FAIL handling |
| 6 | validation artifact missing |
| 7 | evidence INDEX.md missing for any cited subdir |
| 8 | reviewer-consensus not UNANIMOUS PASS |
| 9 | oracle quorum <2 APPROVE OR unresolved blockers |
| 10 | gate.py exits non-zero (overall=REFUSED) |

## Iron Rule reminder

forge composes ONLY skills, agents, and hooks already in the plugin. It does not
invent new validation, does not silently retry past refusals, does not mock any
output. If a phase produces no artifact, the phase failed — refuse, do not
hallucinate evidence.

## Closes

Closes the implicit gap between PRD §1.16.2 commands (each one phase in
isolation) and PRD §1.13 (full Comprehensive Planning + Execution mode).
forge is the named conductor for that mode.
