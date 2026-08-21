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
pass "screen inversion defaults are wired into RICE"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

fake_bin="$test_tmp/bin"
shader_state="$test_tmp/shader-state"
damage_state="$test_tmp/damage-state"
toggle_state="$test_tmp/toggle-state"
mkdir -p "$fake_bin"
printf '[[EMPTY]]\n' >"$shader_state"
printf '2\n' >"$damage_state"
cat >"$fake_bin/hyprctl" <<'HYPRCTL'
#!/bin/bash

set -euo pipefail

shader_state=${RICE_INVERT_TEST_SHADER_STATE:?}
damage_state=${RICE_INVERT_TEST_DAMAGE_STATE:?}
case "$1 $2" in
  "getoption decoration:screen_shader")
    jq -cn --arg shader "$(<"$shader_state")" '{str:$shader}'
    ;;
  "getoption debug:damage_tracking")
    jq -cn --argjson damage "$(<"$damage_state")" '{int:$damage}'
    ;;
  "eval hl.config({ decoration = { screen_shader = \"$RICE_INVERT_TEST_SHADER\" }, debug = { damage_tracking = 0 } })")
    printf '%s\n' "$RICE_INVERT_TEST_SHADER" >"$shader_state"
    printf '0\n' >"$damage_state"
    ;;
  "eval hl.config({ decoration = { screen_shader = \"\" }, debug = { damage_tracking = 2 } })")
    printf '\n' >"$shader_state"
    printf '2\n' >"$damage_state"
    ;;
  *)
    exit 1
    ;;
esac
HYPRCTL
chmod +x "$fake_bin/hyprctl"

run_toggle() {
  PATH="$fake_bin:$PATH" RICE_PATH="$ROOT" RICE_INVERT_STATE_DIR="$toggle_state" \
    RICE_INVERT_TEST_SHADER_STATE="$shader_state" RICE_INVERT_TEST_DAMAGE_STATE="$damage_state" \
    RICE_INVERT_TEST_SHADER="$shader" "$toggle" >/dev/null
}

run_toggle
[[ $(<"$shader_state") == $shader ]] || fail "screen inversion command enables the shader"
[[ $(<"$damage_state") == 0 ]] || fail "screen inversion disables partial-damage rendering"
[[ $(<"$toggle_state/screen-filter-damage-tracking") == 2 ]] ||
  fail "screen inversion saves the previous damage tracking mode"

run_toggle
[[ -z $(<"$shader_state") ]] || fail "screen inversion command disables the shader"
[[ $(<"$damage_state") == 2 ]] || fail "screen inversion restores full damage tracking"
[[ ! -e $toggle_state/screen-filter-damage-tracking ]] || fail "screen inversion removes saved state when disabled"
pass "screen inversion toggles safely without partial-damage flicker"
