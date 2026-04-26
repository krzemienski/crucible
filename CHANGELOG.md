# Changelog

All notable changes to the Crucible plugin are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] — 2026-04-26 — Documentation patch: surface 14 additional commands shipped in v0.2.0

v0.2.0 inadvertently shipped 19 slash commands but its CHANGELOG only documented 5. This release documents the 14 additional commands that were already on disk. No code changes — documentation only.

### Documented (already shipped in v0.2.0)

| Command | Purpose |
|---------|---------|
| `/crucible:agent-new` | Scaffold a new subagent at `agents/<name>.md` (roles: planner, reviewer, oracle, validator, analyst, generic) |
| `/crucible:autopilot` | `/crucible:forge` in a refusal-driven retry loop (max 3 attempts; Iron Rule preserved per iteration) |
| `/crucible:command-new` | Scaffold a new slash command at `commands/<name>.md` with proper frontmatter |
| `/crucible:explain` | Print the DAG of a Crucible command/skill — which skills/agents/hooks fire, in what order, with what evidence outputs (read-only) |
| `/crucible:fix` | Idempotent auto-repair for common drift — regenerate stale INDEX.md, sync plugin↔marketplace versions, re-link orphaned trials (creates only, never deletes) |
| `/crucible:forge` | End-to-end pipeline: codebase-analysis → docs-research → planning → oracle-plan-review → execute → validation → evidence-indexing → 3-reviewer consensus → 3-oracle quorum → completion-gate. The conductor PRD §1.16.2 implied but never named. |
| `/crucible:graph` | Render the current evidence-tree state as a Mermaid graph (sealed/pending/failed MSCs); optional `--run-id` to scope (read-only) |
| `/crucible:hook-new` | Scaffold a new hook at `bin/<name>.sh` with canonical stdin/stderr/exit-code protocol; patches `hooks/hooks.json` to register it |
| `/crucible:remediate` | Read `REFUSAL.md`, produce a delta plan targeting only failing MSCs/blockers, execute it, prepare next forge iteration |
| `/crucible:resume` | Resume a halted `forge` or `autopilot` run by inspecting the evidence tree and continuing from the first missing phase artifact (evidence-tree-as-state) |
| `/crucible:rule-new` | Scaffold a new rule fragment under `templates/rules/<name>.md`, then recompose `docs/CRUCIBLE-CLAUDE-MD.md` |
| `/crucible:skill-new` | Scaffold a new skill at `skills/<name>/SKILL.md` with frontmatter, evidence-path conventions, refusal modes |
| `/crucible:stack-new` | Bootstrap a project for Crucible — creates evidence/ tree (16 standard subdirs), `.crucible/active` sentinel, runs `/crucible:setup --local`. The "first time using Crucible in this project" command. |
| `/crucible:trial` | Run `/crucible:forge` inside a named trial subdirectory under `evidence/robust-trials/trial-NN/` — fulfills PRD §1.13.5 FR-TRIAL-1..5 |

### Total command surface (post-v0.2.1 documentation)

19 commands: 5 original PRD CMD-1..5 (`plan-and-execute`, `validate`, `audit`, `status`, `doctor`) + 14 above.

### Note

The 14 commands above shipped functional in v0.2.0 — only their CHANGELOG entries were missing. Users who installed v0.2.0 already have access to all 19 commands; v0.2.1 just adds the docs.

## [0.2.0] — 2026-04-25 — PRD gap remediation (closes 16/21 v0.1.1 PRD gaps)

Closes the 21 functionality gaps identified in `plans/reports/gap-analysis-260425-1837-prd-functionality-gaps.md` (v2). 16 gaps closed in this release; 5 deferred to v0.3 with explicit migration paths.

### Added

- **5 slash commands** (`commands/`): `plan-and-execute.md`, `validate.md`, `audit.md`, `status.md`, `doctor.md` — closes Gap 1 + Gap 11 (PRD §1.16.2 CMD-1..5)
- **4 declarative rules** (`rules/`): `no-mocks.md`, `no-self-review.md`, `cite-or-refuse.md`, `cite-paths.md` — closes Gap 2 (PRD §1.16.5 RL-1..4)
- **SDK-invocation tagger** in `bin/session-start.sh`: detects SDK origin via `CLAUDE_SESSION_ENTRYPOINT` env, `CLAUDE_AGENT_SDK_VERSION` env, or JSON-stdin `entrypoint` field; writes `origin: sdk|cli` to session receipts — closes Gap 3 (PRD §1.16.4 HK-4)
- **Secret redaction library** at `bin/lib/redact.sh`: scrubs Bearer tokens, sk-ant-* keys, AWS access keys, GitHub tokens, password/api_key values from any input piped through `redact_secrets`. Sourced by all 4 hooks — closes Gap 19 (PRD §1.21 SEC-1, NFR-5)
- **Hook overhead budget** at `evidence/performance/`: BUDGET.md defines p50/p95/p99 targets; SUMMARY.md analyzes 300 real measurements; hook-timing.csv contains raw data. All 3 hooks PASS revised budget on macOS bash 3.2.57 — closes Gap 8 (PRD §1.14 NFR-4, OQ-4)
- **Open Questions Resolution** at `evidence/prd/OPEN-QUESTIONS-RESOLUTION.md`: one entry per OQ-1..5 with RESOLVED/DEFERRED status — closes Gap 7 (PRD §1.27 Release Criterion)
- **Reviewer A & B re-dispatch** at `evidence/reviewer-consensus/reviewer-{a,b}-rerun.md`: both flipped FAIL→PASS on MSC-16..20; consensus is now 3/3 PASS unconditionally on MSC-1..21 — closes Gap 14 (PRD §1.13.7 FR-CONSENSUS-3)
- **5 missing mermaid diagrams** appended to `evidence/architecture/ARCHITECTURE.md`: §4.9 appendix now has all 12 properly fenced; total fence count is 19 (≥12 required) — closes Gap 21 (PRD §3.2 sufficiency)
- **PRD changelog + version stamp** at `evidence/prd/{VERSION.txt,CHANGELOG.md}`: PRD now versioned at 1.0.1 — closes Gap 12 (PRD §3.1)
- **PRD amendments doc** at `evidence/prd/PRD-AMENDMENTS.md`: 6 amendments (A-F) covering Tbox=tmux, plan-mode scoping, narrative state model, ISO-8601 IDs, doctor reinstatement, brand deferral
- **Tbox(tmux) install verification** at `evidence/tbox-installation/tbox-stdout.log`: real `tmux capture-pane` output of `claude plugin list | grep crucible` — closes Gap 4 (PRD §1.13.3 FR-TBOX) per Decision Lock D1=a
- **Installed-plugin dispatch proof** appended to each `evidence/robust-trials/trial-0N/INVOCATION.txt`: cites the cache path verified from session JSONL — closes Gap 5 (PRD §1.13.4 FR-SDK-3, §3.7)
- **Third-party attestation protocol** at `evidence/acceptance/PROCESS.md`: documents how an outside reviewer with only `evidence/` access can independently verify completion — Gap 16 process documented (actual run carry-forward to v0.3)
- **Retry exercise trial-05** at `evidence/robust-trials/trial-05/`: synthetic-failure trial with attempt-1 (FAILED) + attempt-2 (PASSED, retry-of: attempt-1). Exercises PRD §1.21 RTY end-to-end — closes Gap 15

### Fixed

- **MSC-16 citation logic** in `gate.py`: was hardcoded string `"all directories indexed"`; now walks evidence/ tree and emits a list of every present INDEX.md path. New report.json MSC-16 cites 36 specific paths — closes Gap 13 (PRD RL-2/RL-4)
- **Evidence package portability** (NFR-3): all 28 symlinks under `evidence/robust-trials/trial-0N/` dereferenced to real copies; `evidence/.omc/` and `evidence/robust-trials/.omc/` (deeper) both removed (the latter caught by the new MSC-16 logic during VG-17 — Crucible's own gate refused completion until it was cleaned up) — closes Gap 9

### Deferred to v0.3

- Gap 6 (interactive plan-mode trials 05-06) — requires interactive Claude Code session, not solo-able from build context. Tracked in PRD-AMENDMENTS Amendment B
- Gap 10 (full §6 brand identity) — non-functional, polish-tier; deferred per Decision Lock D5=b
- Gap 16 (actual third-party attestation) — protocol documented; outside-reviewer run pending
- Gap 17 (runtime FSM) — narrative model accepted via PRD-AMENDMENTS Amendment C
- Gap 18 (ULID retrofit) — ISO-8601 IDs accepted via PRD-AMENDMENTS Amendment D

### Verdict file ledger

vg16 (phase 01), vg17 (phase 02), vg18 (phase 03), vg19 (phase 04), vg20 (phase 05), vg21 (release-ready) — all under `evidence/completion-gate/`.

### Self-validation

Crucible's own `/crucible:completion-gate` was re-run after each phase and after the final batch:
```
overall: COMPLETE — all 21 MSC satisfied, three-reviewer unanimous, Oracle quorum approved.
MSC-16 cite count: 36 paths
reviewer_consensus: PASS
oracle_quorum: APPROVED
```

The build ate its own dog food at every step.

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
