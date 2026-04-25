---
name: disable
description: Deactivate Crucible enforcement in the current project. Use this when Crucible's hooks are blocking a session in a project that is not actively running a Crucible workflow, or when you want to step out of enforcement temporarily. This is the explicit opt-out — Crucible's hooks become silent no-ops. Removes the .crucible/active sentinel. Reversible via /crucible:enable. Does not delete any evidence/ artifacts.
---

# Crucible — Disable enforcement in this project

## Purpose

Deactivate Crucible's hooks in the current project so they stop firing. Use when:

- A session is being blocked but you are not running a Crucible workflow.
- You want to pause enforcement to do unrelated work in a Crucible-active project.
- You are abandoning a Crucible workflow and don't plan to return.

## Workflow

1. Verify `${CLAUDE_PROJECT_DIR}/.crucible/active` exists (so you know there's something to disable).
2. Remove the sentinel via Bash:
   ```bash
   rm -f ${CLAUDE_PROJECT_DIR}/.crucible/active
   ```
3. Confirm to the user:
   `Crucible disabled at <project>/.crucible/active (file removed). Hooks are now silent.`
4. If the user wants to PERMANENTLY block re-activation (e.g., shared project where someone else might re-enable), suggest:
   ```bash
   touch ${CLAUDE_PROJECT_DIR}/.crucible/disabled
   ```
   This kill switch overrides any future `.crucible/active` until the user explicitly removes it.

## Forbidden actions

- Do NOT delete `evidence/` artifacts — they are the project's audit trail and remain valuable even after disable.
- Do NOT touch any other `.crucible/` files unless the user explicitly asks.
- Do NOT report success if the rm command failed (e.g., no `.crucible/active` to remove).

## Example

```
User: /crucible:disable
Assistant: Crucible disabled at /Users/me/myproject/.crucible/active.
           Pre/Post/Stop hooks will be silent no-ops here.
           Evidence directory preserved.
           To re-enable: /crucible:enable
```

## Iron Rule

This is the explicit, documented escape hatch from Crucible enforcement. It is NOT a "force-complete" or a way to bypass the gate while a workflow is active — it is a clean opt-out that turns Crucible's voice off in this project. Within an active workflow, the gate still refuses without override; this skill changes whether the workflow is active at all.
