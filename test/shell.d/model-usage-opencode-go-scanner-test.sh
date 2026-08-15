#!/bin/bash

source "$(dirname "$0")/base-test.sh"

require_command jq
require_command python3

test_home=$(mktemp -d)
trap 'rm -rf "$test_home"' EXIT

db="$test_home/opencode.db"
auth="$test_home/auth.json"
usage="$test_home/usage.json"

python3 - "$db" "$auth" "$usage" <<'PY'
import json
import sqlite3
import sys
import time

database_path, auth_path, usage_path = sys.argv[1:]
now_ms = round(time.time() * 1000)

connection = sqlite3.connect(database_path)
connection.execute("CREATE TABLE message (id TEXT PRIMARY KEY, session_id TEXT, time_created INTEGER, data TEXT)")


def add_message(message_id, session_id, age_seconds, cost, model, input_tokens, output_tokens, cache_read, cache_write):
  data = {
    "role": "assistant",
    "providerID": "opencode-go",
    "modelID": model,
    "cost": cost,
    "tokens": {
      "input": input_tokens,
      "output": output_tokens,
      "reasoning": 0,
      "cache": {"read": cache_read, "write": cache_write},
    },
  }
  connection.execute(
    "INSERT INTO message VALUES (?, ?, ?, ?)",
    (message_id, session_id, now_ms - age_seconds * 1000, json.dumps(data)),
  )


add_message("recent", "session-1", 60, 3, "gpt-test", 10, 20, 30, 40)
add_message("weekly", "session-2", 10 * 60 * 60, 4, "gpt-test", 1, 2, 3, 4)
add_message("monthly", "session-3", 8 * 24 * 60 * 60, 9, "deepseek-test", 5, 6, 7, 8)
add_message("pending", "session-4", 60, 0, "gpt-test", 999, 999, 999, 999)
connection.commit()
connection.close()

with open(auth_path, "w", encoding="utf-8") as handle:
  json.dump({"opencode-go": {"type": "api", "key": "not-read-by-test-output"}}, handle)

with open(usage_path, "w", encoding="utf-8") as handle:
  json.dump({
    "usage": {
      "rolling": {"status": "ok", "percent": 72, "resetsAt": "2030-01-02T03:04:05Z"},
      "weekly": {"status": "ok", "percent": 28, "resetsAt": "2030-01-08T00:00:00Z"},
      "monthly": {"status": "ok", "percent": 14, "resetsAt": "2030-02-01T00:00:00Z"},
    },
  }, handle)
PY

result=$(python3 "$ROOT/shell/plugins/model-usage/scripts/opencode_go_usage_scanner.py" "$db" "$auth" "file://$usage")

[[ $(jq -r '.ready' <<<"$result") == "true" ]] || fail "OpenCode Go scanner detects auth" "$result"
pass "OpenCode Go scanner detects auth"

[[ $(jq -r '.totalPrompts' <<<"$result") == "3" ]] || fail "OpenCode Go scanner ignores streaming rows" "$result"
pass "OpenCode Go scanner ignores streaming rows"

[[ $(jq -r '.todayTotalTokens' <<<"$result") == "110" ]] || fail "OpenCode Go scanner totals token categories" "$result"
pass "OpenCode Go scanner totals token categories"

[[ $(jq -r '.rateLimitPercent' <<<"$result") == "0.72" ]] || fail "OpenCode Go scanner reports the server five-hour usage" "$result"
pass "OpenCode Go scanner reports the server five-hour usage"

[[ $(jq -r '.secondaryRateLimitPercent' <<<"$result") == "0.28" ]] || fail "OpenCode Go scanner reports the server weekly usage" "$result"
pass "OpenCode Go scanner reports the server weekly usage"

[[ $(jq -r '.tertiaryRateLimitPercent' <<<"$result") == "0.14" ]] || fail "OpenCode Go scanner reports the server monthly usage" "$result"
pass "OpenCode Go scanner reports the server monthly usage"

[[ $(jq -r '.rateLimitResetAt' <<<"$result") == "2030-01-02T03:04:05Z" ]] || fail "OpenCode Go scanner reports the server five-hour reset" "$result"
pass "OpenCode Go scanner reports the server five-hour reset"

[[ $(jq -r '.usageNote' <<<"$result") == "Live limits from OpenCode Go" ]] || fail "OpenCode Go scanner labels live limits" "$result"
pass "OpenCode Go scanner labels live limits"

[[ $(jq -r '.rateLimitSpent' <<<"$result") == "-1" && $(jq -r '.rateLimitLimit' <<<"$result") == "12.0" ]] ||
  fail "OpenCode Go scanner does not invent dollar usage" "$result"
pass "OpenCode Go scanner does not invent dollar usage"

[[ $(jq -c '.modelUsage["gpt-test"]' <<<"$result") == '{"inputTokens":11,"outputTokens":22,"cacheReadInputTokens":33,"cacheCreationInputTokens":44}' ]] ||
  fail "OpenCode Go scanner groups model tokens" "$result"
pass "OpenCode Go scanner groups model tokens"
