#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

command="$ROOT/bin/omarchy-xfce-nightlight"
setup="$ROOT/install/user/xfce-nightlight.sh"

[[ -x $command ]]
[[ -x $setup ]]
bash -n "$command"
bash -n "$setup"

rg -q 'night_gamma="1:0.8071225:0.6512994"' "$command"
rg -q 'day_gamma="1:1:1"' "$command"
rg -q 'Day Light' "$command"
rg -q 'Night Light' "$command"
rg -q 'xfce-nightlight' "$ROOT/install/user/all.sh"
rg -q '#fff' "$ROOT/default/omarchy/icons/nightlight-full-white.svg"
rg -q '#fff' "$ROOT/default/omarchy/icons/nightlight-empty-white.svg"

pass "XFCE nightlight widget and X11 gamma fallback are wired"
