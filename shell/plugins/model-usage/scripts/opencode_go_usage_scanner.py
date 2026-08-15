#!/usr/bin/env python3
"""Read OpenCode Go usage from OpenCode's local SQLite history.

OpenCode does not expose the Go subscription quota through its CLI. The local
database does record the billed cost for each completed assistant response,
which lets the bar show a useful, read-only estimate without touching the
running OpenCode process or its credentials.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sqlite3
import time
from pathlib import Path
from typing import Any


WINDOWS = (
  ("5-hour window", 12.0, 5 * 60 * 60),
  ("Weekly window", 30.0, 7 * 24 * 60 * 60),
  ("Monthly window", 60.0, 30 * 24 * 60 * 60),
)


def expand_path(value: str) -> Path:
  return Path(os.path.expandvars(os.path.expanduser(value))).resolve()


def local_date(timestamp: float) -> str:
  return dt.datetime.fromtimestamp(timestamp).strftime("%Y-%m-%d")


def recent_date_strings() -> list[str]:
  today = dt.datetime.now().date()
  return [(today - dt.timedelta(days=offset)).strftime("%Y-%m-%d") for offset in range(6, -1, -1)]


def number(value: Any) -> float:
  try:
    return float(value or 0)
  except (TypeError, ValueError):
    return 0.0


def integer(value: Any) -> int:
  return max(0, round(number(value)))


def token_bucket() -> dict[str, int]:
  return {
    "inputTokens": 0,
    "outputTokens": 0,
    "cacheReadInputTokens": 0,
    "cacheCreationInputTokens": 0,
  }


def message_tokens(data: dict[str, Any]) -> tuple[int, int, int, int]:
  tokens = data.get("tokens")
  if not isinstance(tokens, dict):
    return 0, 0, 0, 0

  cache = tokens.get("cache")
  if not isinstance(cache, dict):
    cache = {}

  input_tokens = integer(tokens.get("input"))
  output_tokens = integer(tokens.get("output")) + integer(tokens.get("reasoning"))
  cache_read = integer(cache.get("read"))
  cache_write = integer(cache.get("write"))
  return input_tokens, output_tokens, cache_read, cache_write


def has_go_auth(auth_path: Path) -> bool:
  try:
    data = json.loads(auth_path.read_text(encoding="utf-8"))
  except (OSError, ValueError):
    return False
  return isinstance(data, dict) and isinstance(data.get("opencode-go"), dict)


def read_messages(database_path: Path) -> list[dict[str, Any]]:
  if not database_path.is_file():
    return []

  messages: list[dict[str, Any]] = []
  try:
    # SQLite's WAL mode permits this read while OpenCode continues writing.
    connection = sqlite3.connect(f"file:{database_path}?mode=ro", uri=True, timeout=2)
    connection.row_factory = sqlite3.Row
    rows = connection.execute("SELECT id, session_id, time_created, data FROM message").fetchall()
  except (OSError, sqlite3.Error):
    return []
  finally:
    try:
      connection.close()
    except UnboundLocalError:
      pass

  for row in rows:
    try:
      data = json.loads(row["data"])
    except (TypeError, ValueError):
      continue
    if not isinstance(data, dict) or data.get("role") != "assistant":
      continue
    if data.get("providerID") != "opencode-go":
      continue

    cost = max(0.0, number(data.get("cost")))
    input_tokens, output_tokens, cache_read, cache_write = message_tokens(data)
    # OpenCode creates an empty assistant row while a response is streaming.
    # It is not usage until it has a billed cost.
    if cost <= 0:
      continue

    timestamp_ms = integer(row["time_created"])
    if timestamp_ms <= 0:
      message_time = data.get("time")
      if isinstance(message_time, dict):
        timestamp_ms = integer(message_time.get("created"))
    if timestamp_ms <= 0:
      continue

    messages.append({
      "id": str(row["id"]),
      "sessionId": str(row["session_id"]),
      "timestamp": timestamp_ms / 1000.0,
      "model": str(data.get("modelID") or "unknown"),
      "cost": cost,
      "inputTokens": input_tokens,
      "outputTokens": output_tokens,
      "cacheReadInputTokens": cache_read,
      "cacheCreationInputTokens": cache_write,
    })
  return messages


def window_usage(messages: list[dict[str, Any]], now: float, limit: float, seconds: int) -> tuple[float, str]:
  current = [message for message in messages if message["timestamp"] >= now - seconds]
  spent = sum(message["cost"] for message in current)
  percent = min(1.0, spent / limit) if limit > 0 else -1.0
  reset_at = ""
  if current:
    reset_at = dt.datetime.fromtimestamp(
      min(message["timestamp"] + seconds for message in current),
      tz=dt.timezone.utc,
    ).isoformat().replace("+00:00", "Z")
  return percent, reset_at


def scan(database_path: Path, auth_path: Path) -> dict[str, Any]:
  messages = read_messages(database_path)
  authenticated = has_go_auth(auth_path)
  ready = authenticated or bool(messages)
  dates = recent_date_strings()
  today = dates[-1]
  recent = {date: 0 for date in dates}
  today_tokens_by_model: dict[str, int] = {}
  model_usage: dict[str, dict[str, int]] = {}
  active_dates: set[str] = set()
  today_sessions: set[str] = set()
  sessions: set[str] = set()

  today_prompts = 0
  today_total_tokens = 0

  for message in messages:
    day = local_date(message["timestamp"])
    sessions.add(message["sessionId"])
    active_dates.add(day)

    bucket = model_usage.setdefault(message["model"], token_bucket())
    bucket["inputTokens"] += message["inputTokens"]
    bucket["outputTokens"] += message["outputTokens"]
    bucket["cacheReadInputTokens"] += message["cacheReadInputTokens"]
    bucket["cacheCreationInputTokens"] += message["cacheCreationInputTokens"]

    total_tokens = (
      message["inputTokens"]
      + message["outputTokens"]
      + message["cacheReadInputTokens"]
      + message["cacheCreationInputTokens"]
    )
    if day in recent:
      recent[day] += total_tokens
    if day == today:
      today_prompts += 1
      today_sessions.add(message["sessionId"])
      today_total_tokens += total_tokens
      today_tokens_by_model[message["model"]] = today_tokens_by_model.get(message["model"], 0) + total_tokens

  limits = []
  now = time.time()
  for label, limit, seconds in WINDOWS:
    percent, reset_at = window_usage(messages, now, limit, seconds)
    limits.append({"label": label, "limit": limit, "spent": sum(
      message["cost"] for message in messages if message["timestamp"] >= now - seconds
    ), "percent": percent if ready else -1, "resetAt": reset_at})

  return {
    "schemaVersion": 1,
    "ready": ready,
    "hasLocalStats": database_path.is_file(),
    "authenticated": authenticated,
    "providerName": "OpenCode Go",
    "tierLabel": "Go" if ready else "",
    "usageNote": "Local estimate from OpenCode history",
    "usageStatusText": "",
    "authHelpText": "Connect OpenCode Go to restore usage data." if not authenticated else "",
    "todayPrompts": today_prompts,
    "todaySessions": len(today_sessions),
    "todayTotalTokens": today_total_tokens,
    "todayTokensByModel": today_tokens_by_model,
    "recentDays": [{"date": date, "messageCount": recent[date]} for date in dates],
    "totalPrompts": len(messages),
    "totalSessions": len(sessions),
    "activeDays": len(active_dates),
    "activeDates": sorted(active_dates),
    "modelUsage": model_usage,
    "rateLimitPercent": limits[0]["percent"],
    "rateLimitLabel": limits[0]["label"],
    "rateLimitResetAt": limits[0]["resetAt"],
    "rateLimitSpent": limits[0]["spent"],
    "rateLimitLimit": limits[0]["limit"],
    "secondaryRateLimitPercent": limits[1]["percent"],
    "secondaryRateLimitLabel": limits[1]["label"],
    "secondaryRateLimitResetAt": limits[1]["resetAt"],
    "secondaryRateLimitSpent": limits[1]["spent"],
    "secondaryRateLimitLimit": limits[1]["limit"],
    "tertiaryRateLimitPercent": limits[2]["percent"],
    "tertiaryRateLimitLabel": limits[2]["label"],
    "tertiaryRateLimitResetAt": limits[2]["resetAt"],
    "tertiaryRateLimitSpent": limits[2]["spent"],
    "tertiaryRateLimitLimit": limits[2]["limit"],
  }


def main() -> int:
  parser = argparse.ArgumentParser()
  parser.add_argument("database_path", nargs="?", default="~/.local/share/opencode/opencode.db")
  parser.add_argument("auth_path", nargs="?", default="~/.local/share/opencode/auth.json")
  args = parser.parse_args()
  print(json.dumps(scan(expand_path(args.database_path), expand_path(args.auth_path)), separators=(",", ":")))
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
