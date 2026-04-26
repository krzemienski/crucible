---
name: doctor
description: Verify Crucible installation health. Compares the plugin manifest (plugin.json) against the Claude Code plugin record and reports drift. Verifies SDK reachability. Read-only diagnostic. PRD §1.16.2 CMD-5.
allowed-tools: Read, Bash, Glob
---

# /crucible:doctor

Installation diagnostic per PRD §1.16.6 (PR-1..3) and §1.16.7 (TB-4).

## Checks performed

1. **Plugin manifest present**: `crucible-plugin/.claude-plugin/plugin.json` parses as valid JSON
2. **Plugin installed**: `claude plugin list | grep crucible` returns a row
3. **Manifest ↔ record equivalence** (PR-2):
   - Every command file in `commands/` appears in the active cache directory
   - Every skill file in `skills/*/SKILL.md` appears
   - Every agent file in `agents/*.md` appears
   - Every hook in `hooks/hooks.json` appears
   - Every rule template in `templates/rules/*.md` appears (rules ship as CLAUDE.md fragments — see check 8)
4. **SDK reachability** (TB-4): `python3 -c "import claude_agent_sdk"` succeeds
5. **Activation state**: report whether `.crucible/active` exists in `$PWD`
6. **Cache freshness**: compare `crucible-plugin/` source SHA-256 to `~/.claude/plugins/cache/crucible-local/crucible/<version>/` SHA-256
7. **Setup sentinel**: report whether `~/.claude/.crucible-config.json` exists. Parse and display `setupCompleted` + `setupVersion` + `target` if present. If absent, recommend `/crucible:setup`.
8. **CLAUDE.md marker block**: locate the target CLAUDE.md (per the sentinel's `target` field — local or global) and verify both `<!-- CRUCIBLE:START -->` and `<!-- CRUCIBLE:END -->` markers are present. If missing, recommend `/crucible:setup --force`.
9. **Setup script integrity**: verify `scripts/setup-claude-md.sh` and `scripts/setup-progress.sh` exist and are executable.

## Output (PRD §6.8 voice)

```
CRUCIBLE DOCTOR
===============
✓ manifest         crucible-plugin/.claude-plugin/plugin.json (v0.2.0)
✓ installed        crucible@crucible-local Status: ✔ enabled
✓ commands         19/19 present in record
✓ skills           11/11 present in record
✓ agents           10/10 present in record
✓ hooks            4/4 present in record
✓ rule templates   4/4 present (templates/rules/)
✓ sdk reachable    claude_agent_sdk 0.7.1
✓ activation       .crucible/active present in /Users/nick/Desktop/crucible
✓ cache fresh      source SHA == cache SHA
✓ setup sentinel   ~/.claude/.crucible-config.json (v0.2.0, target=local, 2026-04-25T20:50:00Z)
✓ CLAUDE.md block  <!-- CRUCIBLE:START --> ... <!-- CRUCIBLE:END --> present in ./.claude/CLAUDE.md
✓ setup scripts    setup-claude-md.sh and setup-progress.sh present and executable
```

## Refusal modes

- Manifest missing → REFUSED with remediation: "run claude plugin install"
- Any component missing from record → REFUSED with diff listing
- SDK unreachable → REFUSED with installation hint
- Cache stale → WARNING (not refusal) with `claude plugin update` hint
- Setup sentinel missing → WARNING with hint to run `/crucible:setup`
- CLAUDE.md markers missing or unbalanced → WARNING with hint to run `/crucible:setup --force` (or `/crucible:fix` for orphan-marker cleanup)
- Setup script not executable → REFUSED with `chmod +x` remediation

## Closes

- PRD §1.16.2 CMD-5 — reinstated in v0.2 per Decision Lock D6=a
- PRD §1.26 OQ-3 partial — `/crucible:audit` is now independently runnable; doctor verifies the substrate it relies on
