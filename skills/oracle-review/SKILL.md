---
name: oracle-review
description: Convene Oracle plan-review verdicts (pre-execution) AND final Oracle evidence-audit verdicts (post-execution, quorum-gated). Use this skill whenever the planning skill submits a plan for approval, whenever VG-14 of a Crucible run executes, or whenever a quorum decision is required. Spawns 3+ independent Oracle subagents in isolated contexts; aggregates verdicts; refuses completion if quorum (≥2 APPROVE, 0 unresolved critical blockers) is not met. Produces evidence/oracle-plan-reviews/ AND evidence/final-oracle-evidence-audit/.
---

# Oracle Review

## Scope

This skill handles two distinct Oracle dispatches (PRD §1.19, §1.20):

1. **Plan-review mode** — pre-execution approval of a planning trial's PLAN.md. Required by FR-PLAN-5/6.
2. **Final evidence-audit mode** — post-execution quorum approval of the entire evidence package. Required by FR-ORACLE-1..4 and MSC-18-21.

Does NOT handle: producing plans (that's `planning`), producing evidence (that's gate-specific skills), reviewer-consensus dispatch (that's a separate concern at VG-13).

## Security

- Each Oracle subagent runs in an ISOLATED context window — no shared state, no shared scratchpad.
- Oracles receive ONLY the read-only path to the artifact under review.
- Oracle subagents are FORBIDDEN from running execution tools (no Write, no Edit, no destructive Bash).
- Oracles MUST cite specific evidence paths for every PASS verdict; refuse to PASS without citation.
- An Oracle that approves without citation MUST be treated as malformed — re-spawn fresh.

## Workflow

### Plan-review mode

1. Receive the planning trial's PLAN.md path.
2. Spawn 1 Oracle subagent (`oracle-auditor-1` or equivalent) via Task tool.
3. Oracle reads PLAN.md, evaluates against PRD §1.13.1 FR-PLAN-1..8.
4. Oracle writes `evidence/oracle-plan-reviews/trial-NN-verdict.md` with: APPROVE or REJECT, cited blockers if any.
5. Verdict timestamp MUST predate any execution timestamp (FR-PLAN-6).
6. If REJECT: planning skill refuses to execute; surfaces blockers to user.

### Final evidence-audit mode (quorum-gated)

1. Spawn ≥3 Oracle subagents (`oracle-auditor-1`, `-2`, `-3`) in PARALLEL via Task tool.
2. Each Oracle receives read-only path to `evidence/`.
3. Each Oracle writes `evidence/final-oracle-evidence-audit/oracle-N.md` with:
   - Per-MSC verdict (PASS/FAIL/INSUFFICIENT_EVIDENCE)
   - Critical blockers list
   - Citations to evidence paths
   - `OVERALL: APPROVE` or `OVERALL: BLOCK`
4. Aggregate verdicts into `decision.md`: count_approve, count_block, list_open_blockers.
5. Quorum: ≥2 APPROVE AND zero unresolved critical blockers.
6. Any blocker raised by any Oracle MUST be remediated; the originating Oracle re-issues verdict after remediation.

## Produced artifacts

- `evidence/oracle-plan-reviews/trial-NN-verdict.md` — pre-execution approval
- `evidence/final-oracle-evidence-audit/oracle-1.md`, `-2.md`, `-3.md` — independent reports
- `evidence/final-oracle-evidence-audit/decision.md` — quorum aggregation
- `evidence/final-oracle-evidence-audit/blockers/<id>.md` — one per critical blocker (paired with remediation receipt)

## Forbidden actions

- Sharing context between Oracle subagents.
- Spawning fewer than 3 Oracles for final-audit mode.
- Allowing an Oracle to write or edit anything outside its own oracle-N.md.
- Marking a blocker resolved without a paired remediation receipt AND an updated APPROVE from the originating Oracle.
- Synthesizing a unanimous APPROVE when actual Oracle verdicts are mixed.

## Example

Final audit at VG-14:

1. Spawn 3 Oracle subagents in parallel via Task tool with subagent_type=oracle-auditor-1/-2/-3.
2. Each receives read-only access to `/Users/nick/Desktop/crucible/evidence/`.
3. Oracle-1 returns APPROVE citing every MSC.
4. Oracle-2 returns BLOCK citing missing AUTH-DEVIATION.md in agent-sdk/.
5. Oracle-3 returns APPROVE.
6. decision.md: 2 APPROVE, 1 BLOCK, 1 open blocker (missing AUTH-DEVIATION.md).
7. Plugin remediates: writes AUTH-DEVIATION.md.
8. Oracle-2 re-evaluates → APPROVE.
9. Final: 3 APPROVE, 0 open blockers → quorum met.
