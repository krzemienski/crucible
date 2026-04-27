# Phase 1 — Install CLAUDE.md Block

## Determine Target

If `--local` was passed → `TARGET=local`.
If `--global` was passed → `TARGET=global`.

Otherwise (wizard), use AskUserQuestion:

**Question:** "Where should Crucible install its rules block?"

**Options:**
1. **Local (this project)** — `./.claude/CLAUDE.md`. Recommended. Crucible is opt-in per project, so local is the natural fit.
2. **Global (all sessions)** — `~/.claude/CLAUDE.md`. Rules visible everywhere, but each project still needs `.crucible/active` to enforce hooks.

Set `TARGET` to `local` or `global`.

If `TARGET=global` and `~/.claude/CLAUDE.md` already exists with content but
without the CRUCIBLE markers, ask a second question:

**Question:** "Global setup will modify your existing CLAUDE.md. How?"

**Options (default first):**
1. **Overwrite into base CLAUDE.md (Recommended)** — append managed block to existing file
2. **Preserve base; install into companion file** — write to `~/.claude/CLAUDE-crucible.md` instead

Set `STYLE=overwrite` or `STYLE=preserve`. Default `overwrite`.

## Run Installer

**MANDATORY**: Always run this script. Do NOT use the Write tool to construct
CLAUDE.md by hand — the script handles backup, marker management, idempotency,
and marker validation.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-claude-md.sh" "$TARGET" "$STYLE"
```

For `--local`, omit `STYLE`.

## Verify Markers

After the script returns, confirm both markers are present in the target file:

```bash
TARGET_FILE=...   # ./.claude/CLAUDE.md or ~/.claude/CLAUDE.md or ~/.claude/CLAUDE-crucible.md
grep -F "<!-- CRUCIBLE:START -->" "$TARGET_FILE" || { echo "ERROR: start marker missing"; exit 2; }
grep -F "<!-- CRUCIBLE:END -->" "$TARGET_FILE" || { echo "ERROR: end marker missing"; exit 2; }
```

If validation fails, do NOT attempt to manually rewrite the file. Stop and
report the failure.

## Save Progress

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-progress.sh" save 1 "$TARGET"
```

## Report

```
✓ Phase 1: CLAUDE.md block installed
   Target: <TARGET_FILE>
   Backup: <TARGET_FILE>.backup.YYYY-MM-DD (if existed)
   Markers: <!-- CRUCIBLE:START --> ... <!-- CRUCIBLE:END --> (verified)
```

Continue to Phase 2.
