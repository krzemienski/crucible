---
name: planning
description: Build the executable plan for a Crucible comprehensive planning task. Use this skill whenever the user invokes /crucible:planning, asks to plan a feature/refactor/migration, or requires Oracle-pre-approved execution. Builds on codebase-analysis and documentation-research outputs. Attributes every step to a skill, subagent, or hook. Submits the plan to Oracle plan-review BEFORE execution per FR-PLAN-5/6. Refuses to start execution without approval. Produces evidence/oracle-plan-reviews/ and evidence/robust-trials/trial-NN/ structured artifacts.
---

# Planning

## Scope

This skill handles comprehensive planning + execution mode (PRD §1.13.1).

Does NOT handle: validation-only mode (use `validation` skill), reviewer/Oracle dispatch (use `oracle-review`), or evidence sealing (handled by post-task hook).

## Security

- Refuse to execute any plan step before Oracle plan-review approval.
- Refuse to declare a plan complete without per-step evidence.
- If the plan would touch files outside `$TARGET_REPO`, refuse and request scope clarification.
- Never embed credentials in plan steps; reference env vars by name.

## Workflow

1. Read the user task brief.
2. Invoke `codebase-analysis` skill — wait for evidence/codebase-analysis/INDEX.md.
3. Invoke `documentation-research` skill — wait for evidence/documentation-research/SUMMARY.md.
3.5. Invoke `skill-enrichment` skill — wait for evidence/skill-enrichment/<run-id>/INDEX.md (5–10 ranked candidate skills). If skill-enrichment refuses (REFUSAL.md present), the planner MUST also refuse — orthogonal-domain prompts cannot be planned with skill attribution. This implements PRD §1.13.1 FR-PLAN-3.
4. Build the executable plan with: ordered steps, per-step skill/subagent/hook attribution (drawn from the skill-enrichment INDEX.md), per-step PASS/FAIL criteria, per-step evidence path. The plan MUST include a top-level **`## Required Skills`** section listing each candidate from skill-enrichment INDEX.md.
5. Submit plan to Oracle plan-review (`oracle-review` skill in plan-review mode). Capture verdict to `evidence/oracle-plan-reviews/`.
6. If REJECTED: refuse to execute, surface blockers to user, await revision.
7. If APPROVED: execute steps in order. Each step writes evidence to `evidence/robust-trials/trial-NN/`.
8. After all steps complete, hand off to `validation` skill for non-mutating verification.

## Produced artifacts

- `evidence/robust-trials/trial-NN/BRIEF.md` — task brief
- `evidence/robust-trials/trial-NN/MODE.txt` — `planning`
- `evidence/robust-trials/trial-NN/INVOCATION.txt` — exact command
- `evidence/robust-trials/trial-NN/PLAN.md` — the executable plan with attributions
- `evidence/robust-trials/trial-NN/transcript.jsonl` — execution trace (copied from session log)
- `evidence/robust-trials/trial-NN/OUTCOME.md` — what was produced and where
- `evidence/oracle-plan-reviews/trial-NN-verdict.md` — Oracle approval (timestamp BEFORE execution)

## Forbidden actions

- Executing any plan step before Oracle plan-review approval.
- Mocking, fabricating, or fixturizing during execution.
- Self-reviewing the executor's own output (reviewers and Oracles handle that, not the executor).
- Silent retry past a failed step (each retry creates a new step under same trial with `retry-of` reference).

## Example

User: `/crucible:planning "add rate limiting to /api/login"`

1. Planning calls codebase-analysis → identifies middleware layer.
2. Planning calls documentation-research → fetches docs for chosen rate-limit lib.
3. Planning drafts 5-step plan: install lib, write middleware, wire into route, run real-system test, capture validation artifacts.
4. Planning submits to oracle-review → APPROVED with timestamp T0.
5. Each step executes after T0; each step seals receipt via post-task hook.
6. After all steps, validation skill runs end-to-end exercise of /api/login under load.
