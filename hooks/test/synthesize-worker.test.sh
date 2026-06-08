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

finish
