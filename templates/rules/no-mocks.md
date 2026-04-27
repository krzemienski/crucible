---
name: no-mocks
description: Iron Rule. Validation runs against real systems only. PRD §1.16.5 RL-1, §5 (Validation Strategy).
scope: planning, validation, execution, all subagents
---

# Rule RL-1 — No mocks

Validation runs against real systems only. The following are FORBIDDEN in any Crucible workflow:

- Mocks (any library imitating a real component)
- Stubs (placeholder implementations)
- Fakes (lightweight substitutes)
- Test doubles (any kind)
- Fixtures (pre-baked data masquerading as runtime evidence)
- Test files (`*.test.*`, `*.spec.*`, `*_test.*`, `tests/`, `__tests__/`, `spec/`)
- Test frameworks or test runners
- SDK substitutions (e.g., a fake `claude_agent_sdk` module)
- "Expected" output written by hand and presented as actual output
- mkdir-simulated installations

## What IS allowed

- Real CLI invocations with stdout/stderr captured verbatim
- Real HTTP requests with response headers + body captured
- Real filesystem inspection of installed artifacts
- Real session JSONL files written by Claude Code or the SDK
- Real screenshots, transcripts, and traces

## Enforcement

- Reviewer C explicitly audits for Iron Rule violations across all evidence + plugin source
- Oracle 3 (Adversarial Skepticism) re-confirms independently
- The completion gate refuses overall=COMPLETE if any test file or mock import is detected

## Why

Crucible exists because LLM-driven systems routinely declare success without proof. Mocks are how that lie gets manufactured. Removing the option to mock removes the option to lie.
