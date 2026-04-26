---
name: remediate
description: Read REFUSAL.md, produce a delta plan targeting ONLY the failing MSCs/blockers, execute it, and prepare the next forge iteration. Used by /crucible:autopilot but also runnable standalone.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task, Skill
---

# /crucible:remediate

Reads the most recent `REFUSAL.md`, asks the planner for a *delta* plan that
targets only the failing MSCs/blockers (not a full re-plan), executes the delta,
and stops. The next `/crucible:forge` invocation will re-gate.

## Required inputs

- `REFUSAL.md` at project root (written by forge or completion-gate on refusal)
- `.crucible/active` (delegated to forge for the next iteration)

If `REFUSAL.md` is missing, refuse with:

```
REFUSED: no REFUSAL.md found. Nothing to remediate.
Run /crucible:forge first; if it succeeds, no remediation is needed.
```

## Pipeline

### Step 1 — Parse REFUSAL.md
Extract:
- Failing MSC list (e.g., `MSC-3`, `MSC-7`)
- Cited blocker paths (e.g., `evidence/validation-artifacts/<run>.md:42`)
- Failure cause (one-sentence per blocker)

### Step 2 — Delta planning
Invoke skill `crucible:planning` with mode=`delta` and the parsed blockers as
input. The planner subagent MUST produce a delta plan that:
- Targets ONLY the failing MSCs
- Reuses the original task's plan structure where possible
- Includes a fresh PASS/FAIL criterion per delta step
- Cites the original failing evidence paths

Required output: `evidence/oracle-plan-reviews/<run-id>/delta-plan.md`.

### Step 3 — Oracle delta-review
Invoke skill `crucible:oracle-review` in plan-review mode against the delta plan.
Single oracle (auditor-1) is sufficient at this phase since the original plan
already received quorum approval upstream.

If `BLOCK`: refuse remediation. The user must manually adjust the task or refusal.
If `APPROVE`: continue.

### Step 4 — Execute delta
Apply the delta plan's steps to the real system. Same execution discipline as
forge Phase 5: every step attributed, sealed via PostToolUse hook, no silent
retries.

### Step 5 — Stop here
Do NOT re-run validation, reviewer consensus, oracle quorum, or completion-gate.
Those are forge's job. Remediate's contract is: *"the cited blockers are now
addressed at the source-code level; let forge re-gate."*

## Output

```
CRUCIBLE REMEDIATE — DELTA APPLIED
==================================
Refusal:        REFUSAL.md
Failing MSCs:   <comma-separated list>
Delta plan:     evidence/oracle-plan-reviews/<run>/delta-plan.md
Delta review:   APPROVED by oracle-auditor-1
Delta executed: <N> steps applied
Next step:      Re-run /crucible:forge to re-gate.
```

## Why standalone matters

Even outside autopilot, remediate is useful when a human-in-the-loop reviews
REFUSAL.md and decides "yes, fix these without re-running the full plan." The
autopilot loop is one consumer; humans are another.

## What remediate does NOT do

- Does NOT modify REFUSAL.md (that's autopilot's responsibility, after the next forge run)
- Does NOT spawn reviewers or oracles (forge does that)
- Does NOT write `evidence/completion-gate/report.json` (only completion-gate does)
- Does NOT bypass any hook
