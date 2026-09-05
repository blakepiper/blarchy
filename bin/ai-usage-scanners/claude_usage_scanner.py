#!/usr/bin/env python3
"""Count today's Claude assistant responses and tokens from local JSONL logs."""

import argparse
import datetime as dt
import json
from pathlib import Path


def scan(projects_path: Path) -> dict:
  today = dt.datetime.now().astimezone().date()
  messages = {}
  for path in projects_path.rglob("*.jsonl"):
    try:
      with path.open(encoding="utf-8", errors="replace") as handle:
        for line_number, line in enumerate(handle):
          if '"usage"' not in line:
            continue
          try:
            entry = json.loads(line)
            message = entry.get("message") or {}
            if entry.get("type") != "assistant" and message.get("role") != "assistant":
              continue
            timestamp = entry.get("timestamp") or message.get("timestamp")
            if dt.datetime.fromisoformat(timestamp.replace("Z", "+00:00")).astimezone().date() != today:
              continue
            usage = message.get("usage") or entry.get("usage") or {}
            total = sum(max(0, int(usage.get(key) or 0)) for key in (
              "input_tokens", "output_tokens", "cache_read_input_tokens", "cache_creation_input_tokens",
            ))
            key = message.get("id") or entry.get("uuid") or f"{path}:{line_number}"
            # Streaming snapshots and copied session histories may repeat IDs.
            messages[key] = max(messages.get(key, 0), total)
          except (ValueError, TypeError, AttributeError):
            continue
    except OSError:
      continue
  return {
    "todayPrompts": sum(total > 0 for total in messages.values()),
    "todayTotalTokens": sum(messages.values()),
  }


if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument("projects_path", nargs="?", default="~/.claude/projects")
  args = parser.parse_args()
  print(json.dumps(scan(Path(args.projects_path).expanduser())))
