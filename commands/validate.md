---
name: validate
description: Run Crucible's Validation-Only mode. Accepts a target artifact, claim, or codebase region; runs non-mutating validation; produces per-item PASS/FAIL with cited evidence. Refuses to issue a verdict when evidence is insufficient. PRD §1.16.2 CMD-2.
allowed-tools: Read, Bash, Glob, Grep, Task, Skill
---

# /crucible:validate

Invokes Crucible's validation workflow per PRD §1.13.2 (FR-VAL-1 through FR-VAL-4).

## Inputs

- Target: a file path, URL, claim, or codebase region
- Validation criteria: explicit per-item PASS/FAIL definitions

## Pipeline

1. Run skill `crucible:validation` against the target
2. Validator subagent (`agents/validator.md`) executes real-system checks (curl, jq, exit codes, file inspection)
3. Per-item PASS/FAIL written with evidence path citations
4. If evidence insufficient for any item → REFUSE that item (do not guess)
5. Output: `evidence/validation-artifacts/<trial-id>.md`

## Iron Rule

Validation runs against REAL systems only. No mocks, stubs, fixtures, or test doubles. See `rules/no-mocks.md`.

## Refusal modes

- Target unreachable → REFUSED
- Criteria unclear → REFUSED with request for clarification
- Evidence insufficient → REFUSED for that specific item (other items may still PASS)
