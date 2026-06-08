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
