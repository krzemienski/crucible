---
name: hook-new
description: Scaffold a new Claude Code hook for Crucible. Creates bin/<name>.sh with canonical stdin/stderr/exit-code protocol and patches hooks/hooks.json to register it. Supports SessionStart, PreToolUse, PostToolUse, Stop events.
allowed-tools: Read, Write, Edit, Bash
---

# /crucible:hook-new

Scaffold a hook script and register it in `hooks/hooks.json`. The Crucible hook
protocol is a strict subset of Claude Code's: read JSON from stdin, exit 0 on
allow, exit 2 + stderr on block.

## Usage

```
/crucible:hook-new <name> --event <SessionStart|PreToolUse|PostToolUse|Stop> [--matcher <glob>]
```

- `<name>` — kebab-case; becomes `bin/<name>.sh`
- `--event` — required; one of the four supported events
- `--matcher` — required for PreToolUse/PostToolUse (e.g., `"Write|Edit|Bash"`); default `"*"` for SessionStart/Stop

## Pipeline

### Step 1 — Validate
- Name kebab-case
- Event in {SessionStart, PreToolUse, PostToolUse, Stop}
- `bin/<name>.sh` doesn't exist
- For SessionStart/Stop, ignore `--matcher` and force `"*"`

### Step 2 — Write `bin/<name>.sh`

```bash
#!/usr/bin/env bash
# <name>.sh — Crucible <event> hook
# Reads tool-call JSON from stdin; exit 0 to allow, exit 2 to block.
# stderr is shown to the user when blocking. stdout is silent.

set -euo pipefail

# Read stdin (Claude Code provides hook context as JSON)
INPUT="$(cat)"

# Read .crucible/active sentinel — Crucible's opt-in gate
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
[ -f "$PROJECT_ROOT/.crucible/active" ] || exit 0   # silent if Crucible not active
[ -f "$PROJECT_ROOT/.crucible/disabled" ] && exit 0  # kill switch
[ "${CRUCIBLE_DISABLE:-}" = "1" ] && exit 0          # per-shell escape

# TODO: implement your check
# Example pattern — refuse on missing artifact:
#
# if ! [ -s "$PROJECT_ROOT/evidence/some-required-file.md" ]; then
#   echo "REFUSED by Crucible <name> hook." >&2
#   echo "Reason: evidence/some-required-file.md is missing or empty." >&2
#   echo "Remediation: <one-line>." >&2
#   exit 2
# fi

exit 0
```

`chmod +x bin/<name>.sh` after writing.

### Step 3 — Patch `hooks/hooks.json`

Read the existing file; add a new entry under the event key:

```json
{
  "matcher": "<matcher>",
  "hooks": [
    { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/bin/<name>.sh" }
  ]
}
```

If the event already exists, append to its array. Use the Edit tool, NOT
overwrite — to preserve other registered hooks.

### Step 4 — Tell user to reload

```
✓ Hook scaffolded:
   Script:   bin/<name>.sh (chmod +x applied)
   Event:    <event>
   Matcher:  <matcher>
   Registry: hooks/hooks.json patched

To activate: claude plugin update crucible@crucible-local
After reload, the hook fires on <event> events matching <matcher>.

Remember: hook implements opt-in via .crucible/active. Without that sentinel,
the hook exits 0 silently — by design.
```

## Refusal modes

- Invalid event → refuse, list the four supported events
- Invalid matcher (not a string) → refuse
- File exists → refuse, suggest rename
- `hooks/hooks.json` malformed → refuse, do NOT overwrite; instruct user to fix manually

## Why opt-in is hard-coded into the template

Crucible's design is per-project opt-in (PRD §1.16, README "Activation"). A
hook that fires regardless of `.crucible/active` violates that contract and
breaks unrelated projects. The template enforces this by structure — every
new hook starts with the three escape checks before any custom logic.
