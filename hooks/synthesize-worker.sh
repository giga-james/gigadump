#!/usr/bin/env bash
# gigadump session synthesis — background worker. Best-effort; never fatal.
# Always exits 0. Guards nested `claude` against re-triggering the hook.
set -uo pipefail

: "${GIGADUMP_LOG:=$HOME/.config/gigadump/synthesize.log}"
: "${GIGADUMP_MAX_CHARS:=60000}"
export GIGADUMP_HOOK_ACTIVE=1

log() {
  mkdir -p "$(dirname "$GIGADUMP_LOG")" 2>/dev/null || true
  printf '%s [worker] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo now)" "$*" >>"$GIGADUMP_LOG" 2>/dev/null || true
}

today() { date -u +%Y-%m-%d 2>/dev/null || echo 0000-00-00; }

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-50
}

# Extract salient transcript content: assistant prose + concise tool markers.
extract_transcript() {
  jq -rs '
    [ .[] | select(.type=="assistant") | .message.content[]? |
      if .type=="text" then .text
      elif .type=="tool_use" then "[tool:" + .name + "] " + ((.input.command // .input.file_path // "") | tostring)
      else empty end
    ] | join("\n")
  ' "$TRANSCRIPT" 2>/dev/null | tail -c "$GIGADUMP_MAX_CHARS"
}

main() {
  local DUMP="${1:?dump path required}"
  local TRANSCRIPT="${2:?transcript path required}"
  export TRANSCRIPT

  command -v jq >/dev/null 2>&1 || { log "no jq"; exit 0; }
  command -v claude >/dev/null 2>&1 || { log "no claude"; exit 0; }
  command -v git >/dev/null 2>&1 || { log "no git"; exit 0; }

  local content; content="$(extract_transcript)"
  [[ -n "$content" ]] || { log "empty transcript extract"; exit 0; }

  local _pfile; _pfile="$(mktemp)"
  trap 'rm -f "$_pfile"' EXIT
  {
    printf '%s\n' "You are synthesizing a Claude Code work session into a single gigadump entry."
    printf '%s\n' "Output EXACTLY the following structure (no preamble, no code fences, no frontmatter):"
    printf '\n'
    printf '%s\n' "TITLE: <concise title of the session work>"
    printf '%s\n' "TAGS: <2-5 lowercase comma-separated tags>"
    printf '\n'
    printf '%s\n' "## Work done"
    printf '%s\n' "<what changed: files touched, key decisions, outcome. Concrete and brief.>"
    printf '\n'
    printf '%s\n' "## Ideas / follow-ups"
    printf '%s\n' "<open questions, TODOs, ideas that surfaced. Leave empty if none; do not invent.>"
    printf '\n'
    printf '%s\n' "Session transcript (assistant messages + tool markers) follows:"
    printf '\n'
    printf '%s\n' "$content"
  } > "$_pfile"

  local out; out="$(claude -p < "$_pfile" 2>>"$GIGADUMP_LOG")" || { log "claude failed"; exit 0; }
  [[ -n "$out" ]] || { log "claude empty output"; exit 0; }

  local title tags body slug file
  title="$(printf '%s\n' "$out" | sed -n 's/^TITLE:[[:space:]]*//p' | head -1)"
  [[ -n "$title" ]] || title="session $(today)"
  tags="$(printf '%s\n' "$out" | sed -n 's/^TAGS:[[:space:]]*//p' | head -1)"
  body="$(printf '%s\n' "$out" | awk 'f{print} /^## /{if(!f){f=1;print}}')"
  [[ -n "$body" ]] || body="$(printf '## Work done\n')"

  slug="$(slugify "$title")"; [[ -n "$slug" ]] || slug="session"
  file="$DUMP/$(today)-$slug.md"
  [[ -e "$file" ]] && file="$DUMP/$(today)-$slug-$$.md"

  {
    printf '%s\n' "---"
    printf '%s\n' "title: $title"
    printf '%s\n' "created: $(today)"
    printf '%s\n' "status: seed"
    printf '%s\n' "tags: [$tags]"
    printf '%s\n' "category:"
    printf '%s\n' "---"
    printf '\n'
    printf '%s\n' "$body"
  } > "$file" || { log "write failed"; exit 0; }
  log "wrote $file"

  git -C "$DUMP" add -- "$file" 2>>"$GIGADUMP_LOG" || { log "git add failed"; exit 0; }
  git -C "$DUMP" commit -q -m "session: $title" 2>>"$GIGADUMP_LOG" || { log "git commit failed"; exit 0; }
  if git -C "$DUMP" remote get-url origin >/dev/null 2>&1; then
    git -C "$DUMP" push -q 2>>"$GIGADUMP_LOG" && log "pushed" || log "push failed"
  else
    log "no remote; committed only"
  fi
  exit 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
