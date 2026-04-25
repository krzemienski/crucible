# Changelog

All notable changes to the Crucible plugin are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] — 2026-04-25 — CRITICAL: opt-in enforcement (was breaking unrelated projects)

### Fixed

- **CRITICAL** — Hooks now require explicit per-project opt-in. Previously, a user-scope install caused Crucible's `Stop` hook to refuse session termination in EVERY project (since the hook fired globally and demanded a passing `evidence/completion-gate/report.json` everywhere). This bricked unrelated workflows that had no Crucible evidence. After this release, hooks are silent no-ops unless `${CLAUDE_PROJECT_DIR}/.crucible/active` exists in the project root. Reported by users running deepest-plan and other workflows in non-Crucible projects.
- Hook `cwd` resolution: when `CLAUDE_PROJECT_DIR` resolved to an `evidence/` subdir (subprocess cwd quirk), the hooks created `evidence/evidence/`. Now walks up to the parent in all 4 hooks.
- `gate.py` blocker detection: previously treated `README.md`, `INDEX.md`, `STATUS.md` in `blockers/` as open blockers. Now excludes meta-files via explicit allowlist.

### Added

- **Three-layer enforcement model**:
  - Layer 1 (Activation): `.crucible/active` sentinel file — hooks check this FIRST.
  - Layer 2 (Escape hatches, all documented in refusal stderr):
    - `.crucible/disabled` kill switch (overrides active).
    - `CRUCIBLE_DISABLE=1` env var (per-shell escape).
    - `/crucible:disable` slash command.
  - Layer 3 (Fail-open on contradictory state): if `.crucible/active` exists but `evidence/completion-gate/` was never created, hook prints a one-line warning and exits 0 (no lock-in for abandoned workflows).
- New skill `/crucible:enable` — creates `.crucible/active` (idempotent, removes any existing `.crucible/disabled`).
- New skill `/crucible:disable` — removes `.crucible/active` (preserves evidence/).
- Refusal stderr message rewritten: now lists ALL 4 escape hatches explicitly so end users have a clear path out when the hook fires unexpectedly.

### Changed

- Skill count: 8 → 10 (added `enable`, `disable`).
- Refusal philosophy clarified: "no override during an active workflow" still holds, but opting in/out of the workflow itself is an explicit, documented user action — not a bypass.

## [0.1.0] — 2026-04-25

### Added

- Initial release.
- 8 skills: `codebase-analysis`, `documentation-research`, `planning`, `validation`, `evidence-indexing`, `session-log-audit`, `oracle-review`, `completion-gate`.
- 10 subagents: `planner`, `codebase-analyst`, `documentation-researcher`, `validator`, `reviewer-a`, `reviewer-b`, `reviewer-c`, `oracle-auditor-1`, `oracle-auditor-2`, `oracle-auditor-3`.
- 4 plugin hooks: `SessionStart`, `PreToolUse`, `PostToolUse`, `Stop` — evidence-gate enforcement layer.
- 4 hook scripts in `bin/`: `session-start.sh`, `pre-task.sh`, `post-task.sh`, `completion-attempt.sh`.
- Two execution modes: comprehensive planning + execution, and validation-only.
- Evidence directory layout matching PRD §3 (Evidence Model).
- Three-reviewer verification consensus.
- Final Oracle quorum audit (≥3 Oracles, ≥2 approvals, zero open critical blockers).
- Machine-readable completion-gate report (`completion-gate/report.json`).
- Iron Rule enforcement: no mocks, stubs, fakes, or fixtures in validation.

### Build provenance

This v0.1.0 release was itself built under Crucible's own discipline. The build evidence package lives at `<target-repo>/evidence/` and includes:

- `documentation-research/` — 26 cited upstream sources with ISO-8601 fetch timestamps
- `tbox-installation/` — install receipts via dual paths (local marketplace + GitHub remote)
- `plugin-records/` — parsed init-message enumeration
- `agent-sdk/` — SDK harness invocation traces (subscription auth)
- `robust-trials/trial-01..04/` — ≥4 trials covering planning/validation/SDK modes
- `session-logs/` — raw Claude Code session JSONL with line-cited audit indexes
- `validation-artifacts/` — real-system outputs per change-producing trial
- `reviewer-consensus/` — three independent reviewer reports
- `final-oracle-evidence-audit/` — three Oracle reports with quorum decision
- `completion-gate/` — final gate report with PASS/REFUSED determination
