#!/usr/bin/env python3
"""Read OpenCode Go limits and local token history.

The usage endpoint is authoritative for the subscription limits. OpenCode's
local SQLite database supplies the token and model history shown below it.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import os
import sqlite3
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


USAGE_URL = "https://opencode.ai/zen/go/v1/usage"

WINDOWS = (
  ("5-hour window", "rolling"),
  ("Weekly window", "weekly"),
  ("Monthly window", "monthly"),
)


def expand_path(value: str) -> Path:
  return Path(os.path.expandvars(os.path.expanduser(value))).resolve()


def local_date(timestamp: float) -> str:
  return dt.datetime.fromtimestamp(timestamp).strftime("%Y-%m-%d")


def number(value: Any) -> float:
  try:
    return float(value or 0)
  except (TypeError, ValueError):
    return 0.0


def integer(value: Any) -> int:
  return max(0, round(number(value)))


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


def read_go_api_key(auth_path: Path) -> str:
  try:
    data = json.loads(auth_path.read_text(encoding="utf-8"))
  except (OSError, ValueError):
    return ""
  if not isinstance(data, dict) or not isinstance(data.get("opencode-go"), dict):
    return ""
  key = data["opencode-go"].get("key")
  return str(key).strip() if key else ""


def fetch_remote_usage(api_key: str, usage_url: str) -> dict[str, Any] | None:
  if not api_key:
    return None

  request = urllib.request.Request(
    usage_url,
    headers={
      "Accept": "application/json",
      "Authorization": f"Bearer {api_key}",
      "User-Agent": "blarchy-ai-usage/1.0",
    },
  )
  try:
    with urllib.request.urlopen(request, timeout=5) as response:
      payload = json.load(response)
  except (OSError, ValueError, urllib.error.URLError):
    return None

  usage = payload.get("usage") if isinstance(payload, dict) else None
  return usage if isinstance(usage, dict) else None


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
    # Completed Go responses can have a zero local cost, so token data is also
    # sufficient to distinguish them from an empty streaming row.
    finish = data.get("finish")
    if cost <= 0 and (
      input_tokens + output_tokens + cache_read + cache_write <= 0
      or not isinstance(finish, str)
      or finish == ""
    ):
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


def normalized_percent(value: Any) -> float:
  try:
    percent = float(value)
  except (TypeError, ValueError):
    return -1.0
  if not math.isfinite(percent):
    return -1.0
  return max(0.0, min(1.0, percent / 100))


def remote_limit(window: dict[str, Any] | None, label: str) -> dict[str, Any]:
  if not isinstance(window, dict):
    return {"label": label, "percent": -1, "resetAt": ""}

  percent = normalized_percent(window.get("percent"))
  reset_at = window.get("resetsAt")
  return {
    "label": label,
    "percent": percent,
    "resetAt": str(reset_at) if reset_at else "",
  }


def scan(database_path: Path, auth_path: Path, usage_url: str = USAGE_URL) -> dict[str, Any]:
  messages = read_messages(database_path)
  api_key = read_go_api_key(auth_path)
  authenticated = bool(api_key)
  remote_usage = fetch_remote_usage(api_key, usage_url)
  remote_available = remote_usage is not None
  ready = authenticated or bool(messages)
  today = dt.datetime.now().strftime("%Y-%m-%d")

  today_prompts = 0
  today_total_tokens = 0

  for message in messages:
    day = local_date(message["timestamp"])
    total_tokens = (
      message["inputTokens"]
      + message["outputTokens"]
      + message["cacheReadInputTokens"]
      + message["cacheCreationInputTokens"]
    )
    if day == today:
      today_prompts += 1
      today_total_tokens += total_tokens

  limits = [
    remote_limit(
      remote_usage.get(window_name) if remote_available else None,
      label,
    )
    for label, window_name in WINDOWS
  ]

  if remote_available:
    usage_note = "Live limits from OpenCode Go"
    usage_status_text = ""
    auth_help_text = ""
  elif authenticated:
    usage_note = "Live limits unavailable; token history is local"
    usage_status_text = "OpenCode Go live limits unavailable"
    auth_help_text = "Could not fetch live limits. Token history is local."
  else:
    usage_note = ""
    usage_status_text = ""
    auth_help_text = "Connect OpenCode Go to restore usage data."

  return {
    "schemaVersion": 1,
    "ready": ready,
    "hasLocalStats": database_path.is_file(),
    "authenticated": authenticated,
    "providerName": "OpenCode Go",
    "tierLabel": "Go" if ready else "",
    "usageNote": usage_note,
    "usageStatusText": usage_status_text,
    "authHelpText": auth_help_text,
    "todayPrompts": today_prompts,
    "todayTotalTokens": today_total_tokens,
    "rateLimitPercent": limits[0]["percent"],
    "rateLimitLabel": limits[0]["label"],
    "rateLimitResetAt": limits[0]["resetAt"],
    "secondaryRateLimitPercent": limits[1]["percent"],
    "secondaryRateLimitLabel": limits[1]["label"],
    "secondaryRateLimitResetAt": limits[1]["resetAt"],
    "tertiaryRateLimitPercent": limits[2]["percent"],
    "tertiaryRateLimitLabel": limits[2]["label"],
    "tertiaryRateLimitResetAt": limits[2]["resetAt"],
  }


def main() -> int:
  parser = argparse.ArgumentParser()
  parser.add_argument("database_path", nargs="?", default="~/.local/share/opencode/opencode.db")
  parser.add_argument("auth_path", nargs="?", default="~/.local/share/opencode/auth.json")
  parser.add_argument("usage_url", nargs="?", default=USAGE_URL)
  args = parser.parse_args()
  print(json.dumps(scan(expand_path(args.database_path), expand_path(args.auth_path), args.usage_url), separators=(",", ":")))
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
