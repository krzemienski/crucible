---
name: rule-new
description: Scaffold a new Crucible rule fragment under templates/rules/<name>.md, then recompose docs/CRUCIBLE-CLAUDE-MD.md so the new rule is included on next /crucible:setup. Reminder to re-install with --force.
allowed-tools: Read, Write, Edit, Bash
---

# /crucible:rule-new

Add a new rule to the Crucible canonical set. Rules ship as **CLAUDE.md
fragments** — they live in `templates/rules/`, get composed into
`docs/CRUCIBLE-CLAUDE-MD.md`, and are installed into the user's CLAUDE.md by
`/crucible:setup`.

## Usage

```
/crucible:rule-new <name> --rule-id <RL-N> [--scope "<comma-separated scopes>"] [--description "<one-line>"]
```

- `<name>` — kebab-case, e.g. `cite-or-refuse`
- `--rule-id RL-N` — sequence number, e.g. `RL-5` (next free)
- `--scope` — comma-separated list of which subagents/skills the rule applies to

## Pipeline

### Step 1 — Validate
- `<name>` kebab-case
- `<RL-N>` not already used (grep `templates/rules/*.md` and `docs/CRUCIBLE-CLAUDE-MD.md` for the ID)
- File doesn't exist

### Step 2 — Write `templates/rules/<name>.md`

```markdown
---
name: <name>
description: <description>
scope: <scope>
rule-id: <RL-N>
---

# Rule <RL-N> — <Title-Case-Name>

<One-paragraph rule statement.>

## What counts (or What is allowed)

- <example>

## What does NOT count (or What is forbidden)

- <example>

## Enforcement

- <Which agent/oracle audits this>
- <How the gate detects violation>

## Why

<Reference the PRD principle this rule operationalizes.>
```

### Step 3 — Recompose `docs/CRUCIBLE-CLAUDE-MD.md`

Append a condensed section between the existing markers, or update the
existing section if `<RL-N>` already appears. Use the format already in the
canonical fragment: `### <Title> (<RL-N>)` heading, 3-6 line summary.

The full long-form rule stays in `templates/rules/<name>.md` for reference;
only the condensed summary lands in CLAUDE.md.

### Step 4 — Notify user

```
✓ Rule scaffolded:
   Long-form: templates/rules/<name>.md
   Condensed: docs/CRUCIBLE-CLAUDE-MD.md (between markers)

To push the new rule into your CLAUDE.md, run:
   /crucible:setup --force

To activate it across all projects already configured:
   /crucible:setup --force --global
```

## Refusal modes

- `<RL-N>` already in use → refuse with the conflicting file path
- `templates/rules/<name>.md` exists → refuse, suggest rename
- Editing `docs/CRUCIBLE-CLAUDE-MD.md` would corrupt markers (missing START/END)
  → refuse, hint to run `/crucible:setup --force` first to repair

## Why long-form + condensed

The long-form file in `templates/rules/` exists for human authors and for
audits — it cites PRD sections, gives examples, explains enforcement. The
condensed version in `docs/CRUCIBLE-CLAUDE-MD.md` is what lands in the user's
CLAUDE.md. Two views, one source of truth, automatic recomposition on
`/crucible:setup`.
