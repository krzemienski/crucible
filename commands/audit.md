---
name: audit
description: Run the Final Oracle evidence audit independently against the current evidence/ tree. Convenes 3 Oracle auditors, computes quorum, writes decision.md. Idempotent — safe to re-run. PRD §1.16.2 CMD-3.
allowed-tools: Read, Bash, Glob, Grep, Task, Skill
---

# /crucible:audit

Standalone runner for the Final Oracle evidence audit per PRD §1.13.8 (FR-ORACLE-1..4) and §3.13. Re-runnable against any well-formed `evidence/` tree.

## Pipeline

1. Verify `evidence/reviewer-consensus/decision.md` exists with PASS verdict (per §3.11)
2. Spawn 3 Oracle auditor subagents in parallel via Task tool:
   - `agents/oracle-auditor-1.md` — Completeness + Citation
   - `agents/oracle-auditor-2.md` — Structural Integrity
   - `agents/oracle-auditor-3.md` — Adversarial Skepticism
3. Each Oracle writes its raw verdict to `evidence/final-oracle-evidence-audit/oracle-N.md`
4. Synthesize quorum decision (≥2 APPROVE + 0 unresolved blockers) → `decision.md`
5. If any Oracle raises a critical blocker, file it under `blockers/<oracle-id>-<msc>-<timestamp>.md`

## Idempotency

Re-running this command does NOT overwrite prior verdicts; new runs are appended with timestamps.

## Refusal modes

- Reviewer consensus missing or FAIL → REFUSED (Oracle audit is downstream of reviewer consensus)
- Any Oracle raises a critical blocker → BLOCKED until remediated

## Closes Open Question

PRD §1.26 OQ-3: "Should `/crucible:audit` be runnable independently of execution mode?" — RESOLVED in v0.2: yes.
