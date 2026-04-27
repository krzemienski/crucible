#!/usr/bin/env bash
# setup-progress.sh — Phase progress save/resume/clear for /crucible:setup.
# Modeled after omc-setup's setup-progress.sh.
#
# Usage:
#   setup-progress.sh save <phase-num> <target>     # phase-num: 1..4, target: local|global
#   setup-progress.sh resume                        # prints "fresh" or last-phase JSON
#   setup-progress.sh clear                         # removes state file

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/lib/config-dir.sh"

PROJECT_ROOT="$(resolve_project_root)"
STATE_FILE="${PROJECT_ROOT}/.crucible/setup-progress.json"

cmd="${1:?Usage: setup-progress.sh <save|resume|clear> [args]}"

case "$cmd" in
  save)
    phase="${2:?phase required}"
    target="${3:?target required}"
    mkdir -p "$(dirname "$STATE_FILE")"
    printf '{"phase":%s,"target":"%s","savedAt":"%s"}\n' \
      "$phase" "$target" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$STATE_FILE"
    echo "saved phase=$phase target=$target"
    ;;
  resume)
    if [ -f "$STATE_FILE" ]; then
      cat "$STATE_FILE"
    else
      echo "fresh"
    fi
    ;;
  clear)
    if [ -f "$STATE_FILE" ]; then
      rm -f "$STATE_FILE"
      echo "cleared"
    else
      echo "no state to clear"
    fi
    ;;
  *)
    echo "ERROR: unknown command: $cmd" >&2
    exit 1
    ;;
esac
