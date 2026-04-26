#!/usr/bin/env bash
# Crucible — secret redaction library (PRD §1.21 SEC-1, NFR-5)
# Source from hook scripts. Reads stdin, writes redacted stdout.
#
# Patterns redacted (heuristic, conservative):
#   - Anthropic API keys: sk-ant-XXXX → sk-ant-REDACTED
#   - Generic sk-* keys (≥20 chars after sk-): sk-XXXX → sk-REDACTED
#   - Bearer tokens: Bearer XXX → Bearer REDACTED
#   - api_key/apikey/api-key=VALUE → api_key=REDACTED
#   - password=VALUE → password=REDACTED
#   - token=VALUE → token=REDACTED
#   - AWS access keys: AKIA[A-Z0-9]{16} → AKIA-REDACTED
#   - GitHub tokens: ghp_/gho_/ghu_/ghs_/ghr_ XXXX → REDACTED

redact_secrets() {
  sed -E '
    s/sk-ant-[a-zA-Z0-9_-]{20,}/sk-ant-REDACTED/g
    s/sk-[a-zA-Z0-9_-]{20,}/sk-REDACTED/g
    s/(Bearer[[:space:]]+)[a-zA-Z0-9._-]{10,}/\1REDACTED/g
    s/((api[_-]?key|apikey|password|token|secret)["'\''[:space:]]*[:=][[:space:]]*["'\''])([^"'\'']{4,})(["'\''])/\1REDACTED\4/gi
    s/AKIA[A-Z0-9]{16}/AKIA-REDACTED/g
    s/(gh[pousr]_)[a-zA-Z0-9]{30,}/\1REDACTED/g
  '
}

# Self-test: if invoked directly, run a smoke test
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "Self-test:"
  echo 'auth: Bearer sk-ant-api03-aBcDeFgHiJkLmNoPqRsTuVwXyZ12345678 password: "hunter2supersecret"' | redact_secrets
  echo 'AKIAIOSFODNN7EXAMPLE token: ghp_aBcDeFgHiJkLmNoPqRsTuVwXyZ123456789012' | redact_secrets
fi
