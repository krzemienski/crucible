<!-- CRUCIBLE:START -->
## Crucible — Evidence-Gated Execution

When Crucible is active in this project (`.crucible/active` sentinel exists), the
following rules apply to every change-producing workflow. Rules are sourced from
the canonical fragments in `crucible-plugin/templates/rules/` and composed by
`/crucible:setup`. To regenerate this block, run `/crucible:setup --force`.

### Iron Rule (RL-1) — No mocks
Validation runs against real systems only. Forbidden: mocks, stubs, fakes, test
doubles, fixtures, test files (`*.test.*`, `*.spec.*`, `tests/`, `__tests__/`),
test frameworks, SDK substitutions, hand-written "expected" output presented as
actual output, mkdir-simulated installations.

Allowed: real CLI invocations with stdout/stderr captured verbatim, real HTTP
requests with response headers + body, real filesystem inspection of installed
artifacts, real session JSONL files written by Claude Code or the SDK.

### Cite or Refuse (RL-2)
Every PASS / FAIL / APPROVE / BLOCK verdict MUST cite a specific evidence file
path. A PASS verdict that lacks a citation is INVALID. Directory globs, prose
descriptions, and references to prior verdicts do NOT count as citations.

### Cite Paths (RL-4) — Specificity
Citations must be maximally specific:
- ✅ `evidence/session-logs/<id>/session.jsonl:42-58` (file + line range)
- ✅ `evidence/session-logs/<id>/INDEX.md` (file)
- ⚠️ `evidence/session-logs/<id>/` (directory — only if the whole dir IS the artifact)
- ❌ `evidence/` or `evidence/session-logs/` (too broad)

### No Self-Review (RL-3)
The agent that PRODUCED an artifact may NOT also REVIEW or APPROVE it.
Independence is structural, not advisory:
- Planner may not review its own plan → Oracle plan-review convenes separately
- Validator may not approve its own verdict → reviewer consensus required
- Reviewers/Oracles cannot write each other's verdicts
- The synthesizer (parent session) only aggregates raw verdicts; never reviews

### Refusal Discipline
When evidence is missing, write a structured `REFUSAL.md` and stop. There is no
override flag. There is no force-complete. Refusal is a feature.

### Workflow
- `/crucible:forge <task>` — end-to-end pipeline (recommended)
- `/crucible:autopilot <task>` — `forge` in a refusal-driven retry loop
- `/crucible:status` — current gate state
- `/crucible:doctor` — installation + activation health
- `/crucible:explain <command>` — show which skills/agents/hooks fire

### Kill switches (when blocked by mistake)
- `/crucible:disable` — remove `.crucible/active` cleanly
- `touch .crucible/disabled` — emergency override
- `CRUCIBLE_DISABLE=1 claude` — per-shell escape
<!-- CRUCIBLE:END -->
