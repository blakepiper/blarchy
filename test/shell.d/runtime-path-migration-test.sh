#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_home=$(mktemp -d)
trap 'rm -rf -- "$test_home"' EXIT

mkdir -p "$test_home/.config/hypr"
printf '%s\n' 'dofile("/usr/share/omarchy/default/hypr/bootstrap.lua")' \
  >"$test_home/.config/hypr/hyprland.lua"
printf '%s\n' 'include "/usr/share/omarchy/default/xcompose"' \
  >"$test_home/.XCompose"

HOME="$test_home" bash "$ROOT/migrations/1787088996.sh" >/dev/null

for config_file in "$test_home/.config/hypr/hyprland.lua" "$test_home/.XCompose"; do
  grep -Fq '/usr/local/share/blarchy' "$config_file" ||
    fail "runtime path migration writes the native BLARCHY path" "$config_file"
  [[ -f $config_file.blarchy-before-runtime-path ]] ||
    fail "runtime path migration backs up changed user configuration" "$config_file"
done
pass "runtime path migration repairs and backs up retained user configuration"
