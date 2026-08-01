#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

stub_bin="$test_tmp/bin"
mkdir -p "$stub_bin"

cat >"$stub_bin/checkupdates" <<'SH'
#!/bin/bash
[[ -n ${TEST_REPO_UPDATES:-} ]] || exit 2
printf '%s\n' "$TEST_REPO_UPDATES"
SH

cat >"$stub_bin/yay" <<'SH'
#!/bin/bash
[[ $* == "-Qua" ]] || exit 1
[[ -n ${TEST_AUR_UPDATES:-} ]] || exit 1
printf '%s\n' "$TEST_AUR_UPDATES"
SH

chmod +x "$stub_bin/checkupdates" "$stub_bin/yay"

run_checker() {
  PATH="$stub_bin:$PATH" \
    TEST_REPO_UPDATES="${TEST_REPO_UPDATES:-}" \
    TEST_AUR_UPDATES="${TEST_AUR_UPDATES:-}" \
    "$ROOT/bin/omarchy-update-available"
}

if run_checker >"$test_tmp/current"; then
  fail "current package set reports an available update"
fi
grep -Fxq 'System packages are up to date' "$test_tmp/current" ||
  fail "current package checker reports ordinary system state"
pass "package checker reports no updates"

TEST_REPO_UPDATES='firefox 1-1 -> 1-2' run_checker >"$test_tmp/repo"
grep -Fxq 'firefox 1-1 -> 1-2' "$test_tmp/repo" ||
  fail "package checker reports Arch repository updates"
pass "package checker detects Arch updates"

TEST_AUR_UPDATES='spotify 1-1 -> 1-2' run_checker >"$test_tmp/aur"
grep -Fxq 'spotify 1-1 -> 1-2' "$test_tmp/aur" ||
  fail "package checker reports AUR updates"
pass "package checker detects AUR updates"
