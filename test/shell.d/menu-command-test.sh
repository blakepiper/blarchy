#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
cleanup() {
  rm -rf "$test_tmp"
}
trap cleanup EXIT

stub_bin="$test_tmp/bin"
qs_args="$test_tmp/qs-args"
mkdir -p "$stub_bin"

cat >"$stub_bin/qs" <<'SH'
#!/bin/bash

printf '%s\n' "$*" >"$OMARCHY_TEST_QS_ARGS"
printf 'ok\n'
SH
chmod +x "$stub_bin/qs"
ln -s "$ROOT/bin/omarchy-menu" "$stub_bin/omarchy-menu"

PATH="$stub_bin:/usr/bin:/bin" \
RICE_PATH=/tmp/installed-runtime \
OMARCHY_PATH=/tmp/installed-runtime \
OMARCHY_TEST_QS_ARGS="$qs_args" \
  "$stub_bin/omarchy-menu" ping >/dev/null

grep -F -- "-p $ROOT/shell" "$qs_args" >/dev/null ||
  fail "menu wrapper sends IPC to the runtime tree containing the wrapper" "$(<"$qs_args")"
pass "menu wrapper keeps its shell IPC in the same runtime tree"
