#!/usr/bin/env python3
"""
Crucible session-log-audit — line-cited behavior verification.

Reads ~/.claude/projects/<encoded-cwd>/<session-id>.jsonl (the canonical Claude
Code session log) and emits per-trial INDEX.md citing the line numbers that
prove each required behavior fired.

Required behaviors (per build prompt VG-11 + PRD §1.17 FR-LOG):
- pre_task hook fired (PreToolUse event)
- post_task hook fired (PostToolUse event)
- stop / completion-attempt hook fired (Stop event or "type":"result")
- The named skill from MODE.txt was invoked (crucible:<skill>)
- For validation-mode trials: zero Write/Edit tool uses

NEVER edits the session log. NEVER fabricates citations. If a required behavior
is missing, the trial must be re-run after the plugin is fixed — not the log.

Usage:
    python3 audit.py <trial-id>

Environment:
    EVIDENCE_ROOT — required, absolute path to evidence/

Inputs:
    $EVIDENCE_ROOT/session-logs/<trial-id>/session.jsonl

Output:
    $EVIDENCE_ROOT/session-logs/<trial-id>/INDEX.md
"""

import json
import os
import sys
from pathlib import Path


REQUIRED_BEHAVIORS = ("pre_task", "post_task", "stop", "skill")


def audit(trial: str, evidence_root: Path) -> dict:
    log = evidence_root / "session-logs" / trial / "session.jsonl"
    if not log.exists():
        print(f"REFUSED: session log not found at {log}", file=sys.stderr)
        sys.exit(2)

    findings = {
        "pre_task": [],
        "post_task": [],
        "stop": [],
        "skill": [],
        "writes": [],
    }

    with log.open() as f:
        for i, line in enumerate(f, 1):
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                continue
            s = json.dumps(msg)
            if "PreToolUse" in s:
                findings["pre_task"].append(i)
            if "PostToolUse" in s:
                findings["post_task"].append(i)
            if '"type":"result"' in s or '"Stop"' in s:
                findings["stop"].append(i)
            if "crucible:" in s:
                findings["skill"].append(i)
            if '"name":"Write"' in s or '"name":"Edit"' in s:
                findings["writes"].append(i)

    return findings


def write_index(trial: str, findings: dict, evidence_root: Path) -> Path:
    out = evidence_root / "session-logs" / trial / "INDEX.md"

    lines = [f"# {trial} session-log audit", ""]
    for k in REQUIRED_BEHAVIORS:
        v = findings[k]
        preview = v[:10]
        suffix = "..." if len(v) > 10 else ""
        lines.append(f"- **{k}**: lines {preview}{suffix} (count={len(v)})")
    w = findings["writes"]
    lines.append(f"- **writes**: lines {w[:10]}{'...' if len(w) > 10 else ''} (count={len(w)})")
    lines.append("")

    # Per-criterion verdict
    lines.append("## Pass criteria")
    for k in REQUIRED_BEHAVIORS:
        verdict = "PASS" if findings[k] else "FAIL"
        lines.append(f"- {k} ≥1: {verdict} (count={len(findings[k])})")
    lines.append("")
    lines.append(
        "Note: validation-mode trials must additionally verify writes count == 0; "
        "see MODE.txt to determine expected mode."
    )

    out.write_text("\n".join(lines) + "\n")
    return out


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: audit.py <trial-id>", file=sys.stderr)
        return 2
    trial = sys.argv[1]
    evidence_root = os.environ.get("EVIDENCE_ROOT")
    if not evidence_root:
        print("REFUSED: EVIDENCE_ROOT env var not set", file=sys.stderr)
        return 2
    findings = audit(trial, Path(evidence_root))
    out = write_index(trial, findings, Path(evidence_root))
    print(f"Wrote {out}")
    print(f"Counts: " + ", ".join(f"{k}={len(findings[k])}" for k in list(REQUIRED_BEHAVIORS) + ["writes"]))
    # Exit non-zero if any required behavior is missing
    if any(not findings[k] for k in REQUIRED_BEHAVIORS):
        print("REFUSED: at least one required behavior was not observed in the session log.", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
