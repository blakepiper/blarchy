#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

test_root="$test_tmp/omarchy"
configured_root="$test_tmp/configured-runtime"
test_home="$test_tmp/home"
stub_bin="$test_tmp/bin"
install_config="$test_tmp/blarchy.conf"
configured_marker="$test_tmp/configured-migration-ran"
mkdir -p "$test_root/migrations" "$configured_root/migrations" "$test_home" "$stub_bin"

printf "export BLARCHY_PATH='%s'\n" "$configured_root" >"$install_config"
cat >"$configured_root/migrations/050-system-config.sh" <<SH
touch "$configured_marker"
SH

cat >"$stub_bin/omarchy-notification-dismiss" <<'SH'
#!/bin/bash
printf '%s\n' "$1" >>"$TEST_DISMISSALS"
SH
cat >"$stub_bin/sudo" <<'SH'
#!/bin/bash
echo "sudo must not run during migrate-wrapper-test" >&2
exit 99
SH
chmod +x "$stub_bin/omarchy-notification-dismiss" "$stub_bin/sudo"

cat >"$test_root/migrations/100-migration.sh" <<'SH'
echo migration >>"$TEST_CALLS"
SH

run_migrate() {
  env -u BLARCHY_PATH -u BLARCHY_INSTALL \
    HOME="$test_home" \
    BLARCHY_INSTALL_CONFIG="$install_config" \
    OMARCHY_PATH="$test_root" \
    OMARCHY_INSTALL="$test_root/install" \
    PATH="$stub_bin:$ROOT/bin:$PATH" \
    TEST_CALLS="$test_tmp/calls" \
    TEST_DISMISSALS="$test_tmp/dismissals" \
    "$ROOT/bin/omarchy-migrate" "$@"
}

: >"$test_tmp/calls"
run_migrate >"$test_tmp/migrate.out"
[[ $(sed -n '1p' "$test_tmp/calls") == "migration" ]] || fail "omarchy-migrate runs pending migrations"
[[ ! -e $configured_marker ]] || fail "explicit compatibility path overrides the installed runtime config"
pass "omarchy-migrate runs migrations without force"

grep -Fx 'BLARCHY Migrations' "$test_tmp/dismissals" >/dev/null || fail "omarchy-migrate dismisses migration notifications"
pass "omarchy-migrate clears completed migration notifications"

rm -rf "$test_home/.local/state/blarchy/migrations"
run_migrate --pending >"$test_tmp/pending.out"
grep -q '^100-migration\.sh$' "$test_tmp/pending.out" || fail "omarchy-migrate --pending lists pending migrations"
pass "omarchy-migrate --pending lists pending migrations"

run_migrate >"$test_tmp/migrate-second.out"
if run_migrate --pending >"$test_tmp/not-pending.out"; then
  fail "omarchy-migrate --pending exits non-zero without pending migrations"
fi
[[ ! -s $test_tmp/not-pending.out ]] || fail "omarchy-migrate --pending stays quiet without pending migrations"
pass "omarchy-migrate --pending reports no pending migrations"

if run_migrate --force >"$test_tmp/force.out" 2>&1; then
  fail "omarchy-migrate rejects obsolete --force option"
fi
grep -q 'Unknown option: --force' "$test_tmp/force.out" || fail "omarchy-migrate reports obsolete --force option"
pass "omarchy-migrate no longer needs --force"
