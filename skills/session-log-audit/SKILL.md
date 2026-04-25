---
name: session-log-audit
description: Locate and inspect the JSONL session log for a robust trial; emit per-trial line citations proving the required behaviors fired. Use this skill whenever a trial completes, whenever an Oracle requests behavior verification, whenever VG-11 of a Crucible run executes, or whenever a reviewer needs to confirm "did the hook actually fire?" Reads from the canonical Claude Code session log path (~/.claude/projects/ENCODED-CWD/SESSION-ID.jsonl). Produces evidence/session-logs/TRIAL-ID/INDEX.md with cited line numbers per behavior. Never edits session logs — fix the plugin and re-run instead.
---

# Session Log Audit

## Scope

This skill handles location, copying, and per-trial behavior auditing of Claude Code session logs (PRD §1.17 FR-LOG, MSC-13, MSC-14).

Does NOT handle: producing the trials themselves (that's `planning`/`validation`), modifying session-log content (sealed audit trail), or evaluating reviewer/Oracle outputs.

## Security

- Read-only access to `~/.claude/projects/`.
- Refuse to write to or modify any session log file.
- Sanitize paths before logging — encoded-cwd patterns may include user-identifiable strings.
- If a session log contains secret values (API keys mistakenly typed), cite line ranges only — never reproduce the secret in INDEX.md.

## Workflow

1. Determine `<encoded-cwd>` for `$TARGET_REPO`: replace every non-alphanumeric character with `-`.
2. List candidate session files: `ls -lt ~/.claude/projects/<encoded-cwd>/*.jsonl`.
3. Match `<session-id>` to the trial by:
   a. SDK-driven trials: read `init.json` from the SDK transcript and extract session_id.
   b. Interactive trials: take the most recently modified `.jsonl` matching the trial's wall-clock window.
4. Copy the session log into `evidence/session-logs/<trial>/session.jsonl` (NEVER edit it).
5. Run `audit.py` (provided in scripts/) over the copy. Output INDEX.md citing line numbers for each required behavior:
   - PreToolUse hook fired
   - PostToolUse hook fired
   - Stop / completion-attempt hook fired
   - The named skill from MODE.txt was invoked (`crucible:<skill-name>`)
   - For validation-mode trials: zero `Write`/`Edit` tool uses
6. If any required behavior is missing, REFUSE to mark the audit complete; surface the missing behavior to the planner for plugin fix + trial re-run.

## Produced artifacts

- `evidence/session-logs/<trial>/session.jsonl` — RAW session log copy (sealed, never edited)
- `evidence/session-logs/<trial>/INDEX.md` — cited line numbers per behavior with counts
- `evidence/session-logs/SUMMARY.md` — aggregated index across all trials
- `scripts/audit.py` — the parser (single source of truth)

## Forbidden actions

- Editing session.jsonl content.
- Synthesizing line citations not present in the actual log.
- Marking a behavior verified without an actual line number citation.
- Hand-authoring INDEX.md without running audit.py.

## Example

Trial-01 ran `/crucible:planning "add header to README"`:

1. encoded-cwd = `-Users-nick-Desktop-crucible`
2. Latest matching .jsonl: `~/.claude/projects/-Users-nick-Desktop-crucible/abc-123.jsonl`
3. Copy → `evidence/session-logs/trial-01/session.jsonl`
4. Run audit.py:
   - PreToolUse: lines [12, 47, 89, 134] (count=4)
   - PostToolUse: lines [13, 48, 90, 135] (count=4)
   - Stop: lines [201] (count=1)
   - crucible:planning skill invocation: lines [5, 23] (count=2)
   - Writes/Edits: lines [45, 132] (count=2 — planning trial, edits expected)
5. INDEX.md captures all citations. PASS.
