#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

migration="$ROOT/migrations/1786901778.sh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

bash -n "$migration" || fail "Super+C migration passes bash syntax validation"
pass "Super+C migration passes bash syntax validation"

legacy_home="$tmpdir/legacy-home"
mkdir -p "$legacy_home/.config/hypr"
cp "$ROOT/config/hypr/bindings.lua" "$legacy_home/.config/hypr/bindings.lua"
sed -i \
  -e 's/"SUPER + SPACE", "SUPER + RETURN", "SUPER + C", /"SUPER + SPACE", "SUPER + RETURN", /' \
  -e '/^o\.bind("SUPER + C", "VSCodium"/d' \
  "$legacy_home/.config/hypr/bindings.lua"

HOME="$legacy_home" bash "$migration"
legacy_bindings="$legacy_home/.config/hypr/bindings.lua"
grep -Fq '"SUPER + RETURN", "SUPER + C", "SUPER + F"' "$legacy_bindings" ||
  fail "migration unbinds inherited Super+C clipboard behavior"
grep -Fq 'o.bind("SUPER + C", "VSCodium", { launch = "codium" })' "$legacy_bindings" ||
  fail "migration binds Super+C to VSCodium"
backup_count=$(find "$legacy_home/.config/hypr" -maxdepth 1 -name 'bindings.lua.bak.*' -type f | wc -l)
(( backup_count == 1 )) || fail "migration backs up the existing bindings file once"
pass "migration repairs the legacy bindings file and keeps a backup"

before_backup_count=$backup_count
HOME="$legacy_home" bash "$migration"
after_backup_count=$(find "$legacy_home/.config/hypr" -maxdepth 1 -name 'bindings.lua.bak.*' -type f | wc -l)
(( after_backup_count == before_backup_count )) ||
  fail "migration is idempotent after Super+C is present"
pass "migration is idempotent after Super+C is present"

custom_home="$tmpdir/custom-home"
mkdir -p "$custom_home/.config/hypr"
cp "$ROOT/config/hypr/bindings.lua" "$custom_home/.config/hypr/bindings.lua"
sed -i 's/VSCodium/Custom editor/' "$custom_home/.config/hypr/bindings.lua"

HOME="$custom_home" bash "$migration"
grep -Fq 'o.bind("SUPER + C", "Custom editor", { launch = "codium" })' \
  "$custom_home/.config/hypr/bindings.lua" ||
  fail "migration preserves an existing Super+C customization"
if find "$custom_home/.config/hypr" -maxdepth 1 -name 'bindings.lua.bak.*' -type f | grep -q .; then
  fail "migration does not back up an already customized Super+C binding"
fi
pass "migration preserves an existing Super+C customization"
