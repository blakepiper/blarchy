#!/bin/bash

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/base-test.sh"

migration="$ROOT/migrations/1787080695.sh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

bash -n "$migration" || fail "red-glasses migration passes bash syntax validation"
[[ $(stat -c '%a' "$migration") == 644 ]] || fail "red-glasses migration has mode 0644"
pass "red-glasses migration has the required format"

legacy_home="$tmpdir/legacy-home"
mkdir -p "$legacy_home/.config/hypr"
cp "$ROOT/config/hypr/bindings.lua" "$legacy_home/.config/hypr/bindings.lua"
sed -i \
  -e 's/, "SUPER + R"//' \
  -e '/^o\.bind("SUPER + R", "Red-glasses color compensation"/d' \
  "$legacy_home/.config/hypr/bindings.lua"

HOME="$legacy_home" bash "$migration"
legacy_bindings="$legacy_home/.config/hypr/bindings.lua"
grep -Fq '"SUPER + I", "SUPER + R",' "$legacy_bindings" ||
  fail "migration adds Super+R to the unbind list"
grep -Fq 'o.bind("SUPER + R", "Red-glasses color compensation"' "$legacy_bindings" ||
  fail "migration adds the Super+R red-glasses binding"
backup_count=$(find "$legacy_home/.config/hypr" -maxdepth 1 -name 'bindings.lua.bak.*' -type f | wc -l)
(( backup_count == 1 )) || fail "migration backs up the existing bindings file once"
pass "migration adds the red-glasses binding and keeps a backup"

HOME="$legacy_home" bash "$migration"
after_backup_count=$(find "$legacy_home/.config/hypr" -maxdepth 1 -name 'bindings.lua.bak.*' -type f | wc -l)
(( after_backup_count == backup_count )) ||
  fail "migration is idempotent after the red-glasses binding is present"
pass "migration is idempotent after the red-glasses binding is present"
