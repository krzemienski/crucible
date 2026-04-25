# Crucible

> **What survives the test, ships.**

A Claude Code plugin that converts task execution into a scientific procedure. Every task — planning, validation-only, or SDK-driven — produces a reproducible evidence package. Completion is forbidden unless every mandatory success criterion is backed by inspectable evidence and a quorum of independent Oracles approves.

## What it does

Crucible enforces an **evidence-first execution discipline** at the plugin layer. It:

- Records every step into a structured evidence directory
- Refuses any completion claim that lacks an inspectable artifact
- Convenes three independent reviewers and three Oracle auditors before allowing completion
- Produces a machine-readable gate report (`completion-gate/report.json`) that any third party can audit

## Why

LLM-driven engineering systems routinely declare success without proof. Crucible removes the option to do so.

## Components

| Component                     | Count | Purpose                                                            |
|-------------------------------|-------|--------------------------------------------------------------------|
| Skills (`crucible:*`)         | 8     | codebase-analysis, documentation-research, planning, validation, evidence-indexing, session-log-audit, oracle-review, completion-gate |
| Subagents (`agents/*.md`)     | 10    | planner, codebase-analyst, documentation-researcher, validator, 3 reviewers, 3 Oracle auditors                                       |
| Hooks (`hooks/hooks.json`)    | 4     | SessionStart, PreToolUse, PostToolUse, Stop — gate enforcement layer |
| Bin scripts (`bin/*.sh`)      | 4     | session-start, pre-task, post-task, completion-attempt — read JSON from stdin, exit 2 to block on invariant violation |

## Install

```bash
# Local development (no install)
claude --plugin-dir /path/to/crucible-plugin

# Local marketplace
claude plugin marketplace add /path/to/crucible-plugin
claude plugin install crucible@<local-marketplace-name>

# GitHub remote
claude plugin marketplace add krzemienski/crucible
claude plugin install crucible@<remote-marketplace-name>
```

## Use

```bash
/crucible:planning       # Comprehensive planning + execution mode
/crucible:validation     # Validation-only mode (non-mutating)
/crucible:audit          # Final Oracle evidence audit
/crucible:completion-gate  # Evaluate the gate; refuse if any MSC is missing
/crucible:doctor         # (planned) verify install + plugin records + SDK reachability
```

## Iron Rule

If the real system doesn't work, fix the real system. **No** mocks, stubs, fakes, in-memory shims, `TEST_MODE`, hand-written transcripts, fixture-driven Oracle approvals, or any other substitute for real execution.

## Refusal discipline

Crucible exists to refuse. When evidence is missing, Crucible writes a structured `REFUSAL.md` and stops. There is no override flag. There is no force-complete. Refusal is a feature.

## Status

This is the first release (v0.1.0). The plugin was itself built under its own discipline: 16 evidence gates (VG-0 through VG-15), three-reviewer consensus, and final Oracle quorum audit. The build evidence package lives alongside this plugin under `../evidence/`.
