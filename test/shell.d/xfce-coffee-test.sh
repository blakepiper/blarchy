#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

bash -n "$ROOT/bin/omarchy-xfce-coffee"
bash -n "$ROOT/install/user/xfce-coffee.sh"

[[ -f $ROOT/config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml ]]
rg -q 'WindowScalingFactor.*value="2"' \
  "$ROOT/config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml"
rg -q 'Resolution.*value="2880x1800"' \
  "$ROOT/config/xfce4/xfconf/xfce-perchannel-xml/displays.xml"
rg -q 'update-period.*-s 5000' "$ROOT/install/user/xfce-coffee.sh"
rg -q '#fff' "$ROOT/default/omarchy/icons/caffeine-cup-full-white.svg"
rg -q '#fff' "$ROOT/default/omarchy/icons/caffeine-cup-empty-white.svg"

test_home=$(mktemp -d)
trap 'rm -rf -- "$test_home"' EXIT

rendered=$(HOME="$test_home" RICE_PATH="$ROOT" "$ROOT/bin/omarchy-xfce-coffee" render)
[[ $rendered == *"$ROOT/default/omarchy/icons/caffeine-cup-empty-white.svg"* ]]
[[ $rendered == *"<click>"*toggle*"</click>"* ]]

pass "XFCE coffee widget and HiDPI configuration are wired"
