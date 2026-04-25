# Installing Crucible

Crucible is a Claude Code plugin. Install once, then invoke via slash commands or have it auto-fire on every Stop event.

## Prerequisites

| Tool | Version | Why |
|------|---------|-----|
| Claude Code CLI | ≥ 0.5 (any version with `claude plugin install`) | Plugin runtime |
| Python | ≥ 3.10 | `gate.py`, `audit.py`, `build_index.py` scripts |
| `jq` | any | Used by hook scripts when available; falls back gracefully |
| `bash` | ≥ 3.2 (macOS default) | Hook scripts are bash 3.2-portable |

Verify:

```bash
claude --version
python3 --version    # ≥ 3.10
jq --version         # optional
bash --version       # 3.2+ OK
```

## Three install paths

Crucible supports three installation modes, in order of recommendation for production use:

### Path A: GitHub remote marketplace (recommended for most users)

```bash
claude plugin marketplace add krzemienski/crucible
claude plugin install crucible@crucible-local
```

Verify:

```bash
claude plugin list | grep crucible
# Expected:
#   ❯ crucible@crucible-local
#     Version: 0.1.0
#     Scope: user
#     Status: ✔ enabled
```

`claude plugin marketplace add krzemienski/crucible` clones the repo into
`~/.claude/plugins/marketplaces/crucible-local/` and reads its
`.claude-plugin/marketplace.json`. The single plugin in that manifest is
`crucible` (source: `./`). Install resolves to
`~/.claude/plugins/cache/crucible-local/crucible/0.1.0/`.

### Path B: Local marketplace (recommended for plugin development)

If you've cloned the repo locally and want to install from your working tree:

```bash
git clone https://github.com/krzemienski/crucible.git
claude plugin marketplace add /absolute/path/to/crucible/crucible-plugin
claude plugin install crucible@crucible-local
```

Same outcome, but the marketplace source is `Directory (/path/to/crucible-plugin)`
instead of `GitHub (krzemienski/crucible)`. Use this when iterating on plugin source.

### Path C: `--plugin-dir` for ephemeral testing (no install)

```bash
claude --plugin-dir /absolute/path/to/crucible-plugin
```

Loads Crucible for the current session only. Nothing is written to
`~/.claude/plugins/`. Useful for smoke-testing changes before committing.

## Verifying installation

Run one of these to confirm Crucible is loaded:

```bash
# 1. Plugin list (should show crucible@crucible-local)
claude plugin list

# 2. Manifest validation
claude plugin validate ~/.claude/plugins/cache/crucible-local/crucible/0.1.0
# Expected: ✔ Validation passed

# 3. JSON output for scripting
claude plugin list --json | jq '.[] | select(.id | startswith("crucible@"))'
```

## What gets installed

After install, you'll have:

```
~/.claude/plugins/cache/crucible-local/crucible/0.1.0/
├── .claude-plugin/
│   ├── marketplace.json
│   └── plugin.json
├── README.md
├── CHANGELOG.md
├── LICENSE
├── INSTALL.md
├── hooks/
│   └── hooks.json              # 4 events (SessionStart/Pre/Post/Stop)
├── bin/
│   ├── session-start.sh        # Records session start
│   ├── pre-task.sh             # Iron-Rule enforcer (blocks test files)
│   ├── post-task.sh            # Idempotent receipt sealer
│   └── completion-attempt.sh   # THE GATE (refuses Stop without report.json)
├── agents/                     # 10 subagents (planner, reviewers, oracles)
└── skills/                     # 8 skills (planning, validation, etc.)
```

## Activation lifecycle (since v0.1.1)

**Crucible is OPT-IN per project.** A user-scope install does NOT enforce in
every project — it only enforces in projects that have explicitly activated it.
This prevents the plugin from breaking unrelated workflows.

### Activate Crucible in a project

```bash
# From the project root, either:
/crucible:enable
# or manually:
mkdir -p .crucible && touch .crucible/active
```

After activation:

1. SessionStart writes a receipt to `evidence/session-receipts/`.
2. PreToolUse / PostToolUse fire on every Write/Edit/Bash.
3. Stop event refuses unless `evidence/completion-gate/report.json` shows `overall=COMPLETE`.

### Deactivate Crucible in a project

```bash
/crucible:disable
# or manually:
rm .crucible/active
```

After deactivation, all hooks are silent no-ops in this project.

### Escape hatches (when you're stuck)

If the Stop hook is blocking you and you need out, ANY of these work:

| Method | Scope | When to use |
|--------|-------|-------------|
| `/crucible:disable` | This project | Recommended; clean opt-out |
| `rm .crucible/active` | This project | Manual equivalent of `/crucible:disable` |
| `touch .crucible/disabled` | This project | Kill switch — overrides `.crucible/active` even if it exists |
| `CRUCIBLE_DISABLE=1 claude` | Current shell | Disable for one shell session only |

The refusal stderr lists all four hatches every time the hook blocks, so you
never need to remember them.

### Self-healing on abandoned workflows

If `.crucible/active` exists but `evidence/completion-gate/` was never created
(typical of an abandoned mid-workflow session), the Stop hook detects the
contradictory state and exits 0 with a one-line warning instead of trapping the
user. To re-enable enforcement after that, run `/crucible:completion-gate` to
generate the gate output, or `/crucible:disable` to opt out cleanly.

### What about the gate's "no override" philosophy?

Crucible's identity is *"refusal is a feature; no force-complete inside an
active workflow"*. That philosophy is intact:

- ❌ "I'm in a Crucible workflow but want to skip the gate" → still refused.
- ✅ "I'm not in a Crucible workflow, get out of my way" → easy opt-out via the hatches above.

Switching states (opt-in / opt-out) is an explicit lifecycle action distinct
from bypassing an active gate.

## Uninstalling

```bash
claude plugin uninstall crucible@crucible-local
claude plugin marketplace remove crucible-local    # optional
```

Or for `--plugin-dir` users: just stop passing the flag.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `Hook Stop (Stop) error: REFUSED ... overall=REFUSED` | Crucible's gate is doing its job; your project doesn't have a passing `report.json` | Run `/crucible:completion-gate` to evaluate, fix any FAILed MSCs, re-run |
| `claude plugin install`: marketplace not found | `claude plugin marketplace add` not run | See Path A or B above |
| Manifests fail to validate | `marketplace.json` field error | Run `claude plugin validate <path>` for line-level errors |
| Hooks don't fire | `bin/*.sh` not executable | `chmod +x ~/.claude/plugins/cache/crucible-local/crucible/0.1.0/bin/*.sh` |
| `evidence/evidence/` directory appearing | You're using a Crucible version <0.1.1 with the cwd bug; upgrade | `claude plugin update crucible@crucible-local` |

## Updating

```bash
claude plugin update crucible@crucible-local
```

This re-pulls from `krzemienski/crucible` (or the local directory for Path B) and refreshes the cache.

## Where evidence lives

After Crucible runs in your project, expect:

```
<your-project>/
└── evidence/
    ├── session-receipts/     # Hook-fired receipts (one per tool use)
    ├── completion-gate/      # report.json + REFUSAL.md (when applicable)
    ├── session-logs/         # Captured Claude Code JSONL session logs
    ├── reviewer-consensus/   # When reviewer subagents run
    └── final-oracle-evidence-audit/  # When Oracle subagents run
```

The full evidence directory layout is documented in the build's
`ARCHITECTURE.md` and PRD §3.
