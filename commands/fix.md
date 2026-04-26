---
name: fix
description: Idempotent auto-repair for common Crucible drift — regenerate stale evidence/INDEX.md files, sync plugin.json ↔ marketplace.json versions, re-create missing evidence subdirs, re-link orphaned trial directories. Read-write but safe (creates only; never deletes user content).
allowed-tools: Read, Write, Edit, Bash, Glob
---

# /crucible:fix

Repair common Crucible drift without destroying user content. Each repair is
idempotent — safe to re-run.

## Usage

```
/crucible:fix [--dry-run] [--only <repair-name>]
```

- `--dry-run` — print what would be repaired, do nothing
- `--only` — run a single repair (see list below)

## Repairs (each idempotent, each safe)

### R1 — Regenerate evidence INDEX.md
For every `evidence/<subdir>/` that lacks `INDEX.md`, create one:
```
# <subdir>

_Indexed by /crucible:evidence-indexing._
```

For existing INDEX.md files, do NOT overwrite — only create when missing.

### R2 — Sync plugin.json ↔ marketplace.json versions
Read `plugin.json.version` and `marketplace.json.plugins[0].version`. If they
disagree, prefer plugin.json (it's the canonical manifest) and patch
marketplace.json to match.

Also align `marketplace.json.metadata.version` if it lags.

### R3 — Re-create missing evidence subdirs
The 16 PRD-mandated subdirs of `evidence/`. Create any missing; populate
INDEX.md per R1.

### R4 — Re-link orphaned trials
For every `evidence/robust-trials/trial-NN/`, verify its symlinks point to
existing canonical evidence. If a symlink target is missing (because forge
was halted mid-trial), prune the dead symlink (do NOT delete trial dir).

### R5 — Restore plugin permissions
Ensure `bin/*.sh` and `scripts/**/*.sh` are executable (`chmod +x`). Plugin
installations sometimes drop the bit.

### R6 — CLAUDE.md marker repair
If the local CLAUDE.md contains `<!-- CRUCIBLE:START -->` but no matching
`<!-- CRUCIBLE:END -->` (or vice versa), remove the orphaned marker. Then
re-run `/crucible:setup --force` to install a fresh block.

This repair only handles the orphan-marker case. If the block is present and
both markers exist, it leaves it alone (use `/crucible:setup --force` to
refresh content).

## Pipeline

For each repair R1..R6:
1. Probe (read-only) for the drift condition
2. If `--dry-run` or `--only <other>`, skip the action
3. Apply the repair
4. Print the action taken

After all repairs, print a summary table:

```
CRUCIBLE FIX — repairs applied
==============================
R1  Evidence INDEX.md     | 3 created, 14 already present
R2  Manifest version sync | already in sync
R3  Evidence subdirs       | 0 missing
R4  Trial symlinks         | 1 dead symlink pruned (trial-03/oracle-plan-reviews)
R5  Script permissions     | 4 chmod +x applied
R6  CLAUDE.md markers      | clean
```

## Refusal modes

- `evidence/` missing entirely → refuse, hint to run `/crucible:stack-new`
- `plugin.json` malformed → refuse R2; do NOT attempt to patch a broken file
- CLAUDE.md target unreadable → refuse R6 only; other repairs continue

## What fix does NOT do

- Does NOT delete files (only prunes dead symlinks)
- Does NOT overwrite content (only creates when missing)
- Does NOT modify rules or agents
- Does NOT re-run forge or any pipeline

## Why idempotent matters

A user running `/crucible:fix` twice in a row should see the second invocation
report "all clean." If a repair is destructive or non-idempotent, it doesn't
belong here — it belongs as an explicit subcommand the user opts into.
