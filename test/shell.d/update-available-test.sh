#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

stub_bin="$test_tmp/bin"
git_log="$test_tmp/git.log"
mkdir -p "$stub_bin"

cat >"$stub_bin/omarchy-update-dev" <<'SH'
#!/bin/bash
[[ $1 == "--print-upstream" ]] || exit 1
[[ ${TEST_GIT_UPSTREAM:-origin/main} != "none" ]] || exit 0
echo "${TEST_GIT_UPSTREAM:-origin/main}"
SH

cat >"$stub_bin/git" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$TEST_GIT_LOG"
[[ $1 == "-C" ]] || exit 1
shift 2
case "$1" in
  fetch) [[ ${TEST_GIT_FETCH:-ok} == "ok" ]] ;;
  rev-list) echo "${TEST_GIT_BEHIND:-0}" ;;
  *) exit 1 ;;
esac
SH

cat >"$stub_bin/timeout" <<'SH'
#!/bin/bash
shift
exec "$@"
SH

chmod +x "$stub_bin"/*

run_checker() {
  OMARCHY_PATH="${TEST_OMARCHY_PATH:-/usr/share/omarchy}" \
    TEST_GIT_LOG="$git_log" \
    PATH="$stub_bin:$PATH" \
    "$ROOT/bin/omarchy-update-available"
}

stdout="$test_tmp/stdout"
stderr="$test_tmp/stderr"

if run_checker >"$stdout" 2>"$stderr"; then
  fail "package-backed installs do not report upstream Omarchy package updates"
fi
grep -Fxq 'BLARCHY is up to date' "$stdout" || fail "package-backed update checker reports BLARCHY state"
pass "package-backed update checker ignores upstream Omarchy content packages"

: >"$git_log"
TEST_OMARCHY_PATH="$test_tmp/checkout" TEST_GIT_BEHIND=2 run_checker >"$stdout" 2>"$stderr"
grep -Fxq 'BLARCHY source 2 new commits on origin/main' "$stdout" ||
  fail "update checker reports BLARCHY source commits" "$(cat "$stdout")"
grep -Fxq -- "-C $test_tmp/checkout fetch --quiet" "$git_log" ||
  fail "update checker fetches the configured BLARCHY checkout" "$(cat "$git_log")"
pass "update checker detects BLARCHY source commits"

if TEST_OMARCHY_PATH="$test_tmp/checkout" TEST_GIT_BEHIND=0 run_checker >"$stdout" 2>"$stderr"; then
  fail "current BLARCHY checkout reports no available update"
fi
grep -Fxq 'BLARCHY is up to date' "$stdout" || fail "current checkout reports BLARCHY state"
pass "update checker reports a current BLARCHY checkout"

TEST_OMARCHY_PATH="$test_tmp/checkout" TEST_GIT_BEHIND=1 TEST_GIT_FETCH=fail \
  run_checker >"$stdout" 2>"$stderr"
grep -Fxq 'BLARCHY source 1 new commit on origin/main' "$stdout" ||
  fail "update checker uses cached BLARCHY source state" "$(cat "$stdout")"
[[ ! -s $stderr ]] || fail "update checker keeps fetch failures quiet" "$(cat "$stderr")"
pass "update checker uses cached state when fetching is unavailable"
