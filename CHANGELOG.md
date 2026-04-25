# Changelog

All notable changes to the Crucible plugin are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
