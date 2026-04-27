# Phase 3 — Verify

Run the same checks as `/crucible:doctor`, but inline. Any failure here means
the user must repair before Phase 4.

## Checks

1. **Plugin manifest parses.**
   ```bash
   python3 -c 'import json,sys;json.load(open(sys.argv[1]))' \
     "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"
   ```

2. **Plugin appears in installed list.**
   ```bash
   claude plugin list 2>&1 | grep -q '^  ❯ crucible@' || { echo "ERROR: crucible not in plugin list"; exit 2; }
   ```

3. **Commands present.** Confirm `commands/`, `skills/`, `agents/`, `hooks/hooks.json`
   exist in the active cache directory.
   ```bash
   for sub in commands skills agents hooks; do
     [ -e "${CLAUDE_PLUGIN_ROOT}/$sub" ] || { echo "ERROR: $sub missing"; exit 2; }
   done
   ```

4. **CLAUDE.md block present.** Confirm the markers are in the target file
   chosen during Phase 1.

5. **Activation sentinel.**
   ```bash
   [ -f .crucible/active ] || { echo "ERROR: .crucible/active missing"; exit 2; }
   ```

6. **Evidence tree.** Confirm `evidence/` exists with at least the 16 standard
   subdirectories.

## On failure

Print the failing check and a remediation hint. Do NOT proceed to Phase 4.

## Save Progress

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-progress.sh" save 3 "$TARGET"
```

## Report

```
✓ Phase 3: Verification passed
   Plugin manifest: parsed
   Plugin record:   crucible@crucible-local present
   Components:      commands/, skills/, agents/, hooks/ all present
   CLAUDE.md:       CRUCIBLE markers verified
   Sentinel:        .crucible/active present
   Evidence:        evidence/ scaffolded with 16+ subdirs
```

Continue to Phase 4.
