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

# Substance filter. Returns 0 if the transcript shows real work.
is_substantial() {
  local t="${1:-}"
  [[ -f "$t" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  local edits commits turns
  edits="$(jq -rs '[.[] | select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and (.name=="Edit" or .name=="Write" or .name=="NotebookEdit"))] | length' "$t" 2>/dev/null || echo 0)"
  commits="$(jq -rs '[.[] | select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Bash") | (.input.command // "") | select(test("git commit"))] | length' "$t" 2>/dev/null || echo 0)"
  turns="$(jq -rs '[.[] | select(.type=="assistant") | .message.content[]? | select(.type=="text")] | length' "$t" 2>/dev/null || echo 0)"
  [[ "${edits:-0}" -gt 0 || "${commits:-0}" -gt 0 || "${turns:-0}" -ge "$GIGADUMP_MIN_TURNS" ]]
}

# Decide whether to synthesize.
# Prints "skip <reason>" or "proceed" (paths are NOT included — re-resolved in main).
decide() {
  local input="$1" dump transcript
  if is_reentrant; then printf 'skip reentrant'; return; fi
  resolve_dump >/dev/null || { printf 'skip not-opted-in'; return; }
  transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)"
  [[ -n "$transcript" ]] || { printf 'skip no-transcript'; return; }
  is_substantial "$transcript" || { printf 'skip trivial'; return; }
  printf 'proceed'
}

main() {
  local input; input="$(cat)"
  local decision; decision="$(decide "$input")"
  if [[ "$decision" != "proceed" ]]; then
    log "skip: ${decision#skip }"
    exit 0
  fi
  # Re-resolve paths with proper quoting — never word-split them.
  local dump; dump="$(resolve_dump)"
  local transcript; transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)"
  log "proceed: $transcript -> $dump"
  # Detach so SessionEnd does not block the terminal. nohup is portable
  # (macOS lacks setsid). The child is reparented and survives hook exit.
  GIGADUMP_HOOK_ACTIVE=1 nohup "$SCRIPT_DIR/synthesize-worker.sh" "$dump" "$transcript" \
    </dev/null >>"$GIGADUMP_LOG" 2>&1 &
  disown 2>/dev/null || true
  exit 0
}

# Run main only when executed directly, not when sourced by tests.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
