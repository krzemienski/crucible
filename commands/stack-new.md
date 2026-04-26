---
name: stack-new
description: Bootstrap a project for Crucible. Creates evidence/ tree (16 standard subdirs + INDEX.md), .crucible/active sentinel, and runs /crucible:setup --local. The "first time using Crucible in this project" command.
allowed-tools: Read, Write, Bash, Skill
---

# /crucible:stack-new

The single command to make a project Crucible-ready. Composes:
- Evidence directory scaffold (16 PRD-mandated subdirs)
- Activation sentinel (`.crucible/active`)
- `/crucible:setup --local` (CLAUDE.md block install + verification)

After this, `/crucible:forge` works in the project.

## Usage

```
/crucible:stack-new [--no-setup]
```

- `--no-setup` — skip the embedded `/crucible:setup --local` invocation. Use if
  the project's CLAUDE.md is already configured and you only need the evidence
  scaffold + activation.

## Required inputs

None. Runs against `$PWD`.

## Pipeline

### Step 1 — Refuse if already a Crucible project
If `.crucible/active` AND `evidence/` AND `evidence/INDEX.md` all exist, refuse:

```
REFUSED: this project already appears Crucible-ready.
- .crucible/active   exists
- evidence/INDEX.md  exists

To re-bootstrap: remove these and re-run /crucible:stack-new.
To extend an existing setup: run /crucible:setup --force.
```

### Step 2 — Scaffold evidence/ tree
Create the 16 standard subdirectories (mirrors what Phase 2 of `/crucible:setup`
does, but standalone here for users who want only the scaffold):

```bash
EVIDENCE_DIRS=(
  "acceptance" "agent-sdk" "architecture" "completion-gate"
  "documentation-research" "final-oracle-evidence-audit"
  "oracle-plan-reviews" "performance" "plugin-discovery"
  "plugin-records" "prd" "reviewer-consensus" "robust-trials"
  "session-logs" "session-receipts" "tbox-installation"
  "validation-artifacts"
)
mkdir -p evidence
for d in "${EVIDENCE_DIRS[@]}"; do
  mkdir -p "evidence/$d"
  if [ ! -f "evidence/$d/INDEX.md" ]; then
    printf '# %s\n\n_Indexed by /crucible:evidence-indexing._\n' "$d" > "evidence/$d/INDEX.md"
  fi
done

if [ ! -f evidence/INDEX.md ]; then
  cat > evidence/INDEX.md <<'MD'
# Evidence Directory

This tree is the durable record for every Crucible run in this project. Each
subdirectory has its own INDEX.md describing its contents. Do not delete
artifacts after a refusal — they are the audit trail.
MD
fi
```

### Step 3 — Activate
```bash
mkdir -p .crucible
touch .crucible/active
```

### Step 4 — Setup (unless `--no-setup`)
Invoke skill `crucible:setup` with `--local` to install the CLAUDE.md block.

### Step 5 — Doctor
Invoke skill `crucible:doctor` to confirm the substrate is healthy.

## Output

```
CRUCIBLE STACK — READY
======================
Project:     <pwd>
Evidence:    17 dirs scaffolded (16 standard + root INDEX.md)
Sentinel:    .crucible/active created
CLAUDE.md:   <target>/CLAUDE.md (CRUCIBLE block installed) [or skipped via --no-setup]
Doctor:      all checks passing

Next steps:
  /crucible:forge <task>     End-to-end pipeline
  /crucible:trial <name>     Named trial under evidence/robust-trials/
  /crucible:status           Current gate state
```

## Refusal modes

- Already-bootstrapped project → refuse (see Step 1)
- `/crucible:setup` failed → propagate refusal; do NOT silently mark stack ready
- `/crucible:doctor` reports drift → propagate; this command's contract is
  "project is Crucible-ready," and drift breaks that

## Why this is its own command

Without `stack-new`, every new Crucible adopter has to remember three
distinct steps (`enable`, `setup`, scaffold the evidence tree). Composing
them into one command is the difference between a 30-second adoption and a
half-hour adoption. The command is the conductor for adoption itself.
