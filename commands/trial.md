---
name: trial
description: Run /crucible:forge inside a named trial subdirectory under evidence/robust-trials/trial-NN/. Fulfills PRD §1.13.5 FR-TRIAL-1..5 (≥4 trials, mix of planning + validation + SDK-driven). Use this when you need a labeled, isolated forge run.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task, Skill
---

# /crucible:trial

A trial is a forge run scoped into its own evidence subdirectory so multiple
forge invocations remain auditable and comparable. The PRD requires ≥4 trials
to satisfy FR-TRIAL-1..5; this command makes that requirement turnkey.

## Usage

```
/crucible:trial <trial-name> <task description> [--mode planning|validation|sdk]
```

- `<trial-name>` — kebab-case slug; becomes the trial directory's identifier
- `--mode planning` (default) — full forge pipeline
- `--mode validation` — validation-only (skips planning + execution; runs
  validation skill against an existing system)
- `--mode sdk` — Agent SDK-driven invocation (records SDK transcript at
  `evidence/agent-sdk/<trial-name>/`)

## Pipeline

### Step 1 — Allocate trial number
Find the next available `trial-NN/` under `evidence/robust-trials/`:
```bash
NEXT=$(ls evidence/robust-trials/ 2>/dev/null | grep -E '^trial-[0-9]+$' | sort -V | tail -1 | sed 's/trial-//')
NEXT=$((${NEXT:-0} + 1))
TRIAL_DIR="evidence/robust-trials/trial-$(printf '%02d' $NEXT)"
mkdir -p "$TRIAL_DIR"
```

### Step 2 — Symlink or scope evidence
For the duration of this trial, all forge-produced evidence is captured under
`$TRIAL_DIR/` AS WELL AS the canonical evidence paths. Use directory symlinks
or copy at trial-end.

Recommended: capture canonically, then at trial-end:
```bash
ln -s ../../../oracle-plan-reviews/<run> $TRIAL_DIR/oracle-plan-reviews
ln -s ../../../validation-artifacts/<run>.md $TRIAL_DIR/validation.md
ln -s ../../../session-logs/<run> $TRIAL_DIR/session-logs
ln -s ../../../session-receipts $TRIAL_DIR/session-receipts
ln -s ../../../completion-gate/report.json $TRIAL_DIR/gate-report.json
```

### Step 3 — Write trial metadata
Before invoking forge, write `$TRIAL_DIR/INDEX.md`:

```markdown
# Trial NN — <trial-name>

- Started: <iso timestamp>
- Mode: <planning|validation|sdk>
- Task: <task description>
- Run ID: (filled in by forge)

## Evidence

(Symlinks populated at trial-end; see $TRIAL_DIR contents.)
```

### Step 4 — Dispatch by mode

**`--mode planning`:** Invoke `/crucible:forge <task>`.

**`--mode validation`:** Invoke `/crucible:validate <task>`. Skips planning,
oracle plan-review, execution. Validates an existing system non-destructively.

**`--mode sdk`:** Invoke the SDK harness at `.crucible-sdk-harness/run.py` (or
equivalent) with the task. Capture the SDK session transcript at
`evidence/agent-sdk/<trial-name>/session.jsonl`.

### Step 5 — Trial-end synthesis
After the underlying forge/validate/sdk call returns, populate the trial INDEX
with:
- The actual run-id used
- The verdict (COMPLETE / REFUSED / VALIDATED)
- Symlinks to the canonical evidence

## Output

```
CRUCIBLE TRIAL — trial-NN <trial-name>
======================================
Mode:        <planning|validation|sdk>
Run ID:      <iso>
Verdict:     <COMPLETE|REFUSED|VALIDATED>
Trial dir:   evidence/robust-trials/trial-NN/
Index:       evidence/robust-trials/trial-NN/INDEX.md
```

## PRD Mapping

This command fulfills:
- FR-TRIAL-1: ≥4 trials (each invocation = 1 trial; run 4× to satisfy)
- FR-TRIAL-2: ≥2 planning trials (`--mode planning`)
- FR-TRIAL-3: ≥1 validation trial (`--mode validation`)
- FR-TRIAL-4: ≥1 SDK trial (`--mode sdk`)
- FR-TRIAL-5: each trial is self-contained under `evidence/robust-trials/trial-NN/`

After 4 invocations (mixing modes appropriately), the FR-TRIAL family is satisfied.
