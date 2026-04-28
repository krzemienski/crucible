# Changelog

All notable changes to the Crucible plugin are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] — 2026-04-28 — Phase 2.5 Skill Discovery & Enrichment (FR-PLAN-3)

Implements PRD §1.13.1 **FR-PLAN-3** — *"Identify required skills and declare them in the plan."* The forge pipeline grows from 10 phases to **11**: a new Phase 2.5 (Skill Discovery & Enrichment) runs after documentation-research and before planning. It walks the user's entire skill ecosystem (`~/.claude/skills/`, every enabled plugin under `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/skills/`, project `.claude/skills/`, and the in-tree `crucible-plugin/skills/`), parses YAML frontmatter only (no body loads — frontmatter is the discovery surface per Claude Code skills doc), filters to enabled plugins via `installed_plugins.json` schema v2, scores via lexical overlap of the task brief vs each skill's description (capped at 1,536 chars per Claude Code's skill-listing truncation), and emits 5–10 ranked candidates. The planner injects them into PLAN.md's new **`## Required Skills`** section so executors invoke them during Phase 5.

### Empirical validation (A/B harness)

Validated end-to-end by **8 real SDK harness runs** (4 baseline + 4 treatment) over a 4-prompt corpus (3 positive + 1 negative control). Every run produced a real `~/.claude/projects/.../<session-id>.jsonl` (126K–225K bytes each). Smoking-gun causality: P1 treatment ("Audit a React component for WCAG 2.1 AA accessibility issues.") JSONL line 50 contains the literal `tool_use` block invoking `validationforge:accessibility-audit` — the #1 ranked candidate from Phase 2.5's INDEX (score 0.6667, overlap=4). All 4 baselines invoked 0 candidate skills. Negative control (N1: "Tell me a joke about pirates.") correctly produced REFUSAL.md (0 above floor; 766 SKILL.md files enumerated). Three independent reviewers confirmed 20/20 MSCs PASS, 0 Iron-Rule violations.

### Added

- **`/crucible:skill-enrichment` skill** at `skills/skill-enrichment/SKILL.md`. Discovers and ranks skills relevant to a task brief from the user's entire skill ecosystem. Frontmatter description ≤1,536 chars (matches Claude Code skill-listing truncation). Refuses (exit 2 + REFUSAL.md) when fewer than 3 candidates score above the relevance floor with absolute token-overlap ≥ 2 — orthogonal-domain protection, no padding.
- **`skill-discoverer` subagent** at `agents/skill-discoverer.md`. Read-only (Read, Grep, Glob, Bash). Spawns from the skill-enrichment skill. Surfaces refusals verbatim to the planner.
- **`scripts/discover_skills.py`** at `skills/skill-enrichment/scripts/discover_skills.py`. Real Python 3.10+. Walks 4 sanctioned scopes; resolves plugin skills via `installed_plugins.json` v2 `installPath` records (NOT the empty-stub `~/.claude/plugins/<plugin>/` directories). Lexical-overlap scoring with stopword filter and minimum absolute overlap of 2 tokens to kill 1-token noise on short briefs. Configurable via env: `TASK_BRIEF`, `EVIDENCE_TARGET`, `SCORE_FLOOR` (default 0.10), `MIN_OVERLAP` (default 2), `MIN_CANDIDATES` (default 3), `MAX_CANDIDATES` (default 10).
- **A/B harness wrapper** at `.crucible-sdk-harness/sdk_forge_variant.py`. Peer to `sdk_planning.py`. Accepts `--variant=baseline|treatment --prompt-id=P1|P2|P3|N1`. Captures session JSONL via real `claude_agent_sdk.query()`. Computes `phase-25-fired.txt` (Bash discover_skills.py count) and `skill-invocations.txt` (Skill tool-use names) by post-processing the real session log.
- **`max_turns` kwarg** on `.crucible-sdk-harness/_common.py:run_harness()`. Backward-compatible (default still 4). Treatment harness runs use 8; baseline 6.

### Changed

- **`commands/forge.md`** — inserted **Phase 2.5** section between Phase 2 and Phase 3 (additive; Phase 3+ NOT renumbered to preserve autopilot.md's parser stability). Refusal-modes table grew row `2.5` (orthogonal-domain refusal). File grew from 7,137 → 8,873 bytes.
- **`agents/planner.md`** — added third Input (`evidence/skill-enrichment/<run-id>/INDEX.md`) and required `## Required Skills` section in PLAN.md output schema. The Required Skills section IS the plan-side artifact of FR-PLAN-3 — without it, the plan is incomplete.
- **`skills/planning/SKILL.md`** — added Workflow step 3.5 invoking skill-enrichment between docs-research and planning. Refusal propagates: if skill-enrichment refuses (orthogonal domain), the planner refuses too.

### Iron Rule discipline

- No mocks, no stubs, no fixtures, no test files anywhere in the new code paths.
- No SDK substitution: harness uses real `claude_agent_sdk.query()`, not `requests.post` to the Messages API.
- All harness JSONL is byte-stream output from real `claude-code` v2.1.121 subprocesses (real msg_ IDs, toolu_ IDs, parentUuid chains, real cache_creation_input_tokens, real durationMs progressions).
- Negative-control N1 produces REFUSAL.md rather than padding — refusal is the load-bearing feature that proves the floor works.

### Empirical evidence (citations)

| MSC | Citation |
|-----|----------|
| MSC-SE-EMP-3 | `evidence/skill-enrichment-empirical/20260428T175056Z/{P1,P2,P3,N1}/treatment/phase-25-fired.txt` |
| MSC-SE-EMP-6 | `evidence/skill-enrichment-empirical/20260428T175056Z/P1/treatment/skill-invocations.txt` |
| MSC-SE-EMP-7 | `evidence/skill-enrichment-empirical/20260428T175056Z/{P1,P2,P3,N1}/baseline/skill-invocations.txt` |
| MSC-SE-EMP-8 | `evidence/skill-enrichment-empirical/20260428T175056Z/N1/treatment/skill-enrichment-output/REFUSAL.md` |
| Reviewer consensus | `evidence/reviewer-consensus/decision.md` (literal `UNANIMOUS PASS`) |
| Validation summary | `evidence/validation-artifacts/20260428T175056Z.md` |
| A/B summary | `evidence/skill-enrichment-empirical/20260428T175056Z/A-B-summary.md` |

### What's in the box (updated counts)

| | v0.3.0 | v0.4.0 |
|---|---|---|
| Slash commands (`/crucible:*`) | 19 | 19 (forge.md grew Phase 2.5; no new command) |
| Skills | 11 | **12** (+ skill-enrichment) |
| Subagents | 10 | **11** (+ skill-discoverer) |
| Hooks | 4 | 4 |
| Bin scripts | 4 | 4 |
| Setup scripts | 2 | 2 |
| Skill scripts (Python) | 2 | **3** (+ discover_skills.py) |
| Rule templates | 4 | 4 |

---

## [0.3.0] — 2026-04-27 — Setup mechanism + comprehensive documentation surface

The first minor bump since v0.2 ships two things that were missing in v0.2.x:
(1) a real install path for Crucible's discipline (the marker-managed CLAUDE.md
fragment installer modeled on `oh-my-claudecode:omc-setup`), and (2) the deep
documentation surface — `docs/OVERVIEW.md` (concepts, architecture, evidence
model, gate sequence, quorum mechanics, refusal protocol) and `docs/USAGE.md`
(per-command reference for all 19, per-skill reference for all 11, per-subagent
reference for all 10, three worked walkthroughs, refusal recovery playbook,
FAQ).

### Added

- **`/crucible:setup` skill** at `skills/setup/SKILL.md` with phased execution
  (4 phase files: `phases/01-install-claude-md.md`, `02-activate.md`,
  `03-verify.md`, `04-welcome.md`). Idempotent. Modeled directly on the
  `oh-my-claudecode:omc-setup` pattern: marker-managed CLAUDE.md block
  (`<!-- CRUCIBLE:START -->...<!-- CRUCIBLE:END -->`), backup before write,
  validate after write. Supports `--local` / `--global` / `--force` /
  `--uninstall`.
- **Setup helper scripts** at `scripts/setup-claude-md.sh` and
  `scripts/setup-progress.sh`. The CLAUDE.md installer uses awk to strip an
  existing marker block, appends the new fragment, and validates marker
  presence post-write. The progress tracker persists a JSON state at
  `.crucible/setup-progress.json` for resume support.
- **Helper library** at `scripts/lib/config-dir.sh` with
  `resolve_claude_config_dir()` and `resolve_project_root()` (handles
  `CLAUDE_CONFIG_DIR` env, sentinel walk-up, and macOS/Linux quirks).
- **Canonical CLAUDE.md fragment** at `docs/CRUCIBLE-CLAUDE-MD.md` —
  composed from the four canonical rule templates. This is the file
  `/crucible:setup` installs into your project's CLAUDE.md.
- **Rule templates** copied to `templates/rules/` (was previously only at
  top-level `rules/`). Plugin-shipped rules live under `templates/`; the
  top-level `rules/` directory remains for in-tree development reference.
- **`docs/OVERVIEW.md`** — 684 lines / ~30KB. Architecture, philosophy,
  four iron rules, component architecture, the forge pipeline (10 phases
  with refusal triggers), evidence model, quorum mechanics, gate sequence
  (VG-0..VG-15), refusal protocol, retry semantics, activation lifecycle,
  hooks layer, comparison to alternatives, glossary.
- **`docs/USAGE.md`** — 966 lines / ~32KB. 60-second tour, first-run
  lifecycle, three worked walkthroughs (green path, autopilot recovery,
  unrecoverable refusal), command reference for all 19 commands with
  examples, skill reference for all 11, subagent reference for all 10,
  hook reference, refusal recovery playbook, authoring extensions, common
  workflows, troubleshooting matrix, FAQ.
- **Doctor checks 7-9** added to `commands/doctor.md` and verified end-to-end:
  - Check 7: setup sentinel (`~/.claude/.crucible-config.json`)
  - Check 8: CLAUDE.md marker block presence
  - Check 9: setup script integrity (executable bits)

### Changed

- **`README.md` rewritten as top-of-funnel.** Was 268 lines / 13KB trying
  to cover everything; now 247 lines / ~7KB pointing at `docs/OVERVIEW.md`
  and `docs/USAGE.md` for depth. Sections retained: 60-second pitch, what's
  in the box, why it exists, quick start, command tiers (at-a-glance), four
  iron rules, opt-in activation, refusal philosophy, status table.
- **Activation section** now leads with `/crucible:setup` (the canonical
  entrypoint) instead of manual `mkdir -p .crucible && touch
  .crucible/active`.

### Verified at release

Frontmatter integrity:
```
✓ 19/19 commands have valid YAML frontmatter
✓ 11/11 skills have valid YAML frontmatter
✓ 10/10 agents have valid YAML frontmatter
```

Doctor-equivalent battery (run manually since `/crucible:doctor` requires
a fresh Claude Code session post-install):
```
✓ manifest         plugin.json valid (v0.3.0)
✓ installed        crucible@crucible-local enabled
✓ commands         19/19 present
✓ skills           11/11 present
✓ agents           10/10 present
✓ hooks            4/4 events registered (SessionStart/Pre/Post/Stop)
✓ rule templates   4/4 present
✓ sdk reachable    claude_agent_sdk 0.1.68
✓ activation       .crucible/active present in build context
✓ CLAUDE.md block  markers START + END both in docs/CRUCIBLE-CLAUDE-MD.md
✓ setup scripts    setup-claude-md.sh + setup-progress.sh executable
⚠ setup sentinel   ABSENT (expected — first user runs /crucible:setup)
```

Manifest schema validation:
```
$ claude plugin validate /Users/nick/Desktop/crucible/crucible-plugin
✔ Validation passed
```

Version parity:
```
.claude-plugin/plugin.json:                "version": "0.3.0"
.claude-plugin/marketplace.json metadata:  "version": "0.3.0"
.claude-plugin/marketplace.json plugins[0]:"version": "0.3.0"
```

### Migration notes

- **Existing v0.2.x users:** run `/crucible:setup --local` (or `--global`)
  to install the new CLAUDE.md marker block. If you previously hand-edited
  rules into your CLAUDE.md, the `--force` flag overwrites cleanly; the
  installer takes a backup first.
- **No breaking API changes.** All 19 commands, all 11 skills, all 10
  subagents, all 4 hooks behave identically to v0.2.1. The v0.3.0 surface
  is additive: setup mechanism, deep docs, doctor checks 7-9.
- **Cache refresh:** Claude Code's plugin cache keys on the marketplace
  version. Bumping `marketplace.json` from 0.2.1 → 0.3.0 forces the cache
  to pick up the new files; otherwise `claude plugin update` is a no-op.
  Both `metadata.version` and `plugins[0].version` are bumped in lockstep.

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
