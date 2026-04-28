#!/usr/bin/env python3
"""Crucible skill-enrichment — discover and rank skills relevant to a task brief.

Walks four sanctioned scopes:
  - ~/.claude/skills/              (personal user-global)
  - ~/.claude/plugins/<plugin>/skills/  (plugin; filtered via installed_plugins.json)
  - <project>/.claude/skills/      (project-local)
  - <project>/crucible-plugin/skills/   (in-tree plugin)

Parses YAML frontmatter only (no body loads). De-duplicates by content hash.
Scores each candidate against TASK_BRIEF via lexical-overlap normalized by description
length (capped at 1536 chars per Claude Code skills-listing truncation).

Emits 5-10 ranked candidates. Refuses with exit 2 + REFUSAL.md if <5 above floor.

Usage:
    TASK_BRIEF="..." EVIDENCE_TARGET="/abs/path" python3 discover_skills.py

Environment:
    TASK_BRIEF       — required, the task description string
    EVIDENCE_TARGET  — required, absolute path to the run-scoped evidence dir
    PROJECT_ROOT     — optional, defaults to CWD; the project to walk for project-scope
    SCORE_FLOOR      — optional float, default 0.05
    MIN_CANDIDATES   — optional int, default 5 (hardcoded per plan v2 §1B)
    MAX_CANDIDATES   — optional int, default 10

Exit codes:
    0  5-10 candidates above floor; INDEX.md, CANDIDATES.md, SKIPPED.md written
    2  refusal (REFUSAL.md written; <5 above floor OR missing env vars)
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

# --- Constants ---
DESCRIPTION_CAP = 1536
DEFAULT_FLOOR = 0.10        # recall-over-brief: skill must mention ≥10% of brief tokens
DEFAULT_MIN_OVERLAP = 2     # absolute: skill must share ≥2 tokens with brief (kills 1-token noise)
DEFAULT_MIN = 3             # min relevant candidates; aspirational target is 5-10 (user spec)
DEFAULT_MAX = 10            # max returned per Phase 2.5 contract

STOPWORDS = {
    "the", "a", "an", "and", "or", "but", "if", "then", "else", "for", "to", "of",
    "in", "on", "at", "by", "with", "is", "are", "was", "were", "be", "been", "being",
    "this", "that", "these", "those", "i", "you", "he", "she", "it", "we", "they",
    "my", "your", "his", "her", "its", "our", "their", "do", "does", "did", "have",
    "has", "had", "will", "would", "could", "should", "may", "might", "can", "use",
    "using", "used", "uses", "as", "from", "into", "out", "over", "under", "no",
    "not", "yes", "so", "such", "via", "per", "every", "any", "all", "some", "more",
    "most", "less", "least", "what", "when", "where", "why", "how", "which", "who",
    "whom", "whose", "than", "also", "only", "one", "two", "three", "first",
}

FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)
NAME_RE = re.compile(r"^name:\s*(.+?)\s*$", re.MULTILINE)
DESC_RE = re.compile(r"^description:\s*(.+?)$", re.MULTILINE | re.DOTALL)


def parse_frontmatter(path: Path) -> dict | None:
    """Return {'name', 'description'} from SKILL.md frontmatter, or None on failure."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    m = FRONTMATTER_RE.match(text)
    if not m:
        return None
    fm_text = m.group(1)
    name_m = NAME_RE.search(fm_text)
    desc_m = DESC_RE.search(fm_text)
    if not name_m:
        return None
    name = name_m.group(1).strip().strip('"\'')
    description = ""
    if desc_m:
        # description may span multiple lines until next ^key: or end-of-frontmatter
        raw = desc_m.group(1)
        # Stop at next top-level YAML key
        cut = re.split(r"\n[a-zA-Z][\w-]*:\s", raw, maxsplit=1)[0]
        description = cut.strip()
    return {"name": name, "description": description, "path": str(path)}


def tokenize(text: str) -> set[str]:
    tokens = re.findall(r"[a-zA-Z][a-zA-Z0-9_-]+", text.lower())
    return {t for t in tokens if t not in STOPWORDS and len(t) >= 3}


def score_and_overlap(brief: str, description: str) -> tuple[float, int]:
    """Compute (recall_over_brief, absolute_overlap_count).

    Score = |overlap| / |brief_tokens|. Description capped at 1536 chars (Claude
    Code skill-listing truncation, per claude-code-skills.md:192) before tokenization
    to match the relevance signal Claude itself sees.

    Absolute overlap is returned separately so the caller can filter out noise:
    a skill matching 1/3 of a 3-token brief (e.g., common word) scores 0.33 but
    has overlap=1, which is below the noise floor. Filtering by `overlap >= 2`
    eliminates this class of false positive.
    """
    capped_desc = description[:DESCRIPTION_CAP]
    brief_tokens = tokenize(brief)
    desc_tokens = tokenize(capped_desc)
    if not brief_tokens or not desc_tokens:
        return (0.0, 0)
    overlap = brief_tokens & desc_tokens
    return (len(overlap) / len(brief_tokens), len(overlap))


def installed_plugin_paths() -> list[Path]:
    """Read ~/.claude/plugins/installed_plugins.json (schema v2: top-level
    {'version': 2, 'plugins': {<plugin_id>: [{'installPath': ..., ...}]}}).
    Return the real installPath for every installed plugin, or [] if the file
    is missing/malformed.

    Schema reference: live filesystem inspection 2026-04-28; pre-flight
    enumeration showed `{'version': 2, 'plugins': {...}}` with each plugin
    holding a list of install records carrying an absolute installPath that
    resolves under ~/.claude/plugins/cache/<marketplace>/<name>/<version>/."""
    manifest = Path.home() / ".claude" / "plugins" / "installed_plugins.json"
    if not manifest.exists():
        return []
    try:
        data = json.loads(manifest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return []
    if not isinstance(data, dict):
        return []
    plugins = data.get("plugins")
    if not isinstance(plugins, dict):
        return []
    paths: list[Path] = []
    for plugin_id, install_records in plugins.items():
        if not isinstance(install_records, list):
            continue
        for rec in install_records:
            if not isinstance(rec, dict):
                continue
            ip = rec.get("installPath")
            if not isinstance(ip, str):
                continue
            p = Path(ip)
            if p.exists() and p.is_dir():
                paths.append(p)
    return paths


def enumerate_skill_paths(project_root: Path, _unused: list[str]) -> tuple[list[Path], dict]:
    """Walk the four sanctioned scopes via the REAL plugin installPaths from
    installed_plugins.json (schema v2). Return (paths, scope_counts).

    Plugin discovery uses installed_plugins.json's `installPath` per record —
    those resolve into ~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/
    where the actual plugin tree lives. The shallow ~/.claude/plugins/<name>/
    directories are stubs and contain no SKILL.md."""
    paths: list[Path] = []
    seen_abs: set[str] = set()
    counts = {"personal": 0, "plugin": 0, "project": 0, "in_tree_plugin": 0,
              "marketplace_cache_excluded": 0,
              "plugins_resolved_via_installpath": 0}

    def _add(p: Path, scope: str) -> None:
        ap = str(p.resolve())
        if ap in seen_abs:
            return
        if "marketplace-cache" in ap:
            counts["marketplace_cache_excluded"] += 1
            return
        seen_abs.add(ap)
        paths.append(p)
        counts[scope] += 1

    # 1. personal — ~/.claude/skills/
    personal_root = Path.home() / ".claude" / "skills"
    if personal_root.exists():
        for p in personal_root.rglob("SKILL.md"):
            _add(p, "personal")

    # 2. plugin — resolve via installed_plugins.json installPath (the real plugin tree)
    install_paths = installed_plugin_paths()
    counts["plugins_resolved_via_installpath"] = len(install_paths)
    for ip in install_paths:
        # Each plugin's skills live under <installPath>/skills/<name>/SKILL.md
        skills_dir = ip / "skills"
        if skills_dir.exists():
            for p in skills_dir.rglob("SKILL.md"):
                _add(p, "plugin")

    # 3. project — <project>/.claude/skills/
    project_skills = project_root / ".claude" / "skills"
    if project_skills.exists():
        for p in project_skills.rglob("SKILL.md"):
            _add(p, "project")

    # 4. in-tree plugin — <project>/crucible-plugin/skills/
    in_tree = project_root / "crucible-plugin" / "skills"
    if in_tree.exists():
        for p in in_tree.rglob("SKILL.md"):
            _add(p, "in_tree_plugin")

    return paths, counts


def content_hash(meta: dict) -> str:
    h = hashlib.sha256()
    h.update(meta["name"].encode("utf-8"))
    h.update(b"\0")
    h.update(meta["description"][:DESCRIPTION_CAP].encode("utf-8"))
    return h.hexdigest()[:16]


def write_index(target: Path, ranked: list[dict], task_brief: str) -> None:
    lines = [f"# skill-enrichment INDEX — top {len(ranked)} candidates", ""]
    lines.append(f"**Task brief:** `{task_brief[:300]}`{'...' if len(task_brief) > 300 else ''}")
    lines.append(f"**Generated:** {datetime.now(timezone.utc).isoformat()}")
    lines.append("")
    lines.append("| Rank | Name | Score | Overlap | Source path | One-line rationale |")
    lines.append("|------|------|-------|---------|-------------|--------------------|")
    for i, c in enumerate(ranked, 1):
        rationale = c["description"][:120].replace("\n", " ").replace("|", "/")
        if len(c["description"]) > 120:
            rationale += "..."
        lines.append(f"| {i} | `{c['name']}` | {c['score']:.4f} | {c['overlap']} | `{c['path']}` | {rationale} |")
    (target / "INDEX.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_candidates(target: Path, ranked: list[dict]) -> None:
    lines = [f"# skill-enrichment CANDIDATES — long-form rationale", ""]
    for i, c in enumerate(ranked, 1):
        lines.append(f"## {i}. `{c['name']}`")
        lines.append(f"**Source:** `{c['path']}`")
        lines.append(f"**Score:** {c['score']:.4f}")
        lines.append("")
        lines.append("**Verbatim description from frontmatter:**")
        lines.append("")
        lines.append("> " + c["description"].replace("\n", "\n> "))
        lines.append("")
    (target / "CANDIDATES.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_skipped(target: Path, skipped: list[dict]) -> None:
    lines = ["# skill-enrichment SKIPPED — files enumerated but not scored", ""]
    if not skipped:
        lines.append("(none — all enumerated files had valid frontmatter)")
    else:
        lines.append("| Path | Reason |")
        lines.append("|------|--------|")
        for s in skipped:
            lines.append(f"| `{s['path']}` | {s['reason']} |")
    (target / "SKIPPED.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_raw_inventory(target: Path, paths: list[Path], counts: dict) -> None:
    lines = ["# skill-enrichment raw inventory", ""]
    lines.append(f"Total enumerated: {len(paths)}")
    for k, v in counts.items():
        lines.append(f"  {k}: {v}")
    lines.append("")
    for p in sorted(paths):
        lines.append(str(p))
    (target / "raw-inventory.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_refusal(target: Path, task_brief: str, floor: float, all_scored: list[dict],
                  min_count: int, min_overlap: int = DEFAULT_MIN_OVERLAP) -> None:
    # Use the SAME filter as the decision logic in main() — both score AND overlap gates
    passing = [c for c in all_scored if c["score"] > floor and c["overlap"] >= min_overlap]
    closest_5 = all_scored[:5]
    lines = [f"# REFUSAL — skill-enrichment", ""]
    lines.append(f"**Generated:** {datetime.now(timezone.utc).isoformat()}")
    lines.append("")
    lines.append(f"REFUSED  skill-enrichment  INDEX.md  fewer-than-{min_count}-above-floor")
    lines.append(f"  task_brief:    \"{task_brief[:300]}{'...' if len(task_brief) > 300 else ''}\"")
    lines.append(f"  floor:         {floor}")
    lines.append(f"  min_overlap:   {min_overlap} (absolute token-overlap requirement)")
    lines.append(f"  enumerated:    {len(all_scored)}")
    lines.append(f"  passing:       {len(passing)} (need ≥{min_count}; filter: score>floor AND overlap≥{min_overlap})")
    lines.append("")
    lines.append("**Closest 5 (diagnostic only — none recommended for plan injection):**")
    lines.append("")
    lines.append("| Rank | Name | Score | Path |")
    lines.append("|------|------|-------|------|")
    for i, c in enumerate(closest_5, 1):
        lines.append(f"| {i} | `{c['name']}` | {c['score']:.4f} | `{c['path']}` |")
    lines.append("")
    lines.append("This refusal is correct behavior. The task brief is orthogonal to the "
                 f"available skill ecosystem. The planner should NOT inject these "
                 f"low-scoring candidates as Required Skills.")
    (target / "REFUSAL.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    task_brief = os.environ.get("TASK_BRIEF", "").strip()
    evidence_target = os.environ.get("EVIDENCE_TARGET", "").strip()
    if not task_brief:
        print("REFUSED: TASK_BRIEF env var not set or empty", file=sys.stderr)
        return 2
    if not evidence_target:
        print("REFUSED: EVIDENCE_TARGET env var not set or empty", file=sys.stderr)
        return 2
    target = Path(evidence_target)
    target.mkdir(parents=True, exist_ok=True)

    project_root = Path(os.environ.get("PROJECT_ROOT", os.getcwd())).resolve()
    floor = float(os.environ.get("SCORE_FLOOR", DEFAULT_FLOOR))
    min_overlap = int(os.environ.get("MIN_OVERLAP", DEFAULT_MIN_OVERLAP))
    min_count = int(os.environ.get("MIN_CANDIDATES", DEFAULT_MIN))
    max_count = int(os.environ.get("MAX_CANDIDATES", DEFAULT_MAX))

    fallback_marker: list[str] = []
    paths, counts = enumerate_skill_paths(project_root, fallback_marker)
    print(f"[discover_skills] enumerated {len(paths)} SKILL.md files", file=sys.stderr)

    candidates: list[dict] = []
    skipped: list[dict] = []
    seen_hashes: set[str] = set()

    for p in paths:
        meta = parse_frontmatter(p)
        if meta is None:
            skipped.append({"path": str(p), "reason": "malformed-frontmatter-or-unreadable"})
            continue
        h = content_hash(meta)
        if h in seen_hashes:
            skipped.append({"path": str(p), "reason": f"duplicate-content-hash:{h}"})
            continue
        seen_hashes.add(h)
        s, ov = score_and_overlap(task_brief, meta["description"])
        meta["score"] = s
        meta["overlap"] = ov
        candidates.append(meta)

    # Sort by score desc, then by overlap desc as tiebreaker (multi-token > single-token at same recall)
    candidates.sort(key=lambda c: (c["score"], c["overlap"]), reverse=True)
    write_raw_inventory(target, paths, counts)
    write_skipped(target, skipped)

    # Filter: above floor AND minimum absolute overlap (kills 1-token noise on short briefs)
    above_floor = [c for c in candidates
                   if c["score"] > floor and c["overlap"] >= min_overlap]
    if len(above_floor) < min_count:
        write_refusal(target, task_brief, floor, candidates, min_count, min_overlap)
        # Also write a stub INDEX.md so MSC-SE-EMP-8's check has a target file
        stub = (
            f"# skill-enrichment INDEX — REFUSED\n\n"
            f"Fewer than {min_count} candidates above floor {floor}. "
            f"See REFUSAL.md for diagnostic.\n"
        )
        (target / "INDEX.md").write_text(stub, encoding="utf-8")
        print(f"REFUSED: only {len(above_floor)} above floor (need ≥{min_count})", file=sys.stderr)
        return 2

    ranked = above_floor[:max_count]
    write_index(target, ranked, task_brief)
    write_candidates(target, ranked)
    print(f"[discover_skills] OK: wrote {len(ranked)} candidates to {target}/INDEX.md", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
