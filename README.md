# Crucible

> **What survives the test, ships.**

A Claude Code plugin that converts task execution into a scientific procedure.
Every change-producing run produces a reproducible **evidence package**, and
completion is forbidden unless every Mandatory Success Criterion is backed by
an inspectable artifact and a quorum of independent Oracles approves.

In one sentence: **Crucible is the gate between "I did the work" and "the
work is done."**

---

## What's in the box

| | Count |
|---|---|
| Slash commands (`/crucible:*`) | **19** — three tiers: orchestration, authoring, inspection |
| Skills | **12** — codebase-analysis, docs-research, planning, **skill-enrichment** (NEW v0.4), validation, evidence-indexing, session-log-audit, oracle-review, completion-gate, enable, disable, setup |
| Subagents | **11** — planner, codebase-analyst, docs-researcher, **skill-discoverer** (NEW v0.4), validator, 3 reviewers, 3 oracles |
| Hooks | **4** — SessionStart, PreToolUse, PostToolUse, Stop |
| Bin scripts | **4** — hook handlers (read JSON stdin, exit 2 to block) |
| Setup scripts | **2** — CLAUDE.md installer + progress tracker |
| Skill scripts | **3** — `gate.py` (completion gate), `build_index.py` (evidence indexer), `discover_skills.py` (NEW v0.4: skill-enrichment) |
| Rule templates | **4** — Iron-Rule, Cite-or-Refuse, Cite-Paths, No-Self-Review |

**Iron-Rule violations: 0.** Crucible was itself built under its own
discipline — the build evidence package lives in `../evidence/` of this repo.

---

## Why it exists

LLM-driven engineering systems routinely declare success without proof. They
claim a feature works because the code looks right; they claim a refactor is
safe because it compiles; they emit "Done!" while leaving silent test
failures and missing migrations behind. This isn't adversarial — it's the
default failure mode of a context-bounded system trained to produce coherent
text. Coherent text is not evidence.

Crucible removes the option to fake completion. Three moves at the plugin
layer:

1. **Hooks watch every tool use.** `PreToolUse` rejects writes to test
   files, mocks, stubs, fixtures. `Stop` refuses session end unless
   `evidence/completion-gate/report.json` shows `overall=COMPLETE`.

2. **Verdicts cite paths or are invalid.** Every PASS / FAIL / APPROVE /
   BLOCK must point to a specific file (and ideally line range). Prose
   isn't a citation.

3. **Independence is structural, not advisory.** The agent that produced
   an artifact may not also approve it. Three reviewers in isolation.
   Three Oracles in isolation. The synthesizer aggregates raw verdicts;
   it never rewrites them.

When Crucible says COMPLETE, an outside reviewer with only `evidence/` can
independently verify. When it refuses, the refusal is structured,
machine-readable, and remediable.

---

## Quick start

```bash
# 1. install (once per machine)
claude plugin marketplace add krzemienski/crucible
claude plugin install crucible@crucible-local

# 2. set up (once per project)
cd my-project
/crucible:setup --local

# 3. work
/crucible:forge "Add /healthz endpoint that returns {status:ok}"
```

If `/crucible:forge` refuses:

```bash
/crucible:remediate          # auto-generates delta plan from REFUSAL.md
/crucible:forge              # retry
```

Or use `/crucible:autopilot <task>` to loop forge → remediate → forge up to
3 attempts automatically.

If you're stuck and need out:

```bash
/crucible:disable             # clean opt-out
touch .crucible/disabled      # nuclear opt-out
CRUCIBLE_DISABLE=1 claude     # one-shell escape
```

---

## Documentation

| Doc | When to read it |
|---|---|
| [`docs/OVERVIEW.md`](./docs/OVERVIEW.md) | Architecture, philosophy, evidence model, gate sequence, quorum mechanics, refusal protocol — the conceptual reference |
| [`docs/USAGE.md`](./docs/USAGE.md) | Per-command reference (all 19), per-skill reference (all 12), per-subagent reference (all 11), three worked walkthroughs, refusal recovery playbook, FAQ |
| [`docs/CRUCIBLE-CLAUDE-MD.md`](./docs/CRUCIBLE-CLAUDE-MD.md) | The canonical CLAUDE.md fragment that `/crucible:setup` installs |
| [`INSTALL.md`](./INSTALL.md) | Three install paths, prerequisites, troubleshooting, activation lifecycle |
| [`CHANGELOG.md`](./CHANGELOG.md) | Release history (v0.1.0 → v0.4.0) |

For "what does X actually do?" questions, run:

```
/crucible:explain forge          # DAG of any pipeline
/crucible:doctor                 # 9-check installation health
/crucible:status                 # current gate state
```

---

## Command tiers (at a glance)

### Tier 1 — Orchestration (the conductors)

`/crucible:forge` · `/crucible:autopilot` · `/crucible:remediate` ·
`/crucible:resume` · `/crucible:trial`

`/crucible:forge` is the 80% case: codebase-analysis → docs-research →
planning → oracle plan-review → execute → validation → evidence-indexing →
3-reviewer consensus → 3-oracle quorum → completion-gate.

### Tier 2 — Authoring (extend Crucible itself)

`/crucible:setup` · `/crucible:stack-new` · `/crucible:skill-new` ·
`/crucible:agent-new` · `/crucible:rule-new` · `/crucible:hook-new` ·
`/crucible:command-new`

### Tier 3 — Inspection (read-only)

`/crucible:doctor` · `/crucible:status` · `/crucible:explain` ·
`/crucible:fix` · `/crucible:graph`

### Tier 0 — Activation primitives (composed by Tier 1)

`/crucible:enable` · `/crucible:disable` · `/crucible:planning` ·
`/crucible:validation` · `/crucible:codebase-analysis` ·
`/crucible:documentation-research` · `/crucible:evidence-indexing` ·
`/crucible:session-log-audit` · `/crucible:oracle-review` ·
`/crucible:completion-gate` · `/crucible:plan-and-execute` ·
`/crucible:validate` · `/crucible:audit`

Full reference — including allowed flags, refusal modes, and worked
examples — lives in [`docs/USAGE.md`](./docs/USAGE.md).

---

## The four iron rules

These are installed into your project's `CLAUDE.md` by `/crucible:setup`,
between `<!-- CRUCIBLE:START -->` and `<!-- CRUCIBLE:END -->` markers
(idempotent, with backup).

- **RL-1 — Iron Rule (no mocks).** Validation runs against real systems
  only. Forbidden: mocks, stubs, fakes, fixtures, test files, test
  frameworks, hand-written "expected" output presented as actual output.
- **RL-2 — Cite or Refuse.** Every verdict cites a specific evidence file
  path. Prose isn't a citation.
- **RL-3 — No Self-Review.** The agent that produced an artifact may not
  also review or approve it. Independence is structural.
- **RL-4 — Cite Paths.** Citations must be maximally specific:
  `file:lineN-M` ideal; bare directory only if the whole dir IS the
  artifact; subtree paths invalid.

The canonical fragment with full text:
[`docs/CRUCIBLE-CLAUDE-MD.md`](./docs/CRUCIBLE-CLAUDE-MD.md).

---

## Activation is opt-in

A user-scope install does **not** enforce in every project. Hooks are silent
no-ops unless `${CLAUDE_PROJECT_DIR}/.crucible/active` exists. This was a
deliberate v0.1.1 fix after the original design broke unrelated workflows.

Three escape hatches if you ever need out:

| Method | Scope |
|---|---|
| `/crucible:disable` | This project (clean opt-out) |
| `touch .crucible/disabled` | This project (overrides active) |
| `CRUCIBLE_DISABLE=1 claude` | One shell session |

The Stop-hook refusal message lists all four hatches inline so you never
have to remember.

Full lifecycle: [`INSTALL.md`](./INSTALL.md#activation-lifecycle).

---

## Refusal is a feature

When evidence is missing or oracles BLOCK, Crucible writes a structured
`REFUSAL.md` and stops. **There is no override flag. There is no
force-complete.** A refusal is not a bug — it's the system functioning
correctly.

The refusal lists exactly which MSCs failed, with cited evidence paths and a
machine-readable delta plan. Run `/crucible:remediate` and Crucible
auto-generates a focused fix plan that targets only the failing criteria.

If `autopilot` exits REFUSED at `--max-attempts`, the surviving cited gaps
are real defects in the underlying system — not transient agent failures.
Take the refusal to the team that owns the system.

Recovery playbook: [`docs/USAGE.md#8-refusal-recovery-playbook`](./docs/USAGE.md#8-refusal-recovery-playbook).

---

## Status

| Version | Date | Highlights |
|---|---|---|
| **0.3.0** | 2026-04-27 | Comprehensive docs (`docs/OVERVIEW.md`, `docs/USAGE.md`); README rewritten as top-of-funnel; setup-mechanism shipped (`scripts/`, `skills/setup/`, `templates/rules/`) — **this release** |
| 0.2.1 | 2026-04-26 | Documented 14 commands shipped silently in 0.2.0 |
| 0.2.0 | 2026-04-25 | PRD gap remediation (16/21 closed); 5 new top-level commands; 4 declarative rules |
| 0.1.1 | 2026-04-25 | Critical opt-in fix: hooks were enforcing globally and breaking unrelated projects |
| 0.1.0 | 2026-04-25 | Initial release |

Full history: [`CHANGELOG.md`](./CHANGELOG.md).

---

## License

[MIT](./LICENSE) © Nick Krzemienski

---

## Build provenance

Crucible was itself built under its own discipline. Sixteen verification
gates (VG-0 through VG-15) plus reviewer-consensus + oracle-quorum gated
its delivery. The full build evidence package — including 26 cited
upstream sources, dual-path install receipts, four robust trials,
session-log audits with line citations, three independent reviewer
reports, and three Oracle audit reports — lives at
[`../evidence/`](../evidence/) (in this repo, alongside the plugin).

This is the longest possible answer to "does it work?" — the system you're
about to install was held to the same standard it imposes on yours.
