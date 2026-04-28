# Crucible — Usage Guide

> *What survives the test, ships.*

This is the practical manual. If you want concepts and architecture, read
[`OVERVIEW.md`](./OVERVIEW.md). If you want install steps, read
[`../INSTALL.md`](../INSTALL.md). If you want the canonical CLAUDE.md fragment
that `/crucible:setup` installs, read [`./CRUCIBLE-CLAUDE-MD.md`](./CRUCIBLE-CLAUDE-MD.md).

---

## Table of contents

1. [60-second tour](#1-60-second-tour)
2. [First-run lifecycle](#2-first-run-lifecycle)
3. [Three working examples](#3-three-working-examples)
4. [Command reference (all 19)](#4-command-reference-all-19)
5. [Skill reference (all 12)](#5-skill-reference-all-12)
6. [Subagent reference (all 11)](#6-subagent-reference-all-11)
7. [Hook reference (all 4)](#7-hook-reference-all-4)
8. [Refusal recovery playbook](#8-refusal-recovery-playbook)
9. [Authoring extensions](#9-authoring-extensions)
10. [Common workflows](#10-common-workflows)
11. [Troubleshooting](#11-troubleshooting)
12. [FAQ](#12-faq)

---

## 1. 60-second tour

```bash
# install
claude plugin marketplace add krzemienski/crucible
claude plugin install crucible@crucible-local

# set up (once per project)
cd my-project
/crucible:setup --local

# work
/crucible:forge "Add /healthz endpoint that returns {status:ok}"

# if it refuses
/crucible:remediate          # apply delta plan
/crucible:forge              # retry

# escape hatches if stuck
/crucible:disable            # opt out cleanly
touch .crucible/disabled     # nuclear opt-out
CRUCIBLE_DISABLE=1 claude    # one-shell escape
```

That's it. Read on for everything underneath.

---

## 2. First-run lifecycle

The full happy path from "no plugin installed" to "first task COMPLETE."

### Step 1 — Install (once per machine)

```bash
claude plugin marketplace add krzemienski/crucible
claude plugin install crucible@crucible-local
```

Verify:

```bash
claude plugin list | grep crucible
# crucible@crucible-local  Status: ✔ enabled
```

### Step 2 — Set up (once per project)

```bash
cd ~/code/my-api
/crucible:setup --local
```

What `/crucible:setup --local` does:

1. **Phase 1 — Install CLAUDE.md block.** Composes
   `docs/CRUCIBLE-CLAUDE-MD.md` from the four canonical rule fragments and
   appends it to your project's `./CLAUDE.md` between markers
   `<!-- CRUCIBLE:START -->...<!-- CRUCIBLE:END -->`. If a marker block
   already exists, it's replaced (idempotent). Backup is written to
   `./CLAUDE.md.crucible-backup-<timestamp>`.
2. **Phase 2 — Activate.** Creates `.crucible/active` sentinel.
3. **Phase 3 — Verify.** Runs `/crucible:doctor`'s nine checks.
4. **Phase 4 — Welcome.** Prints next-step guidance.

Variants:

- `/crucible:setup --global` — install into `~/.claude/CLAUDE.md` instead.
- `/crucible:setup --force` — overwrite an existing marker block (used after
  rule-template changes).
- `/crucible:setup --uninstall` — remove the marker block cleanly.

If you'd rather start from a fully bootstrapped project (with the standard
16-subdir `evidence/` tree pre-created), use `/crucible:stack-new` instead —
it calls `/crucible:setup` internally and adds the evidence scaffold.

### Step 3 — Run a task

```
You: /crucible:forge
     Add a GET /healthz endpoint to my FastAPI service that returns
     {"status":"ok"} with HTTP 200.
```

Crucible runs the 11-phase pipeline (10 numbered + Phase 2.5 skill-enrichment, v0.4+). You'll see (abridged):

```
[1/10] codebase-analysis ........ ✓ evidence/codebase-analysis/<id>/SUMMARY.md
[2/10] documentation-research .... ✓ evidence/documentation-research/<id>/SUMMARY.md
[3/10] planning .................. ✓ evidence/oracle-plan-reviews/<id>/plan.md
[4/10] oracle plan-review ........ ✓ APPROVED (3/3) — proceeding
[5/10] execute ................... ✓ src/routes/health.py written
[6/10] validation ................ ✓ evidence/validation-artifacts/<id>/step-03-curl-healthz.txt
[7/10] evidence-indexing ......... ✓ all dirs indexed
[8/10] reviewer-consensus ........ ✓ UNANIMOUS PASS (a/b/c)
[9/10] oracle-quorum ............. ✓ APPROVED (3/3, 0 blockers)
[10/10] completion-gate .......... ✓ overall=COMPLETE
```

Stop hook fires on session end → exit 0 (allowed). Done.

### Step 4 — If it refuses

```
[10/10] completion-gate .......... ✗ REFUSED
  cited gaps:
    - MSC-2: route registered? evidence path empty
  see: evidence/completion-gate/REFUSAL.md
```

```
You: /crucible:remediate
```

Crucible reads `REFUSAL.md`, produces a delta plan touching only MSC-2,
executes it, and prepares the next forge iteration. Re-run:

```
You: /crucible:forge
```

Or use `/crucible:autopilot` from the start — it loops up to 3 attempts
automatically.

---

## 3. Three working examples

Complete walkthroughs of three real workflows.

### Example A — Add an HTTP endpoint (green path)

**Task:** add `GET /healthz` to a FastAPI service.

```
You: /crucible:forge
     Add a GET /healthz endpoint to my FastAPI service that returns
     {"status":"ok"} with HTTP 200.

Crucible — phase 1 (codebase-analysis):
  Dispatching codebase-analyst subagent...
  → evidence/codebase-analysis/20260427T145600Z/SUMMARY.md
    repo: FastAPI, src/main.py creates app, src/routes/ holds 3 routers

Crucible — phase 2 (documentation-research):
  Dispatching documentation-researcher subagent...
  → evidence/documentation-research/20260427T145630Z/SUMMARY.md
    cited 4 FastAPI sources (decorators, response_model, status_code, JSONResponse)

Crucible — phase 2.5 (skill-enrichment, NEW v0.4):
  Dispatching skill-discoverer subagent...
  Walking 4 scopes: ~/.claude/skills/, ~/.claude/plugins/cache/**/skills/,
                    ./.claude/skills/, ./crucible-plugin/skills/
  Enumerated 869 SKILL.md files. Scored against task brief.
  → evidence/skill-enrichment/20260427T145700Z/INDEX.md
    Top 5 ranked candidates (overlap≥2, score≥0.10):
      1. backend-development         score 0.5714 overlap 4
      2. ck:python-best-practices    score 0.4286 overlap 3
      3. fastapi-routes              score 0.4286 overlap 3
      4. api-design                  score 0.2857 overlap 2
      5. ck:debug                    score 0.2857 overlap 2

Crucible — phase 3 (planning):
  Dispatching planner subagent (consumes skill-enrichment INDEX)...
  → evidence/oracle-plan-reviews/20260427T145700Z/plan.md

  MSCs:
    MSC-1: src/routes/health.py exists with @router.get("/healthz") decorator
           cite: src/routes/health.py
    MSC-2: route registered in src/main.py via app.include_router(health.router)
           cite: src/main.py:42-46
    MSC-3: curl localhost:8000/healthz returns HTTP 200 with body {"status":"ok"}
           cite: evidence/validation-artifacts/.../step-03-curl-healthz.txt

Crucible — phase 4 (oracle plan-review):
  Dispatching 3 oracles...
  → oracle-1: APPROVE  oracle-2: APPROVE  oracle-3: APPROVE
  → quorum: 3/3, 0 blockers — proceeding

Crucible — phase 5 (execute):
  Writing src/routes/health.py...
  Editing src/main.py to register router...
  → both writes accepted by PreToolUse hook (no test/mock paths)

Crucible — phase 6 (validation):
  Dispatching validator subagent...
  → starting service: uvicorn src.main:app &
  → curl localhost:8000/healthz
  → captured stdout: HTTP/1.1 200 OK ... {"status":"ok"}
  → evidence/validation-artifacts/20260427T145820Z/step-03-curl-healthz.txt

Crucible — phase 7 (evidence-indexing):
  Updated 8 INDEX.md files

Crucible — phase 8 (3-reviewer consensus):
  → reviewer-a (completeness): PASS — all 3 MSCs cited, files non-empty
  → reviewer-b (integrity): PASS — curl output matches expected
  → reviewer-c (iron-rule): PASS — no test files, no mocks
  → decision: UNANIMOUS PASS

Crucible — phase 9 (3-oracle quorum):
  → oracle-1: APPROVE  oracle-2: APPROVE  oracle-3: APPROVE
  → 3/3, 0 blockers

Crucible — phase 10 (completion-gate):
  SEAL    MSC-1  src/routes/health.py
  SEAL    MSC-2  src/main.py:42-46
  SEAL    MSC-3  evidence/validation-artifacts/.../step-03-curl-healthz.txt
  APPROVE consensus  evidence/reviewer-consensus/decision.md
  APPROVE quorum     evidence/final-oracle-evidence-audit/decision.md
  overall: COMPLETE
  → exit 0 — Stop hook will allow session end
```

### Example B — Refusal then autopilot recovery

**Task:** replace MD5 with SHA-256 across an auth module.

```
You: /crucible:autopilot
     Replace MD5 with SHA-256 in src/auth/. The system must continue to
     authenticate existing users (their stored hashes will need migration).

Crucible — attempt 1 of 3:
  ... runs phases 1-9 ...

Crucible — phase 10 (completion-gate):
  SEAL    MSC-1  src/auth/hash.py:14 (sha256 import)
  SEAL    MSC-2  src/auth/hash.py:22 (hash_password uses sha256)
  REFUSED MSC-3  evidence/validation-artifacts/.../step-04-grep-md5.txt
                 grep -rn "md5" src/auth/ returned 2 hits in src/auth/migrations/
  REFUSED MSC-4  evidence/validation-artifacts/.../step-05-login-existing.txt
                 existing user "alice@test.com" failed authentication
  overall: REFUSED — see REFUSAL.md

Crucible — autopilot remediation:
  Reading REFUSAL.md...
  Dispatching planner for delta plan covering MSC-3, MSC-4...
  → delta plan written

Crucible — attempt 2 of 3:
  ... applies delta: removes residual MD5 in migrations + adds dual-hash
      check during 30-day rotation window ...
  ... runs phases 1-9 again on updated tree ...

Crucible — phase 10 (completion-gate):
  SEAL    MSC-1..MSC-4 (all 4)
  APPROVE consensus  UNANIMOUS PASS
  APPROVE quorum     APPROVED (3/3)
  overall: COMPLETE
  → autopilot exits — task done
```

### Example C — A refusal you cannot retry through

**Task:** verify an API meets a SLA without modifying it.

```
You: /crucible:validate
     Verify GET /api/v1/orders returns p95 < 200ms under 100 RPS.

Crucible — validation-only mode:
  Dispatching validator subagent...
  → producing markdown checklist with 5 items
  Iron Rule: 0 Write/Edit calls allowed

Validator output (markdown):
  - [ ] step-01: capture baseline RPS via wrk -t4 -c100 -d30s
  - [ ] step-02: parse latency histogram via wrk2's --latency flag
  - [ ] step-03: assert p95 < 200ms or REFUSE with cited measurements
  ...

You execute the 5 steps manually (this skill is non-mutating)...

You: /crucible:completion-gate

Crucible:
  SEAL    MSC-1  evidence/validation-artifacts/.../step-01-wrk.txt (baseline 287rps)
  REFUSED MSC-3  evidence/validation-artifacts/.../step-03-p95.txt
                 measured p95=312ms, target was <200ms
  overall: REFUSED — see REFUSAL.md

This is a real defect in the system, not in your task definition. There is
nothing to remediate at the plugin level. The Crucible refusal is the
evidence you take to the team that owns the API.
```

---

## 4. Command reference (all 19)

Each command has frontmatter declaring `allowed-tools`. Some are read-only
(safe to run anywhere); others are read-write (gated by hooks).

### Tier 1 — Orchestrators

#### `/crucible:forge <task>`

End-to-end Crucible pipeline. The conductor.

```
/crucible:forge "Add a /healthz endpoint to my FastAPI service"
```

Runs phases 1-10. Halts on first refusal. The 80% case for any
change-producing work.

#### `/crucible:autopilot <task> [--max-attempts N]`

`forge` in a refusal-driven retry loop.

```
/crucible:autopilot "Replace MD5 with SHA-256 across the auth module" --max-attempts 4
```

Default `--max-attempts=3`. Iron Rule preserved at every iteration. Use when
you expect a multi-step remediation cycle.

#### `/crucible:remediate`

Read `REFUSAL.md`, produce a delta plan covering only failing MSCs, execute
it, prepare the next iteration.

```
/crucible:remediate
```

Used inside autopilot but also runnable standalone. Will refuse if no
`REFUSAL.md` exists.

#### `/crucible:resume`

Resume a halted forge or autopilot run by inspecting the evidence tree (the
tree IS the state — there's no separate state file).

```
/crucible:resume
```

Useful after a session crash, restart, or context overflow.

#### `/crucible:trial <name> <task>`

Run forge inside `evidence/robust-trials/trial-NN/<name>/`. Fulfills the
robust-trial contract — labeled, isolated, reproducible runs.

```
/crucible:trial healthz-baseline "Add /healthz endpoint"
```

Use when you need a named, archivable forge run (releases, audits, regression
suites).

### Tier 2 — Authoring

#### `/crucible:setup [--local|--global] [--force|--uninstall]`

Install or refresh Crucible's CLAUDE.md rule block. Run once per project.

```
/crucible:setup --local            # default: install into ./CLAUDE.md
/crucible:setup --global           # install into ~/.claude/CLAUDE.md
/crucible:setup --force            # overwrite existing marker block
/crucible:setup --uninstall        # remove marker block cleanly
```

Idempotent. Writes `~/.claude/.crucible-config.json` to track sentinel state.

#### `/crucible:stack-new`

Bootstrap a project for Crucible — creates `evidence/` tree (16 standard
subdirs + INDEX.md), `.crucible/active` sentinel, and runs `/crucible:setup
--local`. The "first time using Crucible in this project" command.

```
/crucible:stack-new
```

#### `/crucible:skill-new <name>`

Scaffold a new skill at `skills/<name>/SKILL.md` with proper frontmatter,
evidence-path conventions, and refusal-modes section.

```
/crucible:skill-new database-migration-validation
```

Plugin reload required after to surface the new skill.

#### `/crucible:agent-new <name> --role <role>`

Scaffold a new subagent at `agents/<name>.md`. Roles: `planner`, `reviewer`,
`oracle`, `validator`, `analyst`, `generic`.

```
/crucible:agent-new payment-validator --role validator
```

Each role auto-fills tool grants (e.g. validators get Read/Bash, oracles get
Read/Grep/Glob only).

#### `/crucible:rule-new <name>`

Scaffold a new rule fragment under `templates/rules/<name>.md`, then
recompose `docs/CRUCIBLE-CLAUDE-MD.md`. Reminder to re-install with
`/crucible:setup --force`.

```
/crucible:rule-new no-network-mocks
```

#### `/crucible:hook-new <name> --event <event>`

Scaffold a new hook at `bin/<name>.sh` with canonical stdin/stderr/exit-code
protocol. Patches `hooks/hooks.json` to register it. Events:
`SessionStart`, `PreToolUse`, `PostToolUse`, `Stop`.

```
/crucible:hook-new block-binary-deletion --event PreToolUse
```

#### `/crucible:command-new <name>`

Scaffold a new top-level slash command at `commands/<name>.md`.

```
/crucible:command-new ship
```

### Tier 3 — Inspection (read-only)

#### `/crucible:doctor`

9-check installation + activation health audit. **Run after every install or
update.**

```
/crucible:doctor
```

Output: 9 ✓/⚠/✗ rows covering manifest, install record, manifest equivalence
(commands/skills/agents/hooks/rules), SDK reachability, activation sentinel,
cache freshness, setup sentinel, CLAUDE.md markers, setup script integrity.

#### `/crucible:status`

Pretty-print the current completion-gate state. Reads
`evidence/completion-gate/report.json` and renders the MSC table, reviewer
consensus, oracle quorum, and overall verdict.

```
/crucible:status
```

Refuses if no gate has been run in this project.

#### `/crucible:explain [<command>]`

Print the DAG of any pipeline — which skills/agents/hooks fire, in what
order, with what evidence outputs.

```
/crucible:explain forge
/crucible:explain autopilot
/crucible:explain                    # print DAG of all pipelines
```

Read-only education tool. Useful for "what does X actually do?" questions.

#### `/crucible:fix`

Idempotent auto-repair for common drift.

```
/crucible:fix
```

What it does:
- Regenerate stale `evidence/INDEX.md` files from current contents.
- Sync `plugin.json` ↔ `marketplace.json` versions if drifted.
- Re-create missing `evidence/` standard subdirs.
- Re-link orphaned trial directories.

**Creates only; never deletes.** Safe to run any time.

#### `/crucible:graph [--run-id <iso>]`

Render the current evidence-tree state as a Mermaid graph. Sealed MSCs
green; pending blue; failed red.

```
/crucible:graph                       # whole tree
/crucible:graph --run-id 20260427T145600Z
```

### Tier 0 — Activation primitives (skill-backed)

These are the building blocks Tier-1 conductors compose. Most dispatch to same-named skills under `skills/<name>/` rather than file-backed commands — Claude Code resolves `/crucible:<skill-id>` to the skill when no command file exists. `/crucible:plan-and-execute`, `/crucible:validate`, and `/crucible:audit` are the exceptions: file-backed in `commands/` and counted in this section's "all 19" total. The remaining 10 entries below are pure skill invocations.

| Command | What it does |
|---|---|
| `/crucible:enable` | Create `.crucible/active`. Activate hooks. Idempotent. |
| `/crucible:disable` | Remove `.crucible/active`. Hooks become silent. Preserves `evidence/`. |
| `/crucible:planning` | Run planner subagent → `evidence/oracle-plan-reviews/<id>/plan.md` |
| `/crucible:validation` | Run validator subagent → markdown checklist; produces NO writes |
| `/crucible:codebase-analysis` | Run codebase-analyst → `evidence/codebase-analysis/<id>/` |
| `/crucible:documentation-research` | Run docs-researcher → `evidence/documentation-research/<id>/` |
| `/crucible:evidence-indexing` | Refresh every `INDEX.md` and `README.md` under `evidence/` |
| `/crucible:session-log-audit` | Audit JSONL session log; cite hook firings by line |
| `/crucible:oracle-review` | Convene 3 oracles for plan-review OR final-evidence-audit |
| `/crucible:completion-gate` | Evaluate gate; emit `report.json` (COMPLETE or REFUSED) |
| `/crucible:plan-and-execute` | Comprehensive mode: planning → review → execute (no audit phases) |
| `/crucible:validate` | Validation-only mode (alias of `/crucible:validation` flow) |
| `/crucible:audit` | Independent post-hoc audit run; convenes 3 oracles only |

Use these directly for fine-grained control or when debugging a specific phase.

---

## 5. Skill reference (all 12)

Skills are composable capability units. Tier-1 commands (`forge`, `autopilot`)
chain skills; you can also invoke them directly.

| Skill | When to invoke | What it produces |
|---|---|---|
| `crucible:setup` | Once per project, before any other Crucible work | CLAUDE.md marker block + `~/.claude/.crucible-config.json` + `.crucible/active` |
| `crucible:enable` | Re-activate after `/crucible:disable` | `.crucible/active` sentinel |
| `crucible:disable` | Opt out of enforcement temporarily | Removes `.crucible/active`; preserves `evidence/` |
| `crucible:codebase-analysis` | Before planning in an unfamiliar repo | `evidence/codebase-analysis/<id>/SUMMARY.md` |
| `crucible:documentation-research` | When SDKs/APIs/specs are involved | `evidence/documentation-research/<id>/sources/*.md` + `SUMMARY.md` |
| **`crucible:skill-enrichment`** (NEW v0.4) | After docs-research, before planning — Phase 2.5 of forge | `evidence/skill-enrichment/<id>/INDEX.md` (5–10 ranked skill candidates) + `CANDIDATES.md` (rationale) + `SKIPPED.md` (audit trail) + `raw-inventory.txt`. Refuses with `REFUSAL.md` for orthogonal-domain prompts. |
| `crucible:planning` | Before any change-producing work | `evidence/oracle-plan-reviews/<id>/plan.md` (with MSCs + Required Skills section, v0.4+) |
| `crucible:validation` | To audit a system without modifying it | Markdown checklist; produces zero writes |
| `crucible:evidence-indexing` | After any evidence change | Refreshed `INDEX.md` for every `evidence/` subdir |
| `crucible:session-log-audit` | After a real CC session | `evidence/session-logs/<id>/INDEX.md` with line citations |
| `crucible:oracle-review` | Pre-execution plan-review OR post-execution evidence-audit | Per-oracle verdicts + `decision.md` |
| `crucible:completion-gate` | At the very end of a task | `evidence/completion-gate/report.json` (COMPLETE or REFUSED) |

### Detailed skill notes

**`crucible:planning`** — the planner subagent consumes
codebase-analysis + documentation-research outputs. It refuses to start
execution without an Oracle plan-review approval. If you want to plan
without enforcing oracle pre-approval, use the parent CC's planner instead.

**`crucible:validation`** — produces a markdown checklist and exits. It is
the ONLY skill in Crucible that is required to be non-mutating. Every other
skill may write to `evidence/`; validation must produce zero `Write`/`Edit`
tool calls. The session-log audit verifies this constraint by counting
writes attributed to validation runs.

**`crucible:completion-gate`** — has NO override flag. The skill's identity
*is* refusal. If MSCs are missing, you do not pass. You do not "talk past
this." You fix the cited gap.

---

## 6. Subagent reference (all 11)

Subagents are dispatched via `Task` with their `subagent_type`. Each runs in
an isolated context with restricted tools.

| Subagent | Role | Tools |
|---|---|---|
| `planner` | Build the executable plan with MSCs + Required Skills section (v0.4+) | Read, Grep, Glob, Bash, Write, Edit, Task |
| `codebase-analyst` | Build repo-wide context before modification | Read, Grep, Glob, Bash |
| `documentation-researcher` | Fetch + cite upstream docs | Read, WebFetch, Bash, Write |
| **`skill-discoverer`** (NEW v0.4) | Phase 2.5: discover + rank relevant skills from user's full ecosystem | Read, Grep, Glob, Bash |
| `validator` | Exercise real system, capture artifacts | Read, Grep, Glob, Bash |
| `reviewer-a` | Completeness check | Read, Grep, Glob |
| `reviewer-b` | Integrity check (content matches claim) | Read, Grep, Glob |
| `reviewer-c` | Iron-Rule compliance | Read, Grep, Glob |
| `oracle-auditor-1` | Completeness + citation audit | Read, Grep, Glob |
| `oracle-auditor-2` | Structural integrity audit | Read, Grep, Glob, Bash |
| `oracle-auditor-3` | Adversarial skepticism | Read, Grep, Glob, Bash |

### Why three reviewers AND three oracles

Different orientations. Reviewers ask "is this evidence package internally
sound?" Oracles ask "does this evidence cover the contract?" A package can
fail one and pass the other; both must pass for COMPLETE.

### Why reviewers/oracles cannot share context

If `reviewer-a` saw `reviewer-b`'s verdict, the second reviewer's
independence collapses — the model's prior would anchor on the first
reviewer's framing. The Task-based subagent dispatch enforces context
isolation mechanically.

---

## 7. Hook reference (all 4)

Defined in `hooks/hooks.json`. Each fires on the named event. All four start
with an activation guard — if `.crucible/active` is missing, they're silent
no-ops.

### `SessionStart` → `bin/session-start.sh`

Fires once per session. Detects CLI vs SDK origin. Writes a session receipt
to `evidence/session-receipts/<session-id>.json`.

### `PreToolUse` (matcher: `Write|Edit|Bash`) → `bin/pre-task.sh`

The Iron Rule enforcer. Reads tool call from stdin. For Write/Edit:
rejects (exit 2) on test/mock paths. For Bash: rejects on test-framework
invocations. Writes a denial note to `evidence/session-receipts/<id>.json`.

### `PostToolUse` (matcher: `Write|Edit|Bash`) → `bin/post-task.sh`

Idempotent receipt sealer. Captures tool name, target, exit status, elapsed
time. Append-only.

### `Stop` (matcher: `*`) → `bin/completion-attempt.sh`

The gate. Checks `evidence/completion-gate/report.json`. Returns exit 2 if
missing or `overall != "COMPLETE"`. Returns exit 0 only on COMPLETE. The
blocking message lists all four escape hatches.

### Performance budget

- Per-hook overhead: p50 < 8ms, p95 < 25ms, p99 < 60ms
- Per-tool-call aggregate: p95 < 40ms (Pre + Post combined)

Reference measurements: `evidence/performance/SUMMARY.md` (300 invocations
on macOS bash 3.2.57).

---

## 8. Refusal recovery playbook

When Crucible refuses, the refusal is structured. Here's how to read it and
respond.

### Step 1 — Read `REFUSAL.md`

```bash
cat evidence/completion-gate/REFUSAL.md
```

The schema:

```markdown
# Crucible Refusal — <run-id>

**Phase:** <which phase failed>
**Triggered by:** <agent or hook>

## Failing criteria
| ID | Status | Citation | Reason |
| MSC-7 | FAIL | path:line | reason |
| MSC-12 | MISSING | (no file) | reason |

## Cited blockers (from oracles)
- ...

## Recommended remediation
<delta plan>
```

### Step 2 — Classify the failure

| Failure type | Response |
|---|---|
| MSC FAIL with explainable cause | `/crucible:remediate` — autoplanner generates delta plan |
| MSC MISSING | The skill that should have produced the file didn't run; re-run that skill |
| Oracle blocker | The plan or evidence has a structural defect; fix or expand the plan |
| Reviewer-c Iron-Rule violation | A test file or mock leaked into the tree; remove and re-run |
| Reviewer-b integrity failure | An evidence file's content doesn't match its claim; rebuild it |

### Step 3 — Apply the remediation

```
/crucible:remediate              # apply auto-generated delta plan
/crucible:forge                  # retry
```

Or from the start: `/crucible:autopilot <task>` to loop automatically.

### Step 4 — If autopilot exits REFUSED at max-attempts

The MSCs that survived all 3 attempts are real defects in your task definition.
The plugin cannot remediate them. Take the final `REFUSAL.md` to the team that
owns the system. The cited gaps are the truth.

### Step 5 — Escape hatches (if the refusal is wrong for your context)

If you need out *right now*:

```bash
/crucible:disable                 # clean opt-out for this project
touch .crucible/disabled          # nuclear opt-out (overrides active)
CRUCIBLE_DISABLE=1 claude         # one-shell escape
rm .crucible/active               # manual equivalent of /crucible:disable
```

---

## 9. Authoring extensions

Crucible is extensible at every layer. Each new piece comes with a scaffolder.

### New skill

```
/crucible:skill-new my-skill
```

Creates `skills/my-skill/SKILL.md` with:
- Frontmatter (name, description, allowed-tools)
- Evidence-path conventions (`evidence/my-skill/<run-id>/`)
- Refusal modes section (what makes this skill refuse)

After creation: restart Claude Code or run `/plugin reload` for the new skill
to be discoverable.

### New subagent

```
/crucible:agent-new my-validator --role validator
```

Roles: `planner`, `reviewer`, `oracle`, `validator`, `analyst`, `generic`.
Each role pre-fills appropriate tool grants and frontmatter.

### New rule

```
/crucible:rule-new no-network-mocks
```

Scaffolds `templates/rules/no-network-mocks.md`. After:
1. Edit the template to your rule.
2. Run `/crucible:setup --force` to recompose `docs/CRUCIBLE-CLAUDE-MD.md`
   and re-install the marker block.

### New hook

```
/crucible:hook-new block-binary-deletion --event PreToolUse
```

Scaffolds `bin/block-binary-deletion.sh` and patches `hooks/hooks.json`.
The script template starts with an activation guard and a stdin JSON read.

### New command

```
/crucible:command-new ship
```

Scaffolds `commands/ship.md` with frontmatter and a pipeline section.

---

## 10. Common workflows

### Workflow: "I want to add a feature with full discipline"

```
/crucible:setup --local         # once per project
/crucible:forge "<task>"        # 80% case
```

### Workflow: "I want to verify a system without changing it"

```
/crucible:validate "<claim>"
# manually execute the produced checklist
/crucible:completion-gate
```

### Workflow: "I want to audit existing evidence"

```
/crucible:audit
```

Convenes 3 oracles only. Read-only. Useful for periodic re-audits or
third-party attestation runs.

### Workflow: "I'm shipping a release and need a labeled trial"

```
/crucible:trial release-v2.4.0 "<task>"
```

Output goes under `evidence/robust-trials/trial-NN/release-v2.4.0/`.

### Workflow: "I want to know what /crucible:autopilot actually does"

```
/crucible:explain autopilot
```

Prints the DAG. Read-only.

### Workflow: "Something feels broken"

```
/crucible:doctor                # is the install ok?
/crucible:fix                   # auto-repair drift
/crucible:status                # is there a gate to look at?
/crucible:graph                 # what does the evidence tree look like?
```

### Workflow: "I want to leave a project but keep the evidence"

```
/crucible:disable               # removes .crucible/active; preserves evidence/
```

### Workflow: "Crucible is blocking a session and I'm not in a Crucible workflow"

This shouldn't happen post-v0.1.1 (opt-in is mandatory). But if it does:

```bash
# in order of preference:
/crucible:disable               # clean
touch .crucible/disabled        # nuclear
CRUCIBLE_DISABLE=1 claude       # per-shell
```

The Stop-hook refusal message lists all of these inline so you don't have
to remember.

---

## 11. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Hook Stop (Stop) error: REFUSED` | Crucible's gate is doing its job | `/crucible:status`, fix cited gaps, re-run |
| `Hook Stop (Stop) error` in unrelated project | `.crucible/active` exists by accident | `rm .crucible/active` or `touch .crucible/disabled` |
| `claude plugin install`: marketplace not found | `claude plugin marketplace add` not run | See `INSTALL.md` paths |
| Hooks don't fire | `bin/*.sh` not executable | `chmod +x ~/.claude/plugins/cache/crucible-local/crucible/<v>/bin/*.sh` |
| `evidence/evidence/` dir appears | Crucible <0.1.1 cwd bug | `claude plugin update crucible@crucible-local` |
| `/crucible:setup` prints "marker block not found" | Manual edit corrupted the markers | `/crucible:setup --force` |
| `/crucible:doctor` says "cache stale" | Source SHA != cache SHA | `claude plugin update crucible@crucible-local` |
| `/crucible:doctor` says "setup sentinel ABSENT" | First run; setup not yet executed | `/crucible:setup --local` (or `--global`) |
| Reviewer-c says "iron rule violation" | A test file leaked into evidence/ or src/ | Find it (`grep -r 'def test_' src/`), remove, re-run |
| Oracle says "MSC has no measurable PASS criterion" | Plan defines fuzzy MSCs | Edit plan to add specific cite paths and grep patterns |
| Forge halts at phase 4 with "BLOCKED" | Oracles rejected the plan | Read their cited blockers; refine plan |

### Verbose mode

Most commands accept `--verbose` for raw output:

```
/crucible:forge "<task>" --verbose
/crucible:doctor --verbose
```

### Reading the gate report directly

```bash
cat evidence/completion-gate/report.json | jq .overall
cat evidence/completion-gate/report.json | jq '.msc[] | select(.status != "PASS")'
```

---

## 12. FAQ

### Why is Crucible opt-in?

A user-scope plugin install used to enforce in *every* project, breaking
unrelated workflows. Since v0.1.1, hooks are silent unless
`.crucible/active` exists in the project root.

### Can I run Crucible against an existing project's evidence?

Yes. `/crucible:audit` runs the 3-oracle quorum against whatever's in
`evidence/`. Read-only. Useful for periodic re-validation or third-party
attestation.

### What if my project legitimately has tests?

Tests are not the target of Iron Rule. The PreToolUse hook rejects
*creating new test files within an active Crucible run* — because such
writes typically appear when an agent is trying to satisfy a missing-validation
gap with a fake. If your project has a pre-existing test suite, it's not
touched. If you genuinely want to write a new test, do it outside the
Crucible workflow (`/crucible:disable`, write the test, `/crucible:enable`).

### Can I customize MSCs for my project?

Yes — they come from your `/crucible:planning` invocation. The planner
subagent generates them based on your task description. You can also edit
the plan before approving (the oracle plan-review will catch unmeasurable
MSCs).

### Can I add custom rules?

Yes. `/crucible:rule-new <name>` scaffolds a fragment under
`templates/rules/`. Edit it; run `/crucible:setup --force` to recompose and
re-install the CLAUDE.md block.

### Does Crucible work with the Anthropic SDK (non-CLI)?

Yes. `bin/session-start.sh` detects SDK origin via
`CLAUDE_SESSION_ENTRYPOINT`, `CLAUDE_AGENT_SDK_VERSION`, or stdin
`entrypoint` field, and tags receipts with `origin: sdk`. The reference
build uses `claude_agent_sdk` 0.1.68; later versions are expected to work.

### What about CI?

Crucible's evidence package is exactly what you want in CI. After a forge
run completes:

```bash
tar -czf evidence-bundle.tgz evidence/
# upload as CI artifact
```

The bundle is self-describing; a reviewer can re-run
`/crucible:completion-gate` against the unpacked tree and reproduce the
verdict.

### Can two people run Crucible on the same project?

Yes — `evidence/` is append-only. Each run gets a unique ISO-8601 ID. Two
people running `/crucible:forge` against the same `<task>` produce two
separate run-id subdirectories under each `evidence/` subdirectory.

### How do I uninstall?

```bash
/crucible:setup --uninstall                      # removes CLAUDE.md block
/crucible:disable                                # removes .crucible/active
claude plugin uninstall crucible@crucible-local  # removes plugin
claude plugin marketplace remove crucible-local  # optional
```

`evidence/` is preserved. Delete it manually if desired.

### Where do I report a bug?

[https://github.com/krzemienski/crucible/issues](https://github.com/krzemienski/crucible/issues)

Include the output of `/crucible:doctor --verbose` and the contents of any
relevant `REFUSAL.md`.

---

## See also

- [`OVERVIEW.md`](./OVERVIEW.md) — concepts, architecture, philosophy
- [`CRUCIBLE-CLAUDE-MD.md`](./CRUCIBLE-CLAUDE-MD.md) — canonical CLAUDE.md fragment installed by `/crucible:setup`
- [`../INSTALL.md`](../INSTALL.md) — install paths, troubleshooting
- [`../CHANGELOG.md`](../CHANGELOG.md) — release history
- [`../README.md`](../README.md) — top-of-funnel overview
