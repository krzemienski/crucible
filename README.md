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
| Skills (`crucible:*`)         | 10    | codebase-analysis, documentation-research, planning, validation, evidence-indexing, session-log-audit, oracle-review, completion-gate, **enable**, **disable** |
| Subagents (`agents/*.md`)     | 10    | planner, codebase-analyst, documentation-researcher, validator, 3 reviewers, 3 Oracle auditors                                       |
| Hooks (`hooks/hooks.json`)    | 4     | SessionStart, PreToolUse, PostToolUse, Stop — gate enforcement layer |
| Bin scripts (`bin/*.sh`)      | 4     | session-start, pre-task, post-task, completion-attempt — read JSON from stdin, exit 2 to block on invariant violation |

## Install

See [`INSTALL.md`](./INSTALL.md) for the full installation guide (prerequisites, three install paths, troubleshooting).

Quick paths:

```bash
# Path A: GitHub marketplace (recommended)
claude plugin marketplace add krzemienski/crucible
claude plugin install crucible@crucible-local

# Path B: Local marketplace
claude plugin marketplace add /absolute/path/to/crucible-plugin
claude plugin install crucible@crucible-local

# Path C: --plugin-dir (no install, ephemeral)
claude --plugin-dir /absolute/path/to/crucible-plugin
```

Verify:

```bash
claude plugin list | grep crucible
# Expected: ❯ crucible@crucible-local  Version: 0.1.0  Status: ✔ enabled
```

## Activation (READ FIRST since v0.1.1)

**Crucible is OPT-IN per project.** A user-scope install does NOT enforce in every project. To activate enforcement in a project:

```bash
/crucible:enable
# or:  mkdir -p .crucible && touch .crucible/active
```

To deactivate (and unstick a blocked session):

```bash
/crucible:disable
# or:  rm .crucible/active
```

Three escape hatches are available if a hook blocks you:

| Method | When to use |
|--------|-------------|
| `/crucible:disable` | Clean opt-out for this project |
| `touch .crucible/disabled` | Kill switch — overrides `.crucible/active` |
| `CRUCIBLE_DISABLE=1 claude` | Per-shell escape |

The refusal stderr lists all hatches every time the gate blocks. See [`INSTALL.md`](./INSTALL.md#activation-lifecycle-since-v011) for full lifecycle.

## Use

Crucible exposes 10 skills via namespaced slash commands. After `/crucible:enable`, the Stop hook fires automatically on every session end.

### The 10 skills (full inventory)

| Skill | When to invoke | What it produces |
|-------|----------------|------------------|
| `/crucible:enable` | Before starting any Crucible workflow in a project | Creates `.crucible/active` sentinel; activates hooks |
| `/crucible:disable` | When opting out of a project, or when blocked by mistake | Removes `.crucible/active`; hooks become silent |
| `/crucible:planning` | Before any change-producing work | A plan with MSCs and an Oracle plan-review request |
| `/crucible:validation` | To audit an existing system without modifying it | A markdown checklist of real-system checks (curl/jq/exit-code) |
| `/crucible:codebase-analysis` | When you need a new repo's structure cited before planning | A summary of components + load-bearing files |
| `/crucible:documentation-research` | When SDKs/APIs/specs are involved | Cited doc snippets at `evidence/documentation-research/` |
| `/crucible:evidence-indexing` | After any evidence change | Refreshed `INDEX.md` for every evidence directory |
| `/crucible:session-log-audit` | After a real Claude Code session against the plugin | Line-cited audit of pre/post/stop/skill/writes from session.jsonl |
| `/crucible:oracle-review` | When you need an Oracle's perspective on a plan or evidence | An APPROVE/BLOCK verdict with cited blockers |
| `/crucible:completion-gate` | At the very end of a task | `report.json` (overall=COMPLETE or REFUSED) and, on REFUSED, `REFUSAL.md` |

### Detailed usage examples

#### Example 1 — `/crucible:planning` for a feature

```
You: /crucible:planning
     Add a /healthz endpoint to my FastAPI service.

Crucible (via planner subagent):
  1. Define MSCs:
     - MSC-1: GET /healthz returns {"status":"ok"} with HTTP 200
     - MSC-2: Endpoint registered in router
     - MSC-3: A test invocation returns the expected JSON
  2. Submit to oracle-auditor-1 for plan review.
  3. On approval, hand off to executor.

Artifacts produced:
  - evidence/oracle-plan-reviews/<run-id>/plan.md
  - evidence/oracle-plan-reviews/<run-id>/oracle-1-verdict.md
```

#### Example 2 — `/crucible:validation` checklist

```
You: /crucible:validation
     Verify GET /healthz returns {"status":"ok"} and 200.

Crucible (via validator subagent):
  Returns markdown checklist with 7 items, each naming a real
  curl/jq invocation, expected output file (step-NN-*.txt),
  and PASS/FAIL/REFUSAL criterion.

Iron Rule: this skill produces ZERO Write/Edit tool calls
(verified via session-log audit's writes count = 0).
```

See `evidence/validation-artifacts/20260425T091803Z-validation.md` in this repo's
build evidence for a captured example (7-item checklist with curl/jq commands).

#### Example 3 — `/crucible:completion-gate` at task end

```
You: /crucible:completion-gate

Crucible (runs gate.py):
  SEAL    MSC-1  documentation-research/SUMMARY.md
  SEAL    MSC-2  prd/PRD.md
  ...
  SEAL    MSC-21 final-oracle-evidence-audit/blockers
  APPROVE consensus  reviewer-consensus/decision.md
  APPROVE quorum     final-oracle-evidence-audit/decision.md
  overall: COMPLETE

  → exit 0 (Stop hook will allow session to end)
```

If any MSC fails:

```
  REFUSED  MSC-15 validation-artifacts EMPTY
  overall: REFUSED — fix the cited gaps and re-run.
  → exit 2 (Stop hook will refuse to let session end)
```

#### Example 4 — Stop event (automatic, you don't invoke this)

Crucible's `bin/completion-attempt.sh` fires on every session end:

```
Hook Stop (Stop) error:
REFUSED by Crucible completion-attempt hook.
Reason: completion-gate/report.json shows overall=REFUSED (must be COMPLETE)

Crucible exists to refuse completion claims that lack evidence.
Run /crucible:completion-gate to evaluate and produce report.json.
If gate produces overall=REFUSED, fix the cited gaps and re-run.
There is NO override flag. NO force-complete. Refusal is a feature.
```

### Three-reviewer / Oracle quorum (advanced workflows)

For audits, releases, security-sensitive work:

1. After your task, dispatch 3 isolated reviewer subagents (`reviewer-a/b/c`) to
   independently verify completeness, integrity, and Iron-Rule compliance.
2. Synthesize their verdicts into `evidence/reviewer-consensus/decision.md` with
   the keyword `UNANIMOUS PASS` (the gate looks for this exact string).
3. Dispatch 3 Oracle auditors (`oracle-auditor-1/2/3`) for the final adversarial
   audit. Quorum = ≥2/3 APPROVE + 0 unresolved blockers.
4. Synthesize Oracle verdicts into `evidence/final-oracle-evidence-audit/decision.md`
   with keyword `APPROVED`.
5. Run `/crucible:completion-gate` — only now can it return `overall=COMPLETE`.

This is the workflow Crucible itself was built under (see `evidence/completion-gate/vg13-verdict.md` and `vg14-verdict.md` for live receipts).

## Architecture

See `evidence/architecture/ARCHITECTURE.md` for the full system architecture document, which includes 7 Mermaid diagrams covering:

- High-level component map (skills + agents + hooks + evidence + audit)
- Tool-invocation lifecycle (Pre→Tool→Post→Stop with Iron-Rule branch)
- Audit pipeline (session-log-audit → reviewer-consensus → oracle-quorum → completion-gate)
- Reviewer-consensus parallel dispatch sequence
- Oracle-quorum parallel dispatch sequence
- State model (IDLE → PLANNING → ... → {COMPLETE | REFUSED})
- Stop event sequence (gate.py decision flow)

## Iron Rule

If the real system doesn't work, fix the real system. **No** mocks, stubs, fakes, in-memory shims, `TEST_MODE`, hand-written transcripts, fixture-driven Oracle approvals, or any other substitute for real execution.

## Refusal discipline

Crucible exists to refuse. When evidence is missing, Crucible writes a structured `REFUSAL.md` and stops. There is no override flag. There is no force-complete. Refusal is a feature.

## Status

This is the first release (v0.1.0). The plugin was itself built under its own discipline: 16 evidence gates (VG-0 through VG-15), three-reviewer consensus, and final Oracle quorum audit. The build evidence package lives alongside this plugin under `../evidence/`.
