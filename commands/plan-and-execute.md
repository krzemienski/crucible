---
name: plan-and-execute
description: Run Crucible's Comprehensive Planning + Execution mode. Builds a plan via the planner subagent, submits it for Oracle plan-review, executes only after approval, and seals every step into evidence/. PRD §1.16.2 CMD-1.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task, Skill
---

# /crucible:plan-and-execute

Invokes Crucible's planning workflow per PRD §1.13.1 (FR-PLAN-1 through FR-PLAN-8).

## Pipeline

1. Run skill `crucible:codebase-analysis` → builds repo-wide context
2. Run skill `crucible:documentation-research` → fetches + cites current upstream docs
3. Run skill `crucible:planning` → produces executable plan with PASS/FAIL criteria per item
4. Run skill `crucible:oracle-review` in plan-review mode → APPROVE or BLOCK
5. If APPROVED: execute plan; every step is attributed to a skill/subagent/hook and sealed by `bin/post-task.sh`
6. If BLOCKED: refuse with cited blockers; remediate and re-submit

## Required activation

Run `/crucible:enable` in the project first (creates `.crucible/active`).

## Output

- Plan: `evidence/oracle-plan-reviews/<trial-id>/plan.md`
- Oracle verdict: `evidence/oracle-plan-reviews/<trial-id>/verdict.md` (timestamp must precede execution)
- Execution receipts: `evidence/session-receipts/`
- Per-trial evidence: `evidence/robust-trials/trial-<NN>/`

## Refusal modes

- Plan submitted without codebase-analysis evidence → REFUSED
- Plan submitted without documentation-research citations → REFUSED
- Execution attempted before Oracle approval timestamp → REFUSED
