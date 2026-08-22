#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

command="$ROOT/bin/omarchy-xfce-nightlight"
setup="$ROOT/install/user/xfce-nightlight.sh"

[[ -x $command ]]
[[ -x $setup ]]
[[ -x $ROOT/bin/omarchy-xfce-nightlight-overlay ]]
bash -n "$command"
bash -n "$setup"
ROOT="$ROOT" python3 - <<'PY'
import ast
import os

path = os.path.join(os.environ["ROOT"], "bin", "omarchy-xfce-nightlight-overlay")
with open(path, encoding="utf-8") as overlay:
  ast.parse(overlay.read())
PY

rg -q 'nightlight-xfce-overlay.pid' "$command"
rg -q 'XShapeCombineRectangles' "$ROOT/bin/omarchy-xfce-nightlight-overlay"
rg -q '0x33ffffff' "$ROOT/bin/omarchy-xfce-nightlight-overlay"
rg -q 'Day Light' "$command"
rg -q 'Night Light' "$command"
rg -q 'xfce-nightlight' "$ROOT/install/user/all.sh"
rg -q '#fff' "$ROOT/default/omarchy/icons/nightlight-full-white.svg"
rg -q '#fff' "$ROOT/default/omarchy/icons/nightlight-empty-white.svg"

pass "XFCE nightlight widget and X11 overlay are wired"
