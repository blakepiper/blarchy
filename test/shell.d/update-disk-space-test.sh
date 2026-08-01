#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

if rg -q 'omarchy-update-(requires-free-space|lock|dev)|omarchy-snapshot|omarchy-migrate' \
  "$ROOT/bin/omarchy-update"; then
  fail "ordinary package updates still enter BLARCHY orchestration"
fi
grep -Fxq 'exec yay -Syu "$@"' "$ROOT/bin/omarchy-update" ||
  fail "ordinary package updates are not delegated directly to yay"
pass "ordinary package updates have no BLARCHY-specific gates"
