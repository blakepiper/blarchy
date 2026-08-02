#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

require_command jq

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

mock_bin="$test_tmp/bin"
log="$test_tmp/hyprctl.log"
mkdir -p "$mock_bin" "$test_tmp/runtime"

cat >"$mock_bin/hyprctl" <<'SH'
#!/bin/bash

case "$1" in
  activewindow)
    printf '{"address":"0xabc","monitor":7,"floating":false,"fullscreen":1}\n'
    ;;
  monitors)
    printf '[{"id":7,"x":1920,"y":0,"width":3840,"height":2160,"scale":2,"transform":%s,"reserved":[10,40,20,30]}]\n' "${TEST_MONITOR_TRANSFORM:-0}"
    ;;
  getoption)
    case "$2" in
      general:gaps_out)
        printf '{"option":"general:gaps_out","css":"10 10 10 10"}\n'
        ;;
      general:border_size)
        printf '{"option":"general:border_size","int":2}\n'
        ;;
      *)
        exit 1
        ;;
    esac
    ;;
  dispatch)
    if [[ ${TEST_HYPRCTL_LUA:-1} == 1 && $2 == hl.dsp.* ]]; then
      printf 'lua %s\n' "$*" >>"$TEST_HYPRCTL_LOG"
    else
      printf '%s\n' "$*" >>"$TEST_HYPRCTL_LOG"
    fi
    ;;
  *)
    exit 1
    ;;
esac
SH
chmod +x "$mock_bin/hyprctl"

run_snap() {
  : >"$log"
  TEST_HYPRCTL_LOG="$log" TEST_HYPRCTL_LUA=1 XDG_RUNTIME_DIR="$test_tmp/runtime" PATH="$mock_bin:$PATH" \
    "$ROOT/bin/omarchy-hyprland-window-snap" "$1"
}

run_snap left
grep -Fq 'lua dispatch hl.dsp.window.fullscreen_state({ internal = 0, client = 0 })' "$log" || fail "snap exits fullscreen first"
grep -Fq 'lua dispatch hl.dsp.window.float({ window = "address:0xabc", action = "toggle" })' "$log" || fail "snap floats a tiled window"
grep -Fq 'lua dispatch hl.dsp.window.resize({ window = "address:0xabc", x = 933, y = 986 })' "$log" ||
  fail "left snap uses half the monitor work area" "$(cat "$log")"
grep -Fq 'lua dispatch hl.dsp.window.move({ window = "address:0xabc", x = 1942, y = 52 })' "$log" ||
  fail "left snap respects monitor origin and reserved edges" "$(cat "$log")"
pass "left snap uses scaled monitor geometry and reserved work area"

run_snap right
grep -Fq 'lua dispatch hl.dsp.window.resize({ window = "address:0xabc", x = 933, y = 986 })' "$log" ||
  fail "right snap uses half the monitor work area" "$(cat "$log")"
grep -Fq 'lua dispatch hl.dsp.window.move({ window = "address:0xabc", x = 2875, y = 52 })' "$log" ||
  fail "right snap aligns with the usable right edge" "$(cat "$log")"
pass "right snap aligns predictably on the current monitor"

run_snap down
grep -Fq 'lua dispatch hl.dsp.window.resize({ window = "address:0xabc", x = 1866, y = 493 })' "$log" ||
  fail "down snap uses half the monitor height" "$(cat "$log")"
grep -Fq 'lua dispatch hl.dsp.window.move({ window = "address:0xabc", x = 1942, y = 545 })' "$log" ||
  fail "down snap aligns with the usable bottom edge" "$(cat "$log")"
pass "vertical snapping respects the usable monitor geometry"

if TEST_HYPRCTL_LOG="$log" PATH="$mock_bin:$PATH" \
  "$ROOT/bin/omarchy-hyprland-window-snap" diagonal >/dev/null 2>&1; then
  fail "snap rejects an invalid direction"
fi
pass "snap rejects invalid directions"
