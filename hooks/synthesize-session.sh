#!/usr/bin/env bash
# gigadump session synthesis — SessionEnd hook entrypoint.
# Cheap gates only; detaches the worker when a session is worth capturing.
# Best-effort: every path exits 0 so the user's session is never disrupted.
set -uo pipefail

: "${GIGADUMP_CONFIG:=$HOME/.config/gigadump/config.json}"
: "${GIGADUMP_LOG:=$HOME/.config/gigadump/synthesize.log}"
: "${GIGADUMP_MIN_TURNS:=6}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  mkdir -p "$(dirname "$GIGADUMP_LOG")" 2>/dev/null || true
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo now)" "$*" >>"$GIGADUMP_LOG" 2>/dev/null || true
}

# The worker runs `claude`, whose SessionEnd would re-enter this hook.
is_reentrant() { [[ -n "${GIGADUMP_HOOK_ACTIVE:-}" ]]; }

# Opt-in + repo resolution. On success prints dumpRepoPath and returns 0.
resolve_dump() {
  local cfg="${1:-$GIGADUMP_CONFIG}"
  [[ -f "$cfg" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  [[ "$(jq -r '.autoSynthesize // false' "$cfg" 2>/dev/null)" == "true" ]] || return 1
  local dump
  dump="$(jq -r '.dumpRepoPath // empty' "$cfg" 2>/dev/null)"
  [[ -n "$dump" && -d "$dump/.git" ]] || return 1
  printf '%s' "$dump"
}

# Run main only when executed directly, not when sourced by tests.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  : # main added in Task 4
fi
