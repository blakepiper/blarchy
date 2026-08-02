#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

test_home=$(mktemp -d)
trap 'rm -rf "$test_home"' EXIT

done_marker="$test_home/.local/state/blarchy/done/example"

if HOME="$test_home" "$ROOT/bin/omarchy-done" check example; then
  fail "done reports an unmarked task as complete"
fi

HOME="$test_home" "$ROOT/bin/omarchy-done" mark example
[[ -f $done_marker ]] || fail "done marks a task complete"
HOME="$test_home" "$ROOT/bin/omarchy-done" check example || fail "done reports a marked task as complete"

HOME="$test_home" "$ROOT/bin/omarchy-done" ensure once || fail "done ensures an unmarked task"
[[ -f $test_home/.local/state/blarchy/done/once ]] || fail "done ensure marks a task complete"
if HOME="$test_home" "$ROOT/bin/omarchy-done" ensure once; then
  fail "done ensures a completed task again"
fi

if HOME="$test_home" "$ROOT/bin/omarchy-done" check ../invalid >/dev/null 2>&1; then
  fail "done accepts marker path traversal"
fi

pass "done manages completion markers"

mkdir -p "$test_home/.local/state/omarchy/done"
touch "$test_home/.local/state/omarchy/done/legacy"
HOME="$test_home" "$ROOT/bin/omarchy-done" check legacy ||
  fail "native done state recognizes a legacy completion marker"
[[ ! -e $test_home/.local/state/blarchy/done/legacy ]] ||
  fail "checking legacy done state does not rewrite it"
pass "done preserves legacy completion state"
