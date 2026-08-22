#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

bash -n "$ROOT/install/user/xfce-model-usage.sh"

[[ -x "$ROOT/bin/xfce-model-usage-dialog" ]]

ROOT="$ROOT" python3 - <<'PY'
import ast
import os

with open(os.path.join(os.environ["ROOT"], "bin", "xfce-model-usage-dialog"), encoding="utf-8") as dialog:
  ast.parse(dialog.read())
PY

ROOT="$ROOT" python3 - <<'PY'
import os
import runpy

module = runpy.run_path(os.path.join(os.environ["ROOT"], "bin", "omarchy-model-usage-xfce"))
data = {
  "updatedAt": 0,
  "providers": [
    {
      "name": "Codex",
      "tier": "",
      "status": "",
      "limits": [{"label": "Session", "percent": 0.25, "resetAt": ""}],
      "todayTokens": 1200,
      "todayPrompts": 3,
    },
  ],
}
rendered = module["rendered_output"](data)
details = module["details_text"](data)
assert "<txt>AI 75% left</txt>" in rendered
assert "<txtclick>" in rendered
assert "AI usage" not in details
assert "Session: 25% used · 75% left" in details
assert "Today: 1.2K tokens · 3 prompts" in details
assert module["pretty_tier"]("default_claude_ai", "") == "Default Claude AI"
PY

pass "XFCE model usage renderer emits panel and details output"
