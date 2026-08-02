#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

mock_bin="$test_tmp/bin"
runtime_dir="$test_tmp/runtime"
log="$test_tmp/calls"
mkdir -p "$mock_bin" "$runtime_dir/omarchy-window-snap"
printf '%s\n' left >"$runtime_dir/omarchy-window-snap/0xold"

cat >"$mock_bin/hyprctl" <<'SH'
#!/bin/bash
case "$1" in
  activewindow)
    printf '%s\n' '{"address":"0xold"}'
    ;;
  clients)
    printf '%s\n' '[{"address":"0xold","floating":true,"workspace":{"id":1}}]'
    ;;
  dispatch)
    printf 'hyprctl %s\n' "$*" >>"$TEST_LOG"
    ;;
  *)
    exit 1
    ;;
esac
SH

chmod +x "$mock_bin/hyprctl"

XDG_RUNTIME_DIR="$runtime_dir" TEST_LOG="$log" PATH="$mock_bin:$PATH" \
  "$ROOT/bin/omarchy-hyprland-window-prepare-launch"

grep -Fxq 'hyprctl dispatch layoutmsg preselect r' "$log" ||
  fail "launch preparation selects the opposite side for the new window"
grep -Fxq 'hyprctl dispatch togglefloating address:0xold' "$log" ||
  fail "launch preparation restores the snapped window to the tiling tree"
[[ ! -e "$runtime_dir/omarchy-window-snap/0xold" ]] ||
  fail "launch preparation clears the pending snap state"
pass "launch preparation restores global tiling before an app maps"
