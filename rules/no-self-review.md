---
name: no-self-review
description: An agent that produced output may not review or approve that output. Independence is structural, not advisory. PRD §1.16.5 RL-3, §1.10 (Product Principles).
scope: reviewers, oracles, planning subagent
---

# Rule RL-3 — No self-review

The agent that PRODUCED an artifact may NOT also REVIEW or APPROVE that artifact.

## Examples

- The planner subagent may not review its own plan; Oracle plan-review is convened separately
- The validator subagent may not approve its own validation verdict; reviewer consensus is required
- A reviewer may not write a follow-up reviewer's verdict
- An Oracle may not approve another Oracle's BLOCK without independent re-evaluation

## Mechanism

- Subagents are spawned via the Task tool with isolated contexts (no shared session state)
- Each reviewer/oracle reads only `evidence/` and its role-specific instructions
- The synthesizer (parent session) NEVER acts as a reviewer or oracle — it only aggregates raw verdicts

## Enforcement

- The completion gate refuses if `evidence/reviewer-consensus/decision.md` is signed by the same agent that wrote any reviewer verdict
- Oracle quorum requires ≥2 distinct Oracle verdict files with distinct authors

## Why

PRD §1.10 Principle #2: "Independence over self-report. The actor never judges its own output." A single agent both performing and judging its work is the failure mode Crucible exists to prevent.
