#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

require_command jq

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

mock_bin="$test_tmp/bin"
log="$test_tmp/hyprctl.log"
mkdir -p "$mock_bin"

cat >"$mock_bin/hyprctl" <<'SH'
#!/bin/bash

case "$1" in
  activewindow)
    printf '{"address":"0xabc","monitor":7,"floating":false,"fullscreen":1}\n'
    ;;
  monitors)
    printf '[{"id":7,"x":1920,"y":0,"width":3840,"height":2160,"scale":2,"transform":%s,"reserved":[10,40,20,30]}]\n' "${TEST_MONITOR_TRANSFORM:-0}"
    ;;
  dispatch)
    printf '%s\n' "$*" >>"$TEST_HYPRCTL_LOG"
    ;;
  *)
    exit 1
    ;;
esac
SH
chmod +x "$mock_bin/hyprctl"

run_snap() {
  : >"$log"
  TEST_HYPRCTL_LOG="$log" PATH="$mock_bin:$PATH" \
    "$ROOT/bin/omarchy-hyprland-window-snap" "$1"
}

run_snap left
grep -Fxq 'dispatch fullscreen 0' "$log" || fail "snap exits fullscreen first"
grep -Fxq 'dispatch setfloating address:0xabc' "$log" || fail "snap floats a tiled window"
grep -Fxq 'dispatch resizewindowpixel exact 945 1010,address:0xabc' "$log" ||
  fail "left snap uses half the monitor work area" "$(cat "$log")"
grep -Fxq 'dispatch movewindowpixel exact 1930 40,address:0xabc' "$log" ||
  fail "left snap respects monitor origin and reserved edges" "$(cat "$log")"
pass "left snap uses scaled monitor geometry and reserved work area"

run_snap right
grep -Fxq 'dispatch resizewindowpixel exact 945 1010,address:0xabc' "$log" ||
  fail "right snap uses half the monitor work area" "$(cat "$log")"
grep -Fxq 'dispatch movewindowpixel exact 2875 40,address:0xabc' "$log" ||
  fail "right snap aligns with the usable right edge" "$(cat "$log")"
pass "right snap aligns predictably on the current monitor"

run_snap down
grep -Fxq 'dispatch resizewindowpixel exact 1890 505,address:0xabc' "$log" ||
  fail "down snap uses half the monitor height" "$(cat "$log")"
grep -Fxq 'dispatch movewindowpixel exact 1930 545,address:0xabc' "$log" ||
  fail "down snap aligns with the usable bottom edge" "$(cat "$log")"
pass "vertical snapping respects the usable monitor geometry"

if TEST_HYPRCTL_LOG="$log" PATH="$mock_bin:$PATH" \
  "$ROOT/bin/omarchy-hyprland-window-snap" diagonal >/dev/null 2>&1; then
  fail "snap rejects an invalid direction"
fi
pass "snap rejects invalid directions"
