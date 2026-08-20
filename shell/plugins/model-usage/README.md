# Model usage

One bar icon and one panel for every AI coding subscription on the machine.
`Panel.qml` owns the bar button and the popup; `Main.qml` owns provider
fan-out and the optional cross-device aggregation; `providers/` holds one
adapter per subscription.

## Panel

The popup is one compact table with every enabled provider visible at once.
Each provider has session, weekly, and monthly columns showing used / remaining
allowance and reset time, plus today's tokens and prompt count. A missing limit
is shown as an em dash, so providers with different subscription windows still
line up without tabs or provider switching.

The long-running shell refreshes every provider in the background and keeps
the latest values in memory. Opening the popup only reads that cached snapshot;
it does not wait for Codex RPC, local transcript scans, or provider endpoints.
The default refresh interval is five minutes, matching the Blix widget. Right
click, `r`, or Enter forces a refresh.

Every configured provider keeps a row even when it has no signed-in data, which
makes auth or endpoint failures visible instead of silently removing a provider.
Set a provider's `enabled` setting to `false` when it should not be shown. Drop
the complete widget with `omarchy plugin disable omarchy.model-usage`.

## Providers

| Provider | Limits | Local stats |
|---|---|---|
| `claude` | Anthropic's OAuth usage endpoint (5-hour session + 7-day weekly) | `~/.claude/projects` scanned by `scripts/claude_usage_scanner.py`, plus `stats-cache.json` and `history.jsonl` |
| `codex` | `scripts/codex_usage_scanner.py` reading the Codex CLI state | the same scanner |
| `opencode-go` | OpenCode Go's live 5-hour, weekly, and monthly usage limits | OpenCode's usage endpoint for limits; `~/.local/share/opencode/opencode.db` for token history |

The Go tab reads the live usage endpoint with the existing OpenCode Go API key,
so its limit percentages and reset times match the OpenCode web console. The
local database is still used for token and model history. If the usage service
is unavailable, the panel does not substitute local cost estimates for live
limits.

Claude limits need a signed-in CLI; without credentials the panel says so and
falls back to local stats only.

## Interactions

- Bar icon: hover = the remaining-usage summary; left = table; right = refresh.
- Panel: `r` or Enter refreshes, Tab moves to the neighboring bar panel, and
  Esc closes.
- IPC: `omarchy-shell omarchy.model-usage <open|close|toggle|refresh>`.

## Settings

Settings live in the widget's entry in `~/.config/omarchy/shell.json`. The
top-level keys can be set with
`omarchy bar set omarchy.model-usage <key> <value>`:

| Key | Default | What it does |
|---|---|---|
| `refreshIntervalSec` | `300` | How often the cached provider snapshot refreshes |
| `syncMode` | `"Off"` | `"On"` writes this machine's snapshot and merges the others |
| `syncDir` | `""` | A folder synced by Syncthing, Dropbox, rsync, … |
| `syncFileName` | `<hostname>.json` | This machine's snapshot file |
| `syncDeviceId` | hostname | Stable device name inside the snapshot |

Numbers need `--json`, or they land in `shell.json` as strings:

```bash
omarchy bar set omarchy.model-usage refreshIntervalSec 300 --json
omarchy bar set omarchy.model-usage syncDir '~/Sync/model-usage'
```

Per-provider settings are nested, and `set` writes its key literally rather
than walking a dotted path — so pass the whole `providers` object as JSON (or
edit `shell.json` directly):

```bash
omarchy bar set omarchy.model-usage providers '{
  "claude": {
    "enabled": true,
    "statsPath": "~/.claude/stats-cache.json",
    "credentialsPath": "~/.claude/.credentials.json",
    "projectsPath": "~/.claude/projects"
  },
  "codex": { "enabled": false }
}' --json
```

`enabled` defaults to `true` for every provider; set it to `false` to hide a
subscription that is installed. The paths above are the defaults.

With `syncMode` on, every `*.json` snapshot in `syncDir` is merged, so today,
the last 7 days, and the all-time totals cover every machine you code on —
active days are unioned by date rather than summed. Rate limits stay
per-account and are never merged.

One caveat on "all-time": the Codex scanner only reads native session files
touched in the last 30 days, so Codex totals and its day count cover that
window. Claude's cover every transcript still on disk.
