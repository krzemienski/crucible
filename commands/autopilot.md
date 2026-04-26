---
name: autopilot
description: /crucible:forge in a refusal-driven retry loop. Runs forge; on REFUSED, parses REFUSAL.md, invokes /crucible:remediate, re-gates. Stops on COMPLETE or after --max-attempts (default 3). Iron Rule preserved at every iteration.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task, Skill
---

# /crucible:autopilot

Forge in a loop. The user supplies a task; autopilot iterates forge → refusal-detect →
remediate → forge until either the gate returns `overall=COMPLETE` or the attempt
budget is exhausted.

## Usage

```
/crucible:autopilot <task description> [--max-attempts N]
```

- `--max-attempts N` — default `3`. Caps the number of forge iterations.
- `--max-attempts 1` — equivalent to a bare `/crucible:forge` (no remediation).

## Required activation

`.crucible/active` must exist (delegated to forge's Phase 0 check).

## Pipeline

### Iteration 0..N-1

For each iteration `i` in `0..N-1`:

1. **Run forge.** Invoke `/crucible:forge` with the task.
2. **Read gate report.** Open `evidence/completion-gate/report.json`.
   - If `overall=COMPLETE`: success. Stop the loop. Report iteration count.
   - If `overall=REFUSED`: continue to step 3.
   - If file missing: forge crashed before gate. Treat as REFUSED with cause "gate
     report not produced". Continue.
3. **Read REFUSAL.md.** Parse the cited blockers. Each blocker has a path and a
   short cause description.
4. **Check attempt budget.** If `i+1 >= max_attempts`: stop the loop, report final
   refusal with attempt count.
5. **Invoke remediate.** Call `/crucible:remediate` with the cited blockers. The
   remediate skill produces a delta plan and applies fixes to the real system.
6. **Loop.** Increment `i`. Re-run forge.

### Iron Rule across iterations

Each iteration is a FULL forge run — full plan, full oracle plan-review, full
reviewer consensus, full oracle quorum. There is no shortcut where remediate's
output is trusted without re-gating. **Refusal exists for a reason. Each
iteration must earn its own COMPLETE verdict.**

## Output (success)

```
CRUCIBLE AUTOPILOT — COMPLETE
=============================
Task:           <task>
Iterations:     M of N (M ≤ max-attempts)
Final verdict:  evidence/completion-gate/report.json (overall=COMPLETE)
Remediations:   M-1 (each captured under evidence/robust-trials/trial-NN/)
```

## Output (exhausted)

```
CRUCIBLE AUTOPILOT — EXHAUSTED
==============================
Task:           <task>
Iterations:     N of N (max attempts hit)
Last verdict:   evidence/completion-gate/report.json (overall=REFUSED)
Last refusal:   REFUSAL.md
Cited blockers: <list of evidence paths>

The autopilot loop did NOT silently succeed. Manual intervention required.
Read REFUSAL.md, address the cited blockers, then re-run /crucible:autopilot
or /crucible:forge.
```

## What autopilot does NOT do

- Does NOT raise the `--max-attempts` cap automatically. Refusal is a feature.
- Does NOT mock evidence to satisfy a stubborn blocker.
- Does NOT skip phases of forge between iterations. Every iteration is full.
- Does NOT modify `.crucible/active` to bypass hooks.

## Closes

Closes the gap that PRD §1.13 describes (Comprehensive Planning + Execution
mode) without prescribing a retry loop. Crucible's design says refusal is a
feature; autopilot makes refusal *productive* by feeding it back as a
remediation signal — without ever bypassing the gate.
