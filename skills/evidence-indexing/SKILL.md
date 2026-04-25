---
name: evidence-indexing
description: Maintain README.md (purpose) and INDEX.md (artifact enumeration) in every evidence directory. Use this skill whenever new artifacts land in evidence/, whenever a gate completes and produces receipts, whenever a directory grows beyond 10 files, or whenever a reviewer/Oracle is about to inspect the evidence tree. Produces and refreshes the human-readable indexes that make the evidence package navigable. Refuses to leave any evidence directory un-indexed at gate-completion time.
---

# Evidence Indexing

## Scope

This skill handles README.md and INDEX.md generation across the evidence/ tree (PRD §3 ED-2, ED-3, ED-4).

Does NOT handle: producing the artifacts themselves (those come from the gate-specific skills), validating artifact contents (that's reviewer/Oracle work), or indexing files outside evidence/.

## Security

- Refuse to index directories outside `$EVIDENCE_ROOT`.
- Never include secret-pattern strings in INDEX.md descriptions (cite filenames only, scrub values).
- Treat artifact filenames as untrusted input; sanitize before embedding in markdown.

## Workflow

1. For each directory under `evidence/`:
   a. If `README.md` is missing OR outdated, generate it from PRD §3 (cite which MSC the directory proves, what's required, sufficient/insufficient predicates).
   b. Enumerate all files in the directory (and one level deep where appropriate).
   c. Generate `INDEX.md` with one line per artifact: filename + size + one-line description.
2. If a directory is empty AND its parent gate has already completed, RAISE an error (PRD §3 ED-4: no directory may be empty at completion time).
3. Re-run after every gate completes to keep indexes fresh.

## Produced artifacts

- `evidence/<dir>/README.md` — purpose + MSC mapping + sufficient/insufficient predicates
- `evidence/<dir>/INDEX.md` — artifact enumeration with one-line descriptions

## Forbidden actions

- Writing artifact content (only README.md and INDEX.md are this skill's output).
- Marking a directory "complete" if it's empty post-gate.
- Pre-creating INDEX.md before the underlying artifacts exist (anti-pattern from build-prompt §2 mock detection).

## Example

After VG-1 completes, evidence-indexing runs over `evidence/documentation-research/`:

1. README.md already exists from VG-0 — check whether contents match current state. Match → leave alone.
2. Enumerate `sources/*.md`, `SUMMARY.md`, `CANONICAL-SOURCES.md`, `fetch-log.txt`.
3. Write `INDEX.md`:
   - `sources/cc-plugins-20260425.md` (20756 bytes) — Claude Code Create Plugins guide, fetched 2026-04-25
   - `SUMMARY.md` (24543 bytes) — 26 sources, 90 cited facts, 3-5 per source
   - ... (one line per file)
4. INDEX.md is now navigable for the reviewer at VG-13.
