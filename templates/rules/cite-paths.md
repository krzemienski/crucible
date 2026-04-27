---
name: cite-paths
description: Citations must be specific file paths, not directory globs or string descriptions. Companion to cite-or-refuse — defines path specificity. PRD §1.16.5 RL-4.
scope: reviewers, oracles, validator, all evidence-producing skills
---

# Rule RL-4 — Cite paths (specificity)

Citation paths must be **maximally specific** — to the file, not the directory; to the line range when feasible, not the file alone.

## Specificity ladder (most specific = best)

1. ✅ `evidence/session-logs/<id>/session.jsonl:42-58` — file + line range
2. ✅ `evidence/session-logs/<id>/INDEX.md` — file
3. ⚠️ `evidence/session-logs/<id>/` — directory (acceptable only when the whole directory is the artifact)
4. ❌ `evidence/session-logs/` — too broad
5. ❌ `evidence/` — meaningless

## When file alone is acceptable

- The file IS the artifact (e.g., a generated report; pointing at a line range adds no value)
- The directory is the artifact (e.g., `evidence/robust-trials/trial-01/` as a whole)

## When file alone is NOT acceptable

- The file is large (>500 lines) and the claim is about a specific behavior — cite the line range
- The file contains both passing and failing items — cite the passing ones specifically

## Enforcement

- Reviewers use `grep -n` for line citations against `session.jsonl` files
- Oracles re-verify by opening the cited line range
- `gate.py` accepts file paths but warns when a citation is a bare directory (unless directory IS the artifact per PRD §3.X)

## Why

A naive third party (PRD §1.28 Acceptance Criterion #1) must be able to navigate to the exact source of each PASS. A bare directory citation forces them to re-discover; a file+line citation hands them the answer.
