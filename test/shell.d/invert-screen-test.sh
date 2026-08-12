#!/bin/bash

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/base-test.sh"

toggle="$ROOT/bin/omarchy-toggle-invert"
shader="$ROOT/config/hypr/shaders/invert-colors.glsl"

[[ -x $toggle ]] || fail "screen inversion command is executable"
bash -n "$toggle" || fail "screen inversion command passes bash syntax validation"
grep -Fq 'o.bind("SUPER + I", "Invert screen colors"' "$ROOT/config/hypr/bindings.lua" ||
  fail "SUPER+I is bound to screen inversion"
grep -Fq '"SUPER + I"' "$ROOT/config/hypr/bindings.lua" ||
  fail "SUPER+I is explicitly unbound before the override"
grep -Fq '1.0 - pixel.rgb' "$shader" ||
  fail "screen inversion shader inverts RGB channels"
grep -Fq '#version 300 es' "$shader" ||
  fail "screen inversion shader matches Hyprland's GLSL interface"
pass "screen inversion defaults are wired into BLARCHY"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

fake_bin="$test_tmp/bin"
state_file="$test_tmp/shader-state"
mkdir -p "$fake_bin"
printf '[[EMPTY]]\n' >"$state_file"
cat >"$fake_bin/hyprctl" <<'HYPRCTL'
#!/bin/bash

set -euo pipefail

state_file=${BLARCHY_INVERT_TEST_STATE:?}
case "$1 $2" in
  "getoption decoration:screen_shader")
    jq -cn --arg shader "$(<"$state_file")" '{str:$shader}'
    ;;
  "eval hl.config({ decoration = { screen_shader = \"$BLARCHY_INVERT_TEST_SHADER\" } })")
    printf '%s\n' "$BLARCHY_INVERT_TEST_SHADER" >"$state_file"
    ;;
  "eval hl.config({ decoration = { screen_shader = \"\" } })")
    printf '\n' >"$state_file"
    ;;
  *)
    exit 1
    ;;
esac
HYPRCTL
chmod +x "$fake_bin/hyprctl"

PATH="$fake_bin:$PATH" BLARCHY_PATH="$ROOT" BLARCHY_INVERT_TEST_STATE="$state_file" \
  BLARCHY_INVERT_TEST_SHADER="$shader" "$toggle" >/dev/null
[[ $(<"$state_file") == $shader ]] || fail "screen inversion command enables the shader"
PATH="$fake_bin:$PATH" BLARCHY_PATH="$ROOT" BLARCHY_INVERT_TEST_STATE="$state_file" \
  BLARCHY_INVERT_TEST_SHADER="$shader" "$toggle" >/dev/null
[[ -z $(<"$state_file") ]] || fail "screen inversion command disables the shader"
pass "screen inversion command toggles between inverted and normal colors"
