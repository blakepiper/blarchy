#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

stub_bin="$test_tmp/bin"
git_log="$test_tmp/git.log"
checkout="$test_tmp/checkout"
runtime_dir="$test_tmp/runtime"
mkdir -p "$stub_bin" "$checkout" "$runtime_dir"
printf '#!/bin/bash\nprintf "installed\\n" >>"$TEST_INSTALL_LOG"\n' >"$checkout/install.sh"

cat >"$stub_bin/git" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$TEST_GIT_LOG"
[[ $1 == "-C" ]] || exit 1
shift 2
case "$1" in
  rev-parse)
    case "$2" in
      --is-inside-work-tree) echo true ;;
      --abbrev-ref) echo origin/main ;;
      *) exit 1 ;;
    esac
    ;;
  status)
    [[ ${TEST_GIT_DIRTY:-0} == 0 ]] || echo ' M local-change'
    ;;
  remote)
    echo "${TEST_GIT_REMOTE_URL:-https://github.com/blakepiper/blarchy.git}"
    ;;
  pull)
    [[ $2 == "--ff-only" && $3 == "origin" && $4 == "main" ]]
    ;;
  *) exit 1 ;;
esac
SH
chmod +x "$stub_bin/git"

cat >"$stub_bin/yay" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >"$TEST_YAY_LOG"
SH
chmod +x "$stub_bin/yay"

run_update() {
  BLARCHY_SOURCE_PATH="$checkout" \
  XDG_RUNTIME_DIR="$runtime_dir" \
  TEST_GIT_LOG="$git_log" \
  TEST_INSTALL_LOG="$test_tmp/install.log" \
  PATH="$stub_bin:$PATH" \
    "$ROOT/bin/blarchy-update"
}

: >"$git_log"
run_update >/dev/null
grep -Fx -- "-C $checkout pull --ff-only origin main" "$git_log" >/dev/null ||
  fail "BLARCHY update pulls its tracked branch with fast-forward only" "$(cat "$git_log")"
grep -Fx installed "$test_tmp/install.log" >/dev/null || fail "BLARCHY update reruns the source installer"
pass "BLARCHY update refreshes from the owned repository"

for unsafe in https://github.com/basecamp/omarchy.git git@github.com:someone/blarchy.git; do
  : >"$git_log"
  if TEST_GIT_REMOTE_URL="$unsafe" run_update >"$test_tmp/unsafe.out" 2>"$test_tmp/unsafe.err"; then
    fail "BLARCHY update accepts untrusted remote $unsafe"
  fi
  ! grep -q ' pull ' "$git_log" || fail "BLARCHY update pulls untrusted remote $unsafe"
done
pass "BLARCHY update rejects Omarchy and arbitrary forks"

: >"$git_log"
if TEST_GIT_DIRTY=1 run_update >"$test_tmp/dirty.out" 2>"$test_tmp/dirty.err"; then
  fail "BLARCHY update accepts a dirty source checkout"
fi
! grep -q ' pull ' "$git_log" || fail "BLARCHY update pulls a dirty checkout"
pass "BLARCHY update preserves local development changes"

TEST_YAY_LOG="$test_tmp/yay.log" PATH="$stub_bin:$PATH" \
  "$ROOT/bin/blarchy" system update --devel
grep -Fx -- '-Syu --devel' "$test_tmp/yay.log" >/dev/null ||
  fail "BLARCHY system update does not delegate to yay"
pass "BLARCHY keeps system package updates distinct from source updates"

if rg -q 'basecamp/omarchy|logs\.omarchy\.org' "$ROOT/bin/blarchy" "$ROOT/bin/blarchy-"*; then
  fail "native BLARCHY commands depend on Omarchy infrastructure"
fi
pass "native BLARCHY commands have no Omarchy infrastructure dependency"
