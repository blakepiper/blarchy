#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

bash -n "$ROOT/bin/omarchy-xfce-coffee"
bash -n "$ROOT/install/user/xfce-coffee.sh"
bash -n "$ROOT/install/user/xfce-power.sh"

[[ -f $ROOT/config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml ]]
power_config="$ROOT/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml"
[[ -f $power_config ]]
[[ $(grep -c 'lid-action-on-.*type="uint" value="1"' "$power_config") == 2 ]]
rg -q 'logind-handle-lid-switch.*type="bool" value="false"' "$power_config"
rg -q 'WindowScalingFactor.*value="2"' \
  "$ROOT/config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml"
rg -q 'Resolution.*value="2880x1800"' \
  "$ROOT/config/xfce4/xfconf/xfce-perchannel-xml/displays.xml"
rg -q 'update-period.*-s 5000' "$ROOT/install/user/xfce-coffee.sh"
rg -q -- '--what=idle' "$ROOT/bin/omarchy-xfce-coffee"
if rg -q -- '--what=.*sleep' "$ROOT/bin/omarchy-xfce-coffee"; then
  fail "XFCE Coffee must not inhibit explicit sleep"
fi
rg -q '#fff' "$ROOT/default/omarchy/icons/caffeine-cup-full-white.svg"
rg -q '#fff' "$ROOT/default/omarchy/icons/caffeine-cup-empty-white.svg"

test_home=$(mktemp -d)
trap 'rm -rf -- "$test_home"' EXIT

mock_bin="$test_home/bin"
call_log="$test_home/xfconf-calls"
mkdir -p "$mock_bin"
cat >"$mock_bin/xfconf-query" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$CALL_LOG"
SH
chmod +x "$mock_bin/xfconf-query"

CALL_LOG="$call_log" PATH="$mock_bin:$PATH" "$ROOT/install/user/xfce-power.sh"
grep -Fq -- '-p /xfce4-power-manager/lid-action-on-ac -n -t uint -s 1' "$call_log"
grep -Fq -- '-p /xfce4-power-manager/lid-action-on-battery -n -t uint -s 1' "$call_log"
grep -Fq -- '-p /xfce4-power-manager/logind-handle-lid-switch -n -t bool -s false' "$call_log"

rendered=$(HOME="$test_home" RICE_PATH="$ROOT" "$ROOT/bin/omarchy-xfce-coffee" render)
[[ $rendered == *"$ROOT/default/omarchy/icons/caffeine-cup-empty-white.svg"* ]]
[[ $rendered == *"<click>"*toggle*"</click>"* ]]

pass "XFCE coffee widget and HiDPI configuration are wired"
