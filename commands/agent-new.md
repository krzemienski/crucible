---
name: agent-new
description: Scaffold a new Crucible subagent at agents/<name>.md with role-appropriate frontmatter and tool grants. Roles: planner, reviewer, oracle, validator, analyst, generic.
allowed-tools: Read, Write, Bash
---

# /crucible:agent-new

Scaffold a new subagent so Crucible can dispatch it via the Task tool.

## Usage

```
/crucible:agent-new <name> --role <planner|reviewer|oracle|validator|analyst|generic> [--description "<one-line>"]
```

## Pipeline

### Step 1 — Validate
- `<name>` must be kebab-case
- `--role` is required (no default — picking the right role is load-bearing)
- Reject if `agents/<name>.md` exists

### Step 2 — Pick template by role

| Role | Tools | Behavior |
|------|-------|----------|
| `planner` | Read, Glob, Grep, Bash, Edit, Write, Task | Produces plans; submits to oracle review; never reviews own plan |
| `reviewer` | Read, Grep, Glob | Read-only audit; emits PASS/FAIL with cited paths; never edits |
| `oracle` | Read, Grep, Glob, Bash (read-only checks) | Final adversarial audit; emits APPROVE/BLOCK with cited blockers |
| `validator` | Read, Bash, Glob, Grep | Real-system validation (curl, jq, exit codes); never mocks |
| `analyst` | Read, Grep, Glob, Bash | Codebase analysis only; no edits |
| `generic` | Read, Glob, Grep, Bash | Catch-all; explicit purpose required in frontmatter |

### Step 3 — Write `agents/<name>.md`

Frontmatter MUST include:
- `name: <name>`
- `description: <description>` — first sentence states role + when to invoke
- `tools: <comma-separated tool list per role table above>`

Body MUST include:
- One-paragraph role statement
- Inputs section (what evidence the agent reads)
- Outputs section (where it writes — single file path)
- Refusal modes (when it refuses to issue a verdict)
- Iron Rule reminder (if reviewer/oracle/validator)
- Independence reminder (if reviewer/oracle): "I do not see other reviewers' verdicts"

### Step 4 — Tell user to reload

```
✓ Agent scaffolded at agents/<name>.md (role: <role>)
  Reload Claude Code or run: claude plugin update crucible@crucible-local
  Then dispatch via Task tool with subagent_type="crucible:<name>".
```

## Refusal modes

- Invalid `<name>` → refuse with regex hint
- Missing `--role` → refuse; print the role table
- File already exists → refuse, suggest rename
- Role outside the supported list → refuse, list valid roles

## Why role-driven

Roles encode the Iron Rule's structural requirements. A reviewer with `Edit`
access could mutate evidence; an oracle without `Read` cannot audit; a planner
without `Task` cannot delegate. Picking the wrong tool list for a role
defeats Crucible's whole independence model. The role argument is the gate.
