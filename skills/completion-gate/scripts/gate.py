#!/usr/bin/env python3
"""
Crucible completion-gate — final arbiter.

Evaluates every Mandatory Success Criterion (MSC-1..MSC-21) from PRD §2 against
cited evidence in evidence/, reads reviewer-consensus/decision.md and
final-oracle-evidence-audit/decision.md, and emits the canonical machine-readable
verdict at evidence/completion-gate/report.json.

Has NO override flag. NO force-complete. Refusal is a feature — when any
criterion fails, emits overall=REFUSED + REFUSAL.md and exits with code 2.

Usage:
    python3 gate.py

Environment:
    EVIDENCE_ROOT — required, absolute path to evidence/

Output:
    $EVIDENCE_ROOT/completion-gate/report.json   (always)
    $EVIDENCE_ROOT/completion-gate/REFUSAL.md    (only if overall=REFUSED)

Exit codes:
    0  overall=COMPLETE
    2  overall=REFUSED (any MSC fails OR consensus fails OR quorum fails)
"""

import json
import os
import sys
from pathlib import Path


# MSC-N → list of evidence file paths to verify (per PRD §3 mapping)
MSC_EVIDENCE = {
    "MSC-1":  ["documentation-research/SUMMARY.md"],
    "MSC-2":  ["prd/PRD.md"],
    "MSC-3":  ["architecture/ARCHITECTURE.md"],
    "MSC-4":  ["tbox-installation/build"],
    "MSC-5":  ["tbox-installation"],
    "MSC-6":  ["tbox-installation", "plugin-records"],
    "MSC-7":  ["plugin-discovery"],
    "MSC-8":  ["plugin-records"],
    "MSC-9":  ["agent-sdk"],
    "MSC-10": ["agent-sdk/planning"],
    "MSC-11": ["agent-sdk/validation"],
    "MSC-12": ["robust-trials/trial-01", "robust-trials/trial-02",
               "robust-trials/trial-03", "robust-trials/trial-04"],
    "MSC-13": ["session-logs"],
    "MSC-14": ["session-logs"],
    "MSC-15": ["validation-artifacts"],
    "MSC-16": [],  # every INDEX.md (checked separately)
    "MSC-17": ["reviewer-consensus/decision.md"],
    "MSC-18": ["final-oracle-evidence-audit"],
    "MSC-19": ["final-oracle-evidence-audit/oracle-1.md",
               "final-oracle-evidence-audit/oracle-2.md",
               "final-oracle-evidence-audit/oracle-3.md"],
    "MSC-20": ["final-oracle-evidence-audit/decision.md"],
    "MSC-21": ["final-oracle-evidence-audit/blockers"],
}


def evaluate_msc(msc_id: str, paths: list, evidence_root: Path) -> dict:
    cited = []
    statuses = []
    for p in paths:
        full = evidence_root / p
        if not full.exists():
            statuses.append("MISSING")
            cited.append(str(full.relative_to(evidence_root)))
            continue
        if full.is_dir():
            non_empty = any(full.iterdir())
            statuses.append("PASS" if non_empty else "EMPTY")
        else:
            non_empty = full.stat().st_size > 0
            statuses.append("PASS" if non_empty else "EMPTY")
        cited.append(str(full.relative_to(evidence_root)))

    if msc_id == "MSC-16":
        # Special: every directory under evidence/ must have INDEX.md.
        # PASS citation = sorted list of every INDEX.md path actually present
        # (per PRD RL-2/RL-4 — citations must be specific file paths, not strings).
        missing_indexes = []
        present_indexes = []
        for d in sorted(evidence_root.rglob("*")):
            if d.is_dir():
                idx = d / "INDEX.md"
                if idx.exists():
                    present_indexes.append(str(idx.relative_to(evidence_root)))
                else:
                    missing_indexes.append(str(d.relative_to(evidence_root)))
        # Include the root INDEX.md too if present
        root_idx = evidence_root / "INDEX.md"
        if root_idx.exists():
            present_indexes.insert(0, "INDEX.md")
        if missing_indexes:
            return {"id": msc_id, "status": "FAIL", "citations": missing_indexes[:5],
                    "note": f"{len(missing_indexes)} directories missing INDEX.md"}
        return {"id": msc_id, "status": "PASS", "citations": present_indexes}

    if all(s == "PASS" for s in statuses):
        return {"id": msc_id, "status": "PASS", "citations": cited}
    if any(s == "MISSING" for s in statuses):
        return {"id": msc_id, "status": "INSUFFICIENT", "citations": cited}
    return {"id": msc_id, "status": "FAIL", "citations": cited}


def evaluate_consensus(evidence_root: Path) -> str:
    decision = evidence_root / "reviewer-consensus" / "decision.md"
    if not decision.exists():
        return "FAIL"
    text = decision.read_text()
    if "unanimous PASS" in text or "UNANIMOUS PASS" in text:
        return "PASS"
    return "FAIL"


def evaluate_quorum(evidence_root: Path) -> str:
    decision = evidence_root / "final-oracle-evidence-audit" / "decision.md"
    if not decision.exists():
        return "BLOCKED"
    text = decision.read_text()
    blockers_dir = evidence_root / "final-oracle-evidence-audit" / "blockers"
    META_FILES = {"README.md", "INDEX.md", "STATUS.md"}
    open_blockers = [
        b for b in blockers_dir.iterdir() if blockers_dir.exists()
        and b.is_file()
        and b.name not in META_FILES
        and not b.name.endswith(".resolved.md")
    ] if blockers_dir.exists() else []
    if "APPROVED" in text and not open_blockers:
        return "APPROVED"
    return "BLOCKED"


def write_refusal(report: dict, evidence_root: Path) -> Path:
    out = evidence_root / "completion-gate" / "REFUSAL.md"
    lines = ["# REFUSAL — Crucible completion gate", ""]
    lines.append("Per PRD §1.10 Principle 5: refusal over rationalization. "
                 "The following criteria were unsatisfied at gate-evaluation time.")
    lines.append("")
    for entry in report["msc"]:
        if entry["status"] != "PASS":
            for cite in entry["citations"]:
                lines.append(f"REFUSED  {entry['id']}  {cite}  {entry['status']}")
    if report["reviewer_consensus"] != "PASS":
        lines.append(f"REFUSED  reviewer_consensus  reviewer-consensus/decision.md  {report['reviewer_consensus']}")
    if report["oracle_quorum"] != "APPROVED":
        lines.append(f"REFUSED  oracle_quorum  final-oracle-evidence-audit/decision.md  {report['oracle_quorum']}")
    lines.append("")
    lines.append(f"overall: {report['overall']} — fix the cited gaps and re-run.")
    out.write_text("\n".join(lines) + "\n")
    return out


def main() -> int:
    evidence_root_env = os.environ.get("EVIDENCE_ROOT")
    if not evidence_root_env:
        print("REFUSED: EVIDENCE_ROOT env var not set", file=sys.stderr)
        return 2
    evidence_root = Path(evidence_root_env)

    msc_results = [evaluate_msc(msc, paths, evidence_root)
                   for msc, paths in MSC_EVIDENCE.items()]
    consensus = evaluate_consensus(evidence_root)
    quorum = evaluate_quorum(evidence_root)

    all_msc_pass = all(e["status"] == "PASS" for e in msc_results)
    overall = "COMPLETE" if (all_msc_pass and consensus == "PASS" and quorum == "APPROVED") else "REFUSED"

    report = {
        "msc": msc_results,
        "reviewer_consensus": consensus,
        "oracle_quorum": quorum,
        "overall": overall,
    }

    out = evidence_root / "completion-gate" / "report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2) + "\n")
    print(f"Wrote {out}")

    if overall == "REFUSED":
        refusal = write_refusal(report, evidence_root)
        print(f"Wrote {refusal}", file=sys.stderr)
        # Print structured refusal to stdout in PRD §6.8 voice
        for entry in report["msc"]:
            if entry["status"] != "PASS":
                for cite in entry["citations"]:
                    print(f"REFUSED  {entry['id']}  {cite}  {entry['status']}")
        if consensus != "PASS":
            print(f"REFUSED  reviewer_consensus  reviewer-consensus/decision.md  {consensus}")
        if quorum != "APPROVED":
            print(f"REFUSED  oracle_quorum  final-oracle-evidence-audit/decision.md  {quorum}")
        print(f"overall: REFUSED")
        return 2

    # PASS path — print SEAL/APPROVE summary
    for entry in report["msc"]:
        for cite in entry["citations"]:
            print(f"SEAL    {entry['id']}  {cite}")
    print(f"APPROVE consensus  reviewer-consensus/decision.md")
    print(f"APPROVE quorum     final-oracle-evidence-audit/decision.md")
    print(f"overall: COMPLETE — all 21 MSC satisfied, three-reviewer unanimous, Oracle quorum approved.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
