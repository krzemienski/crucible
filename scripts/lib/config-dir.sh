#!/usr/bin/env bash
# config-dir.sh — Resolve Claude Code config directory.
# Mirrors the omc-setup pattern. Sourced by other Crucible setup scripts.
# Respects CLAUDE_CONFIG_DIR env var; falls back to $HOME/.claude.

resolve_claude_config_dir() {
  if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    printf '%s' "$CLAUDE_CONFIG_DIR"
  else
    printf '%s' "$HOME/.claude"
  fi
}

# Resolve project root: nearest ancestor with .crucible/ or git root, else PWD.
resolve_project_root() {
  local d="$PWD"
  while [ "$d" != "/" ]; do
    if [ -d "$d/.crucible" ] || [ -d "$d/.git" ]; then
      printf '%s' "$d"
      return 0
    fi
    d="$(dirname "$d")"
  done
  printf '%s' "$PWD"
}
