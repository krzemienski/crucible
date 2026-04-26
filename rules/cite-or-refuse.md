---
name: cite-or-refuse
description: Every PASS verdict must cite a specific evidence file path. Missing citation = REFUSE. PRD §1.16.5 RL-2, §3 (Evidence Model).
scope: reviewers, oracles, validator, completion-gate
---

# Rule RL-2 — Cite or refuse

A PASS verdict that lacks an evidence path citation is INVALID.

## What counts as a citation

✅ A specific relative file path: `evidence/session-logs/20260425T091529Z-planning/INDEX.md`
✅ A path with a line range: `evidence/session-logs/<id>/session.jsonl:42-58`
✅ A list of file paths: `["a.md", "b.md", "c.md"]`

## What does NOT count

❌ A directory glob: `evidence/session-logs/*`
❌ A string description: `"all logs verified"` or `"all directories indexed"`
❌ A reference to a prior verdict: `"see oracle-1.md"`
❌ Memory ("I read it earlier")

## Enforcement

- `gate.py` walks each MSC's citation list and verifies every cited path exists and is non-empty
- Reviewer/Oracle verdicts that PASS without citations are treated as INSUFFICIENT
- The completion gate refuses overall=COMPLETE if any MSC.citations field is a string description rather than a path

## Why

PRD §1.10 Principle #3: "Reproducibility over narrative." A third party reading `evidence/` must be able to navigate to the exact artifact that proves each PASS. Strings are narrative; paths are evidence.
