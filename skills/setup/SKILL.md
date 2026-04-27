---
name: setup
description: Install or refresh Crucible's CLAUDE.md rule block, scaffold evidence directory, and verify plugin health. Runs once per project (or globally) — idempotent. Modeled after oh-my-claudecode:omc-setup.
---

# Crucible Setup

The single command that activates Crucible in a project. After this, all other
`/crucible:*` commands are usable.

**When this skill is invoked, immediately execute the workflow below. Do not only
restate or summarize these instructions back to the user.**

## Flag Parsing

Check for flags in the user's invocation:
- `--help` → Show Help Text (below) and stop
- `--local` → Phase 1 only (target=local), then Phase 2..4
- `--global` → Phase 1 only (target=global), with overwrite/preserve sub-question
- `--force` → Skip Pre-Setup Check; run full wizard
- `--uninstall` → Strip the CRUCIBLE block from the local CLAUDE.md and exit
- No flags → Run Pre-Setup Check, then full setup if needed

## Help Text

When user runs with `--help`, display this and stop:

```
Crucible Setup — Activate Crucible in a project

USAGE:
  /crucible:setup              Run setup wizard (or update if already configured)
  /crucible:setup --local      Install CLAUDE.md block in this project (./.claude/CLAUDE.md)
  /crucible:setup --global     Install CLAUDE.md block globally (~/.claude/CLAUDE.md)
  /crucible:setup --force      Re-run wizard from scratch
  /crucible:setup --uninstall  Remove CRUCIBLE block from local CLAUDE.md
  /crucible:setup --help       Show this help

WHAT IT DOES:
  Phase 1 — Install rules block into target CLAUDE.md (idempotent, marker-managed)
  Phase 2 — Activate (.crucible/active sentinel + scaffold evidence/ tree)
  Phase 3 — Verify (run /crucible:doctor checks)
  Phase 4 — Welcome (next-step banner)

NOTE:
  Crucible is opt-in per project. Even after --global setup, each project still
  needs `.crucible/active` (auto-created by --local; create manually elsewhere).
```

## Pre-Setup Check: Already Configured?

Before doing anything, check the per-user sentinel:

```bash
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SENTINEL="${CONFIG_DIR}/.crucible-config.json"
if [ -f "$SENTINEL" ]; then
  ALREADY_CONFIGURED=true
fi
```

### If Already Configured (and no --force / --uninstall flags)

Use AskUserQuestion to prompt:

**Question:** "Crucible is already configured. What would you like to do?"

**Options:**
1. **Update CLAUDE.md only** — re-install the canonical block at the previously chosen target
2. **Run full setup again** — Phase 1..4 from scratch
3. **Cancel** — exit without changes

If "Update CLAUDE.md only": run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-claude-md.sh" <previous-target>` and stop.
If "Run full setup again": continue to Resume Detection.
If "Cancel": stop.

## Resume Detection

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-progress.sh" resume
```

If the output is not `fresh`, ask the user whether to resume from the saved phase
or start over. If they choose start over, run `setup-progress.sh clear`.

## Phase Execution

For each phase, read the corresponding file under `phases/` and follow its
instructions exactly. Save progress after each phase.

1. **Phase 1 — Install CLAUDE.md block.** Read `${CLAUDE_PLUGIN_ROOT}/skills/setup/phases/01-install-claude-md.md`.
2. **Phase 2 — Activate.** Read `${CLAUDE_PLUGIN_ROOT}/skills/setup/phases/02-activate.md`.
3. **Phase 3 — Verify.** Read `${CLAUDE_PLUGIN_ROOT}/skills/setup/phases/03-verify.md`.
4. **Phase 4 — Welcome.** Read `${CLAUDE_PLUGIN_ROOT}/skills/setup/phases/04-welcome.md`.

After all phases succeed, write the per-user sentinel:

```bash
mkdir -p "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
cat > "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.crucible-config.json" <<JSON
{"setupCompleted":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","setupVersion":"0.2.0","target":"$TARGET"}
JSON
```

## Uninstall Path

If `--uninstall` was passed, run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-claude-md.sh" local --uninstall
rm -f .crucible/active
```

Report success and stop. The sentinel under `~/.claude/.crucible-config.json` is
left in place so the user can run `/crucible:setup` again without the wizard.
