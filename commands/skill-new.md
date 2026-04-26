---
name: skill-new
description: Scaffold a new Crucible skill. Creates skills/<name>/SKILL.md with proper frontmatter, evidence-path conventions, refusal modes section, and an optional scripts/ subdir. Plugin reload required after to surface the new skill.
allowed-tools: Read, Write, Bash
---

# /crucible:skill-new

Scaffold a new `crucible:<name>` skill. Used to extend Crucible without manual
file plumbing.

## Usage

```
/crucible:skill-new <name> [--description "<one-line>"] [--with-scripts]
```

- `<name>` — kebab-case (`my-checker`, `audit-helper`); becomes `crucible:<name>`
- `--description` — short description used in frontmatter and the skill picker
- `--with-scripts` — create `skills/<name>/scripts/` with a `.gitkeep`

## Pipeline

### Step 1 — Validate name
- Reject if not kebab-case (regex `^[a-z][a-z0-9-]*$`)
- Reject if `skills/<name>/` already exists; suggest a different name

### Step 2 — Create skill directory
```bash
mkdir -p "${CLAUDE_PLUGIN_ROOT}/skills/<name>"
[[ "$WITH_SCRIPTS" == "1" ]] && { mkdir -p "${CLAUDE_PLUGIN_ROOT}/skills/<name>/scripts"; touch "${CLAUDE_PLUGIN_ROOT}/skills/<name>/scripts/.gitkeep"; }
```

### Step 3 — Write SKILL.md
Use the Write tool to create `skills/<name>/SKILL.md` with the template below,
substituting `<name>` and `<description>`.

#### Template

```markdown
---
name: <name>
description: <description>
---

# Crucible <Title-Case-Name>

<One-paragraph statement of what this skill does and when to use it.>

## When to invoke

- <Trigger condition 1>
- <Trigger condition 2>

## Pipeline

1. <Step>
2. <Step>
3. <Step>

## Output

<Required evidence path under evidence/<this-skill>/, what's produced, what's
required for downstream consumption.>

## Refusal modes

- <When this skill refuses to produce a verdict>
- <How to remediate>

## Iron Rule reminder

This skill produces evidence from the real system. No mocks, fixtures, or
hand-written transcripts. If real-system access is unavailable, refuse rather
than fabricate.
```

### Step 4 — Tell the user to reload
After scaffolding, print:

```
✓ Skill scaffolded at skills/<name>/SKILL.md
  Reload Claude Code to discover it (or re-install: claude plugin update crucible@crucible-local).
  Then invoke as /crucible:<name>.
```

## Refusal modes

- `<name>` invalid → refuse with regex hint
- `skills/<name>/` already exists → refuse, suggest rename
- `${CLAUDE_PLUGIN_ROOT}` not set → refuse, hint to run inside Claude Code with the plugin loaded

## What this command does NOT do

- Does NOT register the skill in any global index — Claude Code auto-discovers from `skills/*/SKILL.md`
- Does NOT auto-invoke the new skill
- Does NOT scaffold scripts beyond an empty `scripts/` dir; the user fills those in
