#!/bin/bash

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/base-test.sh"

toggle="$ROOT/bin/omarchy-toggle-red-glasses"
invert="$ROOT/bin/omarchy-toggle-invert"
shader="$ROOT/config/hypr/shaders/red-glasses-compensation.glsl"
invert_shader="$ROOT/config/hypr/shaders/invert-colors.glsl"

[[ -x $toggle ]] || fail "red-glasses compensation command is executable"
bash -n "$toggle" || fail "red-glasses compensation command passes bash syntax validation"
grep -Fq 'o.bind("SUPER + R", "Red-glasses color compensation"' "$ROOT/config/hypr/bindings.lua" ||
  fail "SUPER+R is bound to red-glasses compensation"
grep -Fq '"SUPER + R"' "$ROOT/config/hypr/bindings.lua" ||
  fail "SUPER+R is explicitly unbound before the override"
grep -Fq 'const vec3 COMPENSATION_GAINS' "$shader" ||
  fail "red-glasses shader defines channel compensation gains"
grep -Fq 'const float BRIGHTNESS_BOOST' "$shader" ||
  fail "red-glasses shader boosts display brightness"
grep -Fq 'const float CONTRAST' "$shader" ||
  fail "red-glasses shader defines contrast adjustment"
grep -Fq 'const float TONE_MAPPING_EXPOSURE' "$shader" ||
  fail "red-glasses shader defines highlight tone mapping"
grep -Fq 'vec3(1.15, 2.40, 1.70)' "$shader" ||
  fail "red-glasses shader uses the green-forward compensation profile"
grep -Fq 'const float CONTRAST = 1.25;' "$shader" ||
  fail "red-glasses shader uses the intended contrast adjustment"
grep -Fq 'const float TONE_MAPPING_EXPOSURE = 1.35;' "$shader" ||
  fail "red-glasses shader uses the intended highlight tone mapping"
grep -Fq '#version 300 es' "$shader" ||
  fail "red-glasses shader matches Hyprland's GLSL interface"
pass "red-glasses compensation defaults are wired into BLARCHY"

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

shader_state=${BLARCHY_RED_TEST_SHADER_STATE:?}
damage_state=${BLARCHY_RED_TEST_DAMAGE_STATE:?}
case "$1 $2" in
  "getoption decoration:screen_shader")
    jq -cn --arg shader "$(<"$shader_state")" '{str:$shader}'
    ;;
  "getoption debug:damage_tracking")
    jq -cn --argjson damage "$(<"$damage_state")" '{int:$damage}'
    ;;
  "eval hl.config({ decoration = { screen_shader = \"$BLARCHY_RED_TEST_SHADER\" }, debug = { damage_tracking = 0 } })")
    printf '%s\n' "$BLARCHY_RED_TEST_SHADER" >"$shader_state"
    printf '0\n' >"$damage_state"
    ;;
  "eval hl.config({ decoration = { screen_shader = \"$BLARCHY_INVERT_TEST_SHADER\" }, debug = { damage_tracking = 0 } })")
    printf '%s\n' "$BLARCHY_INVERT_TEST_SHADER" >"$shader_state"
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

run_red() {
  PATH="$fake_bin:$PATH" BLARCHY_PATH="$ROOT" \
    BLARCHY_SCREEN_FILTER_STATE_DIR="$toggle_state" \
    BLARCHY_RED_TEST_SHADER_STATE="$shader_state" \
    BLARCHY_RED_TEST_DAMAGE_STATE="$damage_state" \
    BLARCHY_RED_TEST_SHADER="$shader" \
    BLARCHY_INVERT_TEST_SHADER="$invert_shader" "$toggle" >/dev/null
}

run_invert() {
  PATH="$fake_bin:$PATH" BLARCHY_PATH="$ROOT" \
    BLARCHY_SCREEN_FILTER_STATE_DIR="$toggle_state" \
    BLARCHY_RED_TEST_SHADER_STATE="$shader_state" \
    BLARCHY_RED_TEST_DAMAGE_STATE="$damage_state" \
    BLARCHY_RED_TEST_SHADER="$shader" \
    BLARCHY_INVERT_TEST_SHADER="$invert_shader" "$invert" >/dev/null
}

run_red
[[ $(<"$shader_state") == $shader ]] || fail "red-glasses command enables its shader"
[[ $(<"$damage_state") == 0 ]] || fail "red-glasses command disables partial-damage rendering"
[[ $(<"$toggle_state/screen-filter-damage-tracking") == 2 ]] ||
  fail "red-glasses command saves the previous damage tracking mode"

run_red
[[ -z $(<"$shader_state") ]] || fail "red-glasses command disables its shader"
[[ $(<"$damage_state") == 2 ]] || fail "red-glasses command restores full damage tracking"
[[ ! -e $toggle_state/screen-filter-damage-tracking ]] || fail "red-glasses command removes saved damage state"

run_red
[[ $(<"$shader_state") == $shader ]] || fail "red-glasses command can be enabled again"

run_invert
[[ $(<"$shader_state") == $invert_shader ]] || fail "inversion switches from red-glasses compensation"
[[ $(<"$toggle_state/screen-filter-damage-tracking") == 2 ]] ||
  fail "switching filters preserves the saved damage tracking mode"

run_invert
[[ -z $(<"$shader_state") ]] || fail "inversion disables the active screen filter"
[[ $(<"$damage_state") == 2 ]] || fail "screen filter restores full damage tracking"
[[ ! -e $toggle_state/screen-filter-damage-tracking ]] || fail "screen filter removes saved damage state"
pass "red-glasses compensation and inversion switch safely"
