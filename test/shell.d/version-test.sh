#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

printf '0.2.0\n' >"$test_tmp/version"

actual=$(BLARCHY_VERSION_FILE="$test_tmp/version" "$ROOT/bin/blarchy-version")
[[ $actual == "0.2.0" ]] || fail "native version reports installed BLARCHY metadata" "actual: $actual"
pass "native version reports installed BLARCHY metadata"

actual=$(BLARCHY_VERSION_FILE="$test_tmp/version" "$ROOT/bin/omarchy-version")
[[ $actual == "0.2.0" ]] || fail "legacy version command delegates to BLARCHY" "actual: $actual"
pass "legacy version command delegates to BLARCHY"

if BLARCHY_VERSION_FILE="$test_tmp/missing" "$ROOT/bin/blarchy-version" >/dev/null 2>&1; then
  fail "version succeeds without installed metadata"
fi
pass "version fails clearly without installed metadata"

[[ $(<"$ROOT/version") == "0.2.0" ]] || fail "repository version is BLARCHY 0.2.0"
pass "repository version is BLARCHY 0.2.0"
