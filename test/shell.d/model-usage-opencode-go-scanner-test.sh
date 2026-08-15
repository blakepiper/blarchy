#!/bin/bash

source "$(dirname "$0")/base-test.sh"

require_command jq
require_command python3

test_home=$(mktemp -d)
trap 'rm -rf "$test_home"' EXIT

db="$test_home/opencode.db"
auth="$test_home/auth.json"

python3 - "$db" "$auth" <<'PY'
import json
import sqlite3
import sys
import time

database_path, auth_path = sys.argv[1:]
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
PY

result=$(python3 "$ROOT/shell/plugins/model-usage/scripts/opencode_go_usage_scanner.py" "$db" "$auth")

[[ $(jq -r '.ready' <<<"$result") == "true" ]] || fail "OpenCode Go scanner detects auth" "$result"
pass "OpenCode Go scanner detects auth"

[[ $(jq -r '.totalPrompts' <<<"$result") == "3" ]] || fail "OpenCode Go scanner ignores streaming rows" "$result"
pass "OpenCode Go scanner ignores streaming rows"

[[ $(jq -r '.todayTotalTokens' <<<"$result") == "110" ]] || fail "OpenCode Go scanner totals token categories" "$result"
pass "OpenCode Go scanner totals token categories"

[[ $(jq -r '.rateLimitPercent' <<<"$result") == "0.25" ]] || fail "OpenCode Go scanner reports the five-hour estimate" "$result"
pass "OpenCode Go scanner reports the five-hour estimate"

[[ $(jq -r '.secondaryRateLimitPercent' <<<"$result") == "0.23333333333333334" ]] || fail "OpenCode Go scanner reports the weekly estimate" "$result"
pass "OpenCode Go scanner reports the weekly estimate"

[[ $(jq -c '.modelUsage["gpt-test"]' <<<"$result") == '{"inputTokens":11,"outputTokens":22,"cacheReadInputTokens":33,"cacheCreationInputTokens":44}' ]] ||
  fail "OpenCode Go scanner groups model tokens" "$result"
pass "OpenCode Go scanner groups model tokens"
