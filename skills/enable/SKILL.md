---
name: enable
description: Activate Crucible enforcement in the current project. Use this when you intentionally want Crucible's hooks (PreToolUse, PostToolUse, Stop) to enforce evidence-gated completion. Without activation, Crucible is silent in this project. This is the explicit opt-in step before starting any /crucible:planning or /crucible:validation workflow. Creates a sentinel file at .crucible/active in the project root. Reversible via /crucible:disable. Safe to invoke multiple times — idempotent.
---

# Crucible — Enable enforcement in this project

## Purpose

Activate Crucible's gate-enforcement hooks in the current working directory. Without this, the hooks are silent no-ops (so user-scope plugin installs do not break unrelated projects).

## Workflow

1. Verify `${CLAUDE_PROJECT_DIR}` is the project root (not a subdirectory).
2. Create the directory and sentinel file via Bash:
   ```bash
   mkdir -p ${CLAUDE_PROJECT_DIR}/.crucible
   touch ${CLAUDE_PROJECT_DIR}/.crucible/active
   ```
3. If `${CLAUDE_PROJECT_DIR}/.crucible/disabled` exists, remove it (kill-switch override would otherwise still suppress enforcement):
   ```bash
   rm -f ${CLAUDE_PROJECT_DIR}/.crucible/disabled
   ```
4. Confirm to the user with a one-line message including the absolute path:
   `Crucible enabled at <project>/.crucible/active. Hooks will now enforce.`

## Forbidden actions

- Do NOT create `.crucible/active` outside the project root.
- Do NOT auto-create `evidence/` content; the user (or other Crucible skills) does that.
- Do NOT silently re-enable if `.crucible/disabled` is present without telling the user.

## Example

```
User: /crucible:enable
Assistant: Crucible enabled at /Users/me/myproject/.crucible/active.
           Pre/Post/Stop hooks will now enforce gate semantics in this project.
           To opt out later: /crucible:disable
```

## Iron Rule

Activation is the only thing this skill does. It does not run the gate. It does not generate evidence. It does not rewrite report.json. It is a 2-line idempotent operation that flips this project from "Crucible is invisible" to "Crucible enforces".
