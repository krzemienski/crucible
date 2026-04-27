# Phase 2 — Activate (Sentinel + Evidence Scaffold)

## Create activation sentinel

For both `--local` and `--global`, the project still needs an activation
sentinel. Create it in the current project root:

```bash
mkdir -p .crucible
touch .crucible/active
```

Crucible's hooks read `.crucible/active` on every PreToolUse / PostToolUse /
Stop event. Without this file, hooks are silent and the gate does not enforce.

## Scaffold evidence directory

Crucible expects 16 standard evidence subdirectories per the PRD. Create any
that are missing; do NOT overwrite content that already exists.

```bash
EVIDENCE_DIRS=(
  "acceptance"
  "agent-sdk"
  "architecture"
  "completion-gate"
  "documentation-research"
  "final-oracle-evidence-audit"
  "oracle-plan-reviews"
  "performance"
  "plugin-discovery"
  "plugin-records"
  "prd"
  "reviewer-consensus"
  "robust-trials"
  "session-logs"
  "session-receipts"
  "tbox-installation"
  "validation-artifacts"
)
mkdir -p evidence
for d in "${EVIDENCE_DIRS[@]}"; do
  mkdir -p "evidence/$d"
  if [ ! -f "evidence/$d/INDEX.md" ]; then
    printf '# %s\n\n_Indexed by /crucible:evidence-indexing._\n' "$d" > "evidence/$d/INDEX.md"
  fi
done
```

## Save Progress

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-progress.sh" save 2 "$TARGET"
```

## Report

```
✓ Phase 2: Activated
   Sentinel: .crucible/active created
   Evidence: 17 dirs scaffolded under ./evidence/ (existing INDEX.md preserved)
```

Continue to Phase 3.
