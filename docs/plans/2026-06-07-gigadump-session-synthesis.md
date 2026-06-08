# Gigadump Session Synthesis Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** At the end of each Claude Code session, automatically synthesize the work done (plus ideas/follow-ups) and push it into the user's gigadump repo for the CI organizer to file.

**Architecture:** A `SessionEnd` command hook shipped in the gigadump plugin runs a cheap-gate entrypoint script (`synthesize-session.sh`). When the session is opted-in and substantial, it spawns a detached worker (`synthesize-worker.sh`) that extracts the transcript, calls headless `claude -p` to write an `idea.md`-shaped entry into the gigadump repo root, then commits and pushes so the existing CI organizer files it. A reentrancy guard (`GIGADUMP_HOOK_ACTIVE`) stops the worker's own `claude` invocation from re-triggering the hook.

**Tech Stack:** Bash, `jq`, `git`, the `claude` CLI (headless `-p`), Claude Code plugin hooks.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `hooks/synthesize-session.sh` | Hook entrypoint. Cheap gates (reentrancy, opt-in, substance). Detaches the worker. Sourceable for unit tests. |
| `hooks/synthesize-worker.sh` | Background worker. Transcript extraction, `claude -p` synthesis, write root file, commit + push. Sourceable for unit tests. |
| `hooks/hooks.json` | Registers the `SessionEnd` command hook for the plugin. |
| `hooks/test/lib.sh` | Tiny shared bash assert harness for the other test scripts. |
| `hooks/test/synthesize-session.test.sh` | Unit tests for entrypoint gate functions. |
| `hooks/test/synthesize-worker.test.sh` | Unit/integration tests for worker functions (claude + git stubbed). |
| `hooks/test/fixtures/` | JSONL transcript fixtures (substantial / trivial / edits / commit). |
| `skills/gigadump-idea/SKILL.md` | Bootstrap gains the `autoSynthesize` opt-in question + config write. |
| `templates/content-README.md` | Documents the feature and the `autoSynthesize` toggle. |

**Transcript JSONL schema (verified against a real transcript):** each line is a record with top-level `.type` (`assistant`, `user`, …). Assistant records hold `.message.content[]`, an array of items with `.type` of `text` (`.text`), `thinking`, or `tool_use` (`.name`, `.input`; Bash commands at `.input.command`, file edits at `.input.file_path`).

---

## Task 1: Scaffold hooks dir, test harness, and entrypoint guards

**Files:**
- Create: `hooks/test/lib.sh`
- Create: `hooks/synthesize-session.sh`
- Create: `hooks/test/synthesize-session.test.sh`

- [ ] **Step 1: Write the shared test harness**

Create `hooks/test/lib.sh`:

```bash
#!/usr/bin/env bash
# Minimal assert harness for hook tests.
TESTS_RUN=0
TESTS_FAILED=0

assert_eq() { # expected actual message
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ "$1" == "$2" ]]; then
    printf 'ok   - %s\n' "$3"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf 'FAIL - %s\n      expected: [%s]\n      actual:   [%s]\n' "$3" "$1" "$2"
  fi
}

finish() {
  printf '\n%d run, %d failed\n' "$TESTS_RUN" "$TESTS_FAILED"
  [[ "$TESTS_FAILED" -eq 0 ]]
}
```

- [ ] **Step 2: Write a failing test for reentrancy + sourcing guard**

Create `hooks/test/synthesize-session.test.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

# Source the script under test WITHOUT running main.
source "$HERE/../synthesize-session.sh"

# Reentrancy: guard returns true only when env var set.
( unset GIGADUMP_HOOK_ACTIVE; is_reentrant ); assert_eq "1" "$?" "is_reentrant false when unset"
( export GIGADUMP_HOOK_ACTIVE=1; is_reentrant ); assert_eq "0" "$?" "is_reentrant true when set"

finish
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `bash hooks/test/synthesize-session.test.sh`
Expected: FAIL — `synthesize-session.sh` does not exist yet (source error).

- [ ] **Step 4: Write the minimal entrypoint with guards**

Create `hooks/synthesize-session.sh`:

```bash
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

# Run main only when executed directly, not when sourced by tests.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  : # main added in Task 4
fi
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash hooks/test/synthesize-session.test.sh`
Expected: PASS — `2 run, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add hooks/test/lib.sh hooks/synthesize-session.sh hooks/test/synthesize-session.test.sh
git commit -m "feat(hooks): scaffold session-synthesis entrypoint + test harness"
```

---

## Task 2: Opt-in resolution (`resolve_dump`)

**Files:**
- Modify: `hooks/synthesize-session.sh`
- Modify: `hooks/test/synthesize-session.test.sh`

- [ ] **Step 1: Write the failing test**

Add to `hooks/test/synthesize-session.test.sh` before `finish`:

```bash
# --- resolve_dump ---
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# A real git repo to point at.
mkdir -p "$TMP/dump" && git -C "$TMP/dump" init -q

write_cfg() { printf '%s' "$1" > "$TMP/config.json"; }

# Not opted in (flag false) -> fail.
write_cfg "{\"autoSynthesize\": false, \"dumpRepoPath\": \"$TMP/dump\"}"
( resolve_dump "$TMP/config.json" >/dev/null ); assert_eq "1" "$?" "resolve_dump fails when autoSynthesize false"

# Opted in + valid repo -> prints path.
write_cfg "{\"autoSynthesize\": true, \"dumpRepoPath\": \"$TMP/dump\"}"
out="$(resolve_dump "$TMP/config.json")"; rc=$?
assert_eq "0" "$rc" "resolve_dump succeeds when opted in"
assert_eq "$TMP/dump" "$out" "resolve_dump prints dump path"

# Opted in but path is not a git repo -> fail.
write_cfg "{\"autoSynthesize\": true, \"dumpRepoPath\": \"$TMP/nope\"}"
( resolve_dump "$TMP/config.json" >/dev/null ); assert_eq "1" "$?" "resolve_dump fails when repo missing"

# Missing config file -> fail.
( resolve_dump "$TMP/missing.json" >/dev/null ); assert_eq "1" "$?" "resolve_dump fails when config missing"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash hooks/test/synthesize-session.test.sh`
Expected: FAIL — `resolve_dump: command not found`.

- [ ] **Step 3: Implement `resolve_dump`**

In `hooks/synthesize-session.sh`, add after `is_reentrant`:

```bash
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash hooks/test/synthesize-session.test.sh`
Expected: PASS — all assertions ok.

- [ ] **Step 5: Commit**

```bash
git add hooks/synthesize-session.sh hooks/test/synthesize-session.test.sh
git commit -m "feat(hooks): add opt-in resolve_dump gate"
```

---

## Task 3: Substance filter (`is_substantial`)

**Files:**
- Create: `hooks/test/fixtures/trivial.jsonl`
- Create: `hooks/test/fixtures/edits.jsonl`
- Create: `hooks/test/fixtures/commit.jsonl`
- Create: `hooks/test/fixtures/turns.jsonl`
- Modify: `hooks/synthesize-session.sh`
- Modify: `hooks/test/synthesize-session.test.sh`

- [ ] **Step 1: Create fixtures**

`hooks/test/fixtures/trivial.jsonl` (one short answer, no tools — must be skipped):

```
{"type":"user","message":{"content":[{"type":"text","text":"what is 2+2"}]}}
{"type":"assistant","message":{"content":[{"type":"text","text":"4"}]}}
```

`hooks/test/fixtures/edits.jsonl` (has a Write tool call — must proceed):

```
{"type":"assistant","message":{"content":[{"type":"text","text":"Editing"},{"type":"tool_use","name":"Write","input":{"file_path":"/tmp/a.txt"}}]}}
```

`hooks/test/fixtures/commit.jsonl` (has a git commit Bash call — must proceed):

```
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"git add -A && git commit -m x"}}]}}
```

`hooks/test/fixtures/turns.jsonl` (6 assistant text turns, no tools — must proceed):

```
{"type":"assistant","message":{"content":[{"type":"text","text":"1"}]}}
{"type":"assistant","message":{"content":[{"type":"text","text":"2"}]}}
{"type":"assistant","message":{"content":[{"type":"text","text":"3"}]}}
{"type":"assistant","message":{"content":[{"type":"text","text":"4"}]}}
{"type":"assistant","message":{"content":[{"type":"text","text":"5"}]}}
{"type":"assistant","message":{"content":[{"type":"text","text":"6"}]}}
```

- [ ] **Step 2: Write the failing test**

Add to `hooks/test/synthesize-session.test.sh` before `finish`:

```bash
# --- is_substantial ---
FX="$HERE/fixtures"
( is_substantial "$FX/trivial.jsonl" ); assert_eq "1" "$?" "trivial session is not substantial"
( is_substantial "$FX/edits.jsonl" );   assert_eq "0" "$?" "session with edit is substantial"
( is_substantial "$FX/commit.jsonl" );  assert_eq "0" "$?" "session with git commit is substantial"
( is_substantial "$FX/turns.jsonl" );   assert_eq "0" "$?" "session with >=6 turns is substantial"
( is_substantial "$FX/missing.jsonl" ); assert_eq "1" "$?" "missing transcript is not substantial"
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `bash hooks/test/synthesize-session.test.sh`
Expected: FAIL — `is_substantial: command not found`.

- [ ] **Step 4: Implement `is_substantial`**

In `hooks/synthesize-session.sh`, add after `resolve_dump`:

```bash
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
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash hooks/test/synthesize-session.test.sh`
Expected: PASS — all assertions ok.

- [ ] **Step 6: Commit**

```bash
git add hooks/synthesize-session.sh hooks/test/synthesize-session.test.sh hooks/test/fixtures
git commit -m "feat(hooks): add substance filter with transcript fixtures"
```

---

## Task 4: Decision + detached spawn (`decide`, `main`)

**Files:**
- Modify: `hooks/synthesize-session.sh`
- Modify: `hooks/test/synthesize-session.test.sh`

- [ ] **Step 1: Write the failing test for `decide`**

Add to `hooks/test/synthesize-session.test.sh` before `finish`:

```bash
# --- decide ---
export GIGADUMP_CONFIG="$TMP/config.json"
write_cfg "{\"autoSynthesize\": true, \"dumpRepoPath\": \"$TMP/dump\"}"

mk_input() { printf '{"transcript_path":"%s","hook_event_name":"SessionEnd"}' "$1"; }

# Reentrant -> skip.
out="$(GIGADUMP_HOOK_ACTIVE=1 decide "$(mk_input "$FX/edits.jsonl")")"
assert_eq "skip reentrant" "$out" "decide skips when reentrant"

# Not opted in -> skip.
write_cfg "{\"autoSynthesize\": false, \"dumpRepoPath\": \"$TMP/dump\"}"
out="$(decide "$(mk_input "$FX/edits.jsonl")")"
assert_eq "skip not-opted-in" "$out" "decide skips when not opted in"

# Opted in + trivial -> skip.
write_cfg "{\"autoSynthesize\": true, \"dumpRepoPath\": \"$TMP/dump\"}"
out="$(decide "$(mk_input "$FX/trivial.jsonl")")"
assert_eq "skip trivial" "$out" "decide skips trivial session"

# Opted in + substantial -> proceed with dump + transcript.
out="$(decide "$(mk_input "$FX/edits.jsonl")")"
assert_eq "proceed $TMP/dump $FX/edits.jsonl" "$out" "decide proceeds on substantial session"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash hooks/test/synthesize-session.test.sh`
Expected: FAIL — `decide: command not found`.

- [ ] **Step 3: Implement `decide` and `main`**

In `hooks/synthesize-session.sh`, add after `is_substantial`:

```bash
# Decide whether to synthesize.
# Prints "skip <reason>" or "proceed <dump> <transcript>".
decide() {
  local input="$1" dump transcript
  if is_reentrant; then printf 'skip reentrant'; return; fi
  dump="$(resolve_dump)" || { printf 'skip not-opted-in'; return; }
  transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)"
  [[ -n "$transcript" ]] || { printf 'skip no-transcript'; return; }
  is_substantial "$transcript" || { printf 'skip trivial'; return; }
  printf 'proceed %s %s' "$dump" "$transcript"
}

main() {
  local input; input="$(cat)"
  local decision; decision="$(decide "$input")"
  # shellcheck disable=SC2086
  set -- $decision
  if [[ "${1:-}" != "proceed" ]]; then
    log "skip: ${2:-}"
    exit 0
  fi
  local dump="$2" transcript="$3"
  log "proceed: $transcript -> $dump"
  # Detach so SessionEnd does not block the terminal. nohup is portable
  # (macOS lacks setsid). The child is reparented and survives hook exit.
  GIGADUMP_HOOK_ACTIVE=1 nohup "$SCRIPT_DIR/synthesize-worker.sh" "$dump" "$transcript" \
    </dev/null >>"$GIGADUMP_LOG" 2>&1 &
  disown 2>/dev/null || true
  exit 0
}
```

Replace the `: # main added in Task 4` placeholder so the bottom guard reads:

```bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash hooks/test/synthesize-session.test.sh`
Expected: PASS — all assertions ok.

- [ ] **Step 5: Commit**

```bash
git add hooks/synthesize-session.sh hooks/test/synthesize-session.test.sh
git commit -m "feat(hooks): add decide() + detached worker spawn"
```

---

## Task 5: Worker text helpers (`slugify`, `extract_transcript`)

**Files:**
- Create: `hooks/synthesize-worker.sh`
- Create: `hooks/test/synthesize-worker.test.sh`

- [ ] **Step 1: Write the failing test**

Create `hooks/test/synthesize-worker.test.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

# Source worker without running main (no args needed because main is guarded).
source "$HERE/../synthesize-worker.sh"

# slugify
assert_eq "hello-world" "$(slugify 'Hello, World!')" "slugify lowercases and dashes"
assert_eq "a-b-c" "$(slugify '  a   b   c  ')" "slugify collapses whitespace"

# extract_transcript pulls assistant text + tool markers.
FX="$HERE/fixtures"
out="$(TRANSCRIPT="$FX/edits.jsonl" extract_transcript)"
case "$out" in
  *"Editing"*) assert_eq "0" "0" "extract includes assistant text" ;;
  *) assert_eq "1" "0" "extract includes assistant text" ;;
esac
case "$out" in
  *"[tool:Write]"*) assert_eq "0" "0" "extract includes tool marker" ;;
  *) assert_eq "1" "0" "extract includes tool marker" ;;
esac

finish
```

Note: sourcing the worker must not require args. The worker reads `DUMP`/`TRANSCRIPT` only inside `main` (added in Task 6), so sourcing is safe.

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash hooks/test/synthesize-worker.test.sh`
Expected: FAIL — `synthesize-worker.sh` does not exist.

- [ ] **Step 3: Implement the worker skeleton + helpers**

Create `hooks/synthesize-worker.sh`:

```bash
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

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  : # main added in Task 6
fi
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash hooks/test/synthesize-worker.test.sh`
Expected: PASS — all assertions ok.

- [ ] **Step 5: Commit**

```bash
git add hooks/synthesize-worker.sh hooks/test/synthesize-worker.test.sh
git commit -m "feat(hooks): add worker slugify + transcript extraction"
```

---

## Task 6: Worker synth → write → commit → push (`main`)

**Files:**
- Modify: `hooks/synthesize-worker.sh`
- Modify: `hooks/test/synthesize-worker.test.sh`

- [ ] **Step 1: Write the failing integration test**

Add to `hooks/test/synthesize-worker.test.sh` before `finish`:

```bash
# --- main: synth + write + commit + push (claude stubbed, real local remote) ---
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Fake `claude` on PATH that emits a canned idea file.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/claude" <<'STUB'
#!/usr/bin/env bash
cat >/dev/null   # consume the prompt on stdin
cat <<'OUT'
---
title: Test Session Work
created: 2026-06-07
status: seed
tags: [test]
category:
---

## Work done
Did the thing.

## Ideas / follow-ups
OUT
STUB
chmod +x "$TMP/bin/claude"

# A dump repo with a local bare remote so `git push` works.
git init -q --bare "$TMP/remote.git"
git init -q "$TMP/dump"
git -C "$TMP/dump" config user.email t@t && git -C "$TMP/dump" config user.name t
git -C "$TMP/dump" commit -q --allow-empty -m init
git -C "$TMP/dump" remote add origin "$TMP/remote.git"
git -C "$TMP/dump" push -q -u origin HEAD

# Run worker main in a subshell with stubbed PATH and args.
( PATH="$TMP/bin:$PATH" GIGADUMP_LOG="$TMP/log" \
  bash "$HERE/../synthesize-worker.sh" "$TMP/dump" "$FX/edits.jsonl" )

# A root .md entry was written.
written="$(ls "$TMP/dump"/*.md 2>/dev/null | head -1)"
case "$written" in
  *.md) assert_eq "0" "0" "worker wrote a root markdown entry" ;;
  *)    assert_eq "1" "0" "worker wrote a root markdown entry" ;;
esac

# It was committed (working tree clean).
status="$(git -C "$TMP/dump" status --porcelain)"
assert_eq "" "$status" "worker committed the entry"

# It was pushed (remote HEAD matches local HEAD).
local_head="$(git -C "$TMP/dump" rev-parse HEAD)"
remote_head="$(git -C "$TMP/remote.git" rev-parse HEAD)"
assert_eq "$local_head" "$remote_head" "worker pushed to remote"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash hooks/test/synthesize-worker.test.sh`
Expected: FAIL — worker has no `main`, so no file/commit/push happens.

- [ ] **Step 3: Implement worker `main`**

In `hooks/synthesize-worker.sh`, replace the `: # main added in Task 6` placeholder block at the bottom with:

```bash
main() {
  local DUMP="${1:?dump path required}"
  local TRANSCRIPT="${2:?transcript path required}"
  export TRANSCRIPT

  command -v jq >/dev/null 2>&1 || { log "no jq"; exit 0; }
  command -v claude >/dev/null 2>&1 || { log "no claude"; exit 0; }
  command -v git >/dev/null 2>&1 || { log "no git"; exit 0; }

  local content; content="$(extract_transcript)"
  [[ -n "$content" ]] || { log "empty transcript extract"; exit 0; }

  local prompt; prompt="$(cat <<EOF
You are synthesizing a Claude Code work session into a single gigadump entry.
Output ONLY a markdown file (no preamble, no code fences) in this exact shape:

---
title: <concise title of the session's work>
created: $(today)
status: seed
tags: [<2-5 lowercase tags>]
category:
---

## Work done
<what changed: files touched, key decisions, outcome. Concrete and brief.>

## Ideas / follow-ups
<open questions, TODOs, ideas that surfaced. Leave empty if none — do not invent.>

Session transcript (assistant messages + tool markers) follows:

$content
EOF
)"

  local out; out="$(printf '%s' "$prompt" | claude -p 2>>"$GIGADUMP_LOG")" || { log "claude failed"; exit 0; }
  [[ -n "$out" ]] || { log "claude empty output"; exit 0; }

  local title slug file
  title="$(printf '%s\n' "$out" | sed -n 's/^title:[[:space:]]*//p' | head -1)"
  [[ -n "$title" ]] || title="session $(today)"
  slug="$(slugify "$title")"; [[ -n "$slug" ]] || slug="session"
  file="$DUMP/$(today)-$slug.md"
  [[ -e "$file" ]] && file="$DUMP/$(today)-$slug-$$.md"

  printf '%s\n' "$out" > "$file" || { log "write failed"; exit 0; }
  log "wrote $file"

  git -C "$DUMP" add -A 2>>"$GIGADUMP_LOG" || { log "git add failed"; exit 0; }
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
```

(Delete the earlier `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then : # main added in Task 6; fi` stub so there is exactly one bottom guard.)

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash hooks/test/synthesize-worker.test.sh`
Expected: PASS — all assertions ok, including push to remote.

- [ ] **Step 5: Re-run the entrypoint tests (no regression)**

Run: `bash hooks/test/synthesize-session.test.sh`
Expected: PASS — `decide`/gates unaffected.

- [ ] **Step 6: Commit**

```bash
git add hooks/synthesize-worker.sh hooks/test/synthesize-worker.test.sh
git commit -m "feat(hooks): worker synthesizes, writes, commits, and pushes"
```

---

## Task 7: Register the plugin hook (`hooks.json`)

**Files:**
- Create: `hooks/hooks.json`

- [ ] **Step 1: Write the hook registration**

Create `hooks/hooks.json`:

```json
{
  "hooks": {
    "SessionEnd": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/synthesize-session.sh",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Validate the JSON parses and is shaped correctly**

Run:
```bash
jq -e '.hooks.SessionEnd[0].hooks[0].type == "command" and (.hooks.SessionEnd[0].hooks[0].command | test("synthesize-session.sh"))' hooks/hooks.json
```
Expected: prints `true`, exit 0.

- [ ] **Step 3: Make the scripts executable**

Run:
```bash
chmod +x hooks/synthesize-session.sh hooks/synthesize-worker.sh
git update-index --chmod=+x hooks/synthesize-session.sh hooks/synthesize-worker.sh 2>/dev/null || true
```

- [ ] **Step 4: Commit**

```bash
git add hooks/hooks.json hooks/synthesize-session.sh hooks/synthesize-worker.sh
git commit -m "feat(hooks): register SessionEnd plugin hook"
```

---

## Task 8: Bootstrap opt-in question + config write (SKILL.md)

**Files:**
- Modify: `skills/gigadump-idea/SKILL.md` (Bootstrap step `d`)

- [ ] **Step 1: Read the current bootstrap config step**

Run: `sed -n '55,66p' skills/gigadump-idea/SKILL.md`
Expected: shows step `d` writing `~/.config/gigadump/config.json` with `dumpRepoPath` and `defaultStatus`.

- [ ] **Step 2: Update step `d` to ask about and persist `autoSynthesize`**

Replace the existing step `d` block:

```markdown
d. Write `~/.config/gigadump/config.json` (create `~/.config/gigadump/` if
   needed) with `dumpRepoPath` = `DUMP` and `defaultStatus` = `seed`.
```

with:

```markdown
d. Ask one yes/no question: "Auto-synthesize each Claude Code session into this
   dump? When on, at the end of every substantial session a hook summarizes the
   work + ideas and pushes an entry here for the organizer to file. (y/n)"
   Then write `~/.config/gigadump/config.json` (create `~/.config/gigadump/` if
   needed) with `dumpRepoPath` = `DUMP`, `defaultStatus` = `seed`, and
   `autoSynthesize` = the boolean answer (default `false` if they decline or are
   unsure). On a reused repo, preserve any existing `autoSynthesize` value rather
   than overwriting it.
```

- [ ] **Step 3: Verify the edit reads correctly**

Run: `sed -n '55,70p' skills/gigadump-idea/SKILL.md`
Expected: step `d` now includes the `autoSynthesize` question and config key.

- [ ] **Step 4: Commit**

```bash
git add skills/gigadump-idea/SKILL.md
git commit -m "feat(skill): bootstrap asks about autoSynthesize opt-in"
```

---

## Task 9: Document the feature (README template)

**Files:**
- Modify: `templates/content-README.md`

- [ ] **Step 1: Read the current README sections**

Run: `cat templates/content-README.md`
Expected: shows "Capture an idea", "What happens on push", "One-time setup".

- [ ] **Step 2: Add an auto-synthesis section**

Insert this section immediately after the "What happens on push" section and before "One-time setup":

```markdown
## Auto-synthesize sessions (optional)

When `autoSynthesize` is `true` in `~/.config/gigadump/config.json`, the gigadump
plugin installs a `SessionEnd` hook that, at the end of each **substantial**
Claude Code session (one with file edits, a commit, or several turns), summarizes
the work plus any ideas that surfaced and pushes an entry here — the organizer
then files it like any other dump. Trivial sessions are skipped.

- **Turn it on:** set `"autoSynthesize": true` in the config (the `/gigadump-idea`
  bootstrap asks once).
- **Turn it off:** set it back to `false`.
- **Debugging:** the hook logs each run to `~/.config/gigadump/synthesize.log`.

Synthesis runs in the background on your Claude subscription via the `claude`
CLI; it never blocks or delays your session.
```

- [ ] **Step 3: Verify the edit**

Run: `grep -n "Auto-synthesize sessions" templates/content-README.md`
Expected: matches the new heading.

- [ ] **Step 4: Commit**

```bash
git add templates/content-README.md
git commit -m "docs: document autoSynthesize session feature"
```

---

## Task 10: Full test sweep + manual end-to-end verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full hook test suite**

Run:
```bash
bash hooks/test/synthesize-session.test.sh && bash hooks/test/synthesize-worker.test.sh
```
Expected: both print `N run, 0 failed`, exit 0.

- [ ] **Step 2: Manual reentrancy check**

Run:
```bash
echo '{"transcript_path":"hooks/test/fixtures/edits.jsonl"}' | GIGADUMP_HOOK_ACTIVE=1 GIGADUMP_LOG=/tmp/g.log bash hooks/synthesize-session.sh
grep -q "skip: reentrant" /tmp/g.log && echo OK-REENTRANT
```
Expected: prints `OK-REENTRANT` (the worker is never spawned when reentrant).

- [ ] **Step 3: Manual skip check (not opted in)**

Run:
```bash
rm -f /tmp/g.log
echo '{"transcript_path":"hooks/test/fixtures/edits.jsonl"}' | GIGADUMP_CONFIG=/tmp/none.json GIGADUMP_LOG=/tmp/g.log bash hooks/synthesize-session.sh
grep -q "skip: not-opted-in" /tmp/g.log && echo OK-OPTOUT
```
Expected: prints `OK-OPTOUT`.

- [ ] **Step 4: Manual end-to-end (real claude, scratch repo with local remote)**

Run:
```bash
SCRATCH="$(mktemp -d)"
git init -q --bare "$SCRATCH/remote.git"
git init -q "$SCRATCH/dump"
git -C "$SCRATCH/dump" config user.email you@example.com
git -C "$SCRATCH/dump" config user.name you
git -C "$SCRATCH/dump" commit -q --allow-empty -m init
git -C "$SCRATCH/dump" remote add origin "$SCRATCH/remote.git"
git -C "$SCRATCH/dump" push -q -u origin HEAD
printf '{"autoSynthesize":true,"dumpRepoPath":"%s","defaultStatus":"seed"}' "$SCRATCH/dump" > "$SCRATCH/config.json"
echo "{\"transcript_path\":\"$PWD/hooks/test/fixtures/turns.jsonl\"}" \
  | GIGADUMP_CONFIG="$SCRATCH/config.json" GIGADUMP_LOG="$SCRATCH/log" bash hooks/synthesize-session.sh
sleep 45   # let the detached worker call claude + push
echo "--- log ---"; cat "$SCRATCH/log"
echo "--- entry ---"; ls "$SCRATCH/dump"/*.md && cat "$SCRATCH/dump"/*.md
```
Expected: log shows `proceed` then `wrote …` then `pushed`; a real synthesized `<date>-<slug>.md` exists in the dump root with `## Work done` / `## Ideas / follow-ups` sections.

- [ ] **Step 5: Final commit (if any verification fixups were needed)**

```bash
git add -A
git commit -m "test: verify gigadump session synthesis end-to-end" || echo "nothing to commit"
```

---

## Notes / known limitations

- Dump paths containing spaces would break the space-delimited `decide` output parsing. gigadump paths are not expected to contain spaces; revisit if that assumption breaks.
- Very long transcripts are truncated to the last `GIGADUMP_MAX_CHARS` (default 60k) chars before synthesis — a simple cost bound, not semantic selection.
- The hook depends on `jq`, `git`, and the `claude` CLI being on PATH; any missing one makes the hook a silent no-op (logged).
