---
name: command-new
description: Scaffold a new Crucible slash command at commands/<name>.md with proper frontmatter (name, description, allowed-tools), pipeline section, and refusal-modes section.
allowed-tools: Read, Write, Bash
---

# /crucible:command-new

Scaffold a new top-level slash command. Used to add new conductors / tools to
the plugin without manual file plumbing.

## Usage

```
/crucible:command-new <name> [--description "<one-line>"] [--allowed-tools "Read,Write,Bash,Task,Skill"]
```

- `<name>` — kebab-case; becomes `/crucible:<name>`
- `--description` — required; first sentence used in the slash-command picker
- `--allowed-tools` — comma-separated; defaults to `Read, Bash, Glob, Grep`

## Pipeline

### Step 1 — Validate
- `<name>` kebab-case
- `commands/<name>.md` doesn't exist
- `--description` is non-empty
- `<name>` doesn't collide with reserved Crucible slash commands (`enable`,
  `disable`, `setup`, `forge`, `autopilot`, etc.)

### Step 2 — Write template

```markdown
---
name: <name>
description: <description>
allowed-tools: <allowed-tools>
---

# /crucible:<name>

<One-paragraph statement of what this command does and when to use it.>

## Required activation

If this command requires `.crucible/active` (most do), say so here. If not,
explicitly state it can run without activation (rare — only for diagnostic
commands like /crucible:doctor).

## Pipeline

1. <Step>
2. <Step>
3. <Step>

## Output

<What the command prints on success and what evidence path it produced.>

## Refusal modes

- <When this command refuses>
- <How to remediate>

## Iron Rule

<This command operates against real systems. Cite real paths, refuse rather
than fabricate.>
```

### Step 3 — Tell user to reload

```
✓ Command scaffolded at commands/<name>.md
  Reload Claude Code or run: claude plugin update crucible@crucible-local
  Then invoke as /crucible:<name>.
```

## Refusal modes

- Invalid `<name>` → refuse with regex hint
- Name collision with reserved command → refuse, list reserved names
- File exists → refuse, suggest rename
- `--description` empty → refuse; first-sentence description is load-bearing
  for the slash-command picker UX

## Why this exists

Hand-authoring command frontmatter is error-prone. A missing `allowed-tools`
key means the command can't call the tools its pipeline requires; a missing
`description` makes the command invisible in the picker. Scaffolding via
this command guarantees the file lands shaped correctly.
