#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

mkdir -p "$test_tmp/bin"
cat >"$test_tmp/bin/yay" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$YAY_CALLS"
SH
chmod +x "$test_tmp/bin/yay"

PATH="$test_tmp/bin:$PATH" YAY_CALLS="$test_tmp/calls" \
  "$ROOT/bin/omarchy-update" --devel
grep -Fxq -- '-Syu --devel' "$test_tmp/calls" ||
  fail "compatibility update route does not delegate directly to yay"

PATH="$test_tmp/bin:$ROOT/bin:$PATH" YAY_CALLS="$test_tmp/calls" \
  "$ROOT/bin/omarchy-update-perform"
grep -Fxq -- '-Syu' "$test_tmp/calls" ||
  fail "legacy perform route does not delegate through the yay compatibility route"
pass "legacy update routes are thin yay aliases"
