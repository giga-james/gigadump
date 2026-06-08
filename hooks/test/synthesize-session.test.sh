#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

# Source the script under test WITHOUT running main.
source "$HERE/../synthesize-session.sh"

# Reentrancy: guard returns true only when env var set.
( unset GIGADUMP_HOOK_ACTIVE; is_reentrant ); assert_eq "1" "$?" "is_reentrant false when unset"
( export GIGADUMP_HOOK_ACTIVE=1; is_reentrant ); assert_eq "0" "$?" "is_reentrant true when set"

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

# --- is_substantial ---
FX="$HERE/fixtures"
( is_substantial "$FX/trivial.jsonl" ); assert_eq "1" "$?" "trivial session is not substantial"
( is_substantial "$FX/edits.jsonl" );   assert_eq "0" "$?" "session with edit is substantial"
( is_substantial "$FX/commit.jsonl" );  assert_eq "0" "$?" "session with git commit is substantial"
( is_substantial "$FX/turns.jsonl" );   assert_eq "0" "$?" "session with >=6 turns is substantial"
( is_substantial "$FX/missing.jsonl" ); assert_eq "1" "$?" "missing transcript is not substantial"

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

# Opted in + substantial -> proceed (status word only, no paths).
out="$(decide "$(mk_input "$FX/edits.jsonl")")"
assert_eq "proceed" "$out" "decide proceeds on substantial session"

# --- space-in-path regression (entrypoint level) ---
mkdir -p "$TMP/my dump" && git -C "$TMP/my dump" init -q
printf '%s' "{\"autoSynthesize\":true,\"dumpRepoPath\":\"$TMP/my dump\"}" > "$TMP/space-config.json"
echo "{\"transcript_path\":\"$FX/edits.jsonl\"}" \
  | GIGADUMP_CONFIG="$TMP/space-config.json" GIGADUMP_LOG="$TMP/space.log" \
    bash "$HERE/../synthesize-session.sh"
grep -q "proceed: .* -> $TMP/my dump$" "$TMP/space.log" 2>/dev/null
assert_eq "0" "$?" "space in dump path: proceed log contains full spaced path"

finish
