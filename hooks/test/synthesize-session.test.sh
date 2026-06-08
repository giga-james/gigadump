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

finish
