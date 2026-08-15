import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  visible: false

  property string providerId: "opencode-go"
  property string providerName: "OpenCode Go"
  property string providerIcon: "opencode"
  property bool enabled: false
  property bool ready: false
  property bool refreshing: false
  property double lastRefreshedAtMs: 0

  property real rateLimitPercent: -1
  property string rateLimitLabel: ""
  property string rateLimitResetAt: ""
  property real rateLimitSpent: 0
  property real rateLimitLimit: 0
  property real secondaryRateLimitPercent: -1
  property string secondaryRateLimitLabel: ""
  property string secondaryRateLimitResetAt: ""
  property real secondaryRateLimitSpent: 0
  property real secondaryRateLimitLimit: 0
  property real tertiaryRateLimitPercent: -1
  property string tertiaryRateLimitLabel: ""
  property string tertiaryRateLimitResetAt: ""
  property real tertiaryRateLimitSpent: 0
  property real tertiaryRateLimitLimit: 0

  property int todayPrompts: 0
  property int todaySessions: 0
  property real todayTotalTokens: 0
  property var todayTokensByModel: ({})

  property var recentDays: []
  property int totalPrompts: 0
  property int totalSessions: 0
  property int activeDays: 0
  property var activeDates: []
  property var modelUsage: ({})

  property string tierLabel: ""
  property string usageStatusText: ""
  property string usageNote: ""
  property string authHelpText: "Connect OpenCode Go to restore usage data."
  property bool hasLocalStats: false
  property var providerSettings: ({})

  readonly property string scannerPath: String(Qt.resolvedUrl("../scripts/opencode_go_usage_scanner.py")).replace("file://", "")

  Process {
    id: usageScanner
    command: ["python3", root.scannerPath, root.databasePath, root.authPath]
    running: false

    stdout: StdioCollector {
      onStreamFinished: root.parseScannerOutput(text)
    }

    onExited: root.finishRefresh()

    stderr: StdioCollector {
      onStreamFinished: if (text.trim() !== "") console.warn("model-usage/opencode-go", text.trim())
    }
  }

  Timer {
    interval: 5 * 60 * 1000
    running: root.enabled
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  onEnabledChanged: if (enabled) refresh()

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string databasePath: String(root.providerSettings?.databasePath ?? "~/.local/share/opencode/opencode.db")
  readonly property string authPath: String(root.providerSettings?.authPath ?? "~/.local/share/opencode/auth.json")

  function finishRefresh() {
    root.refreshing = false
    root.lastRefreshedAtMs = Date.now()
  }

  function refresh() {
    if (usageScanner.running)
      return
    root.refreshing = true
    usageScanner.running = true
  }

  function parseScannerOutput(output) {
    const raw = String(output || "").trim()
    if (raw === "")
      return

    try {
      const data = JSON.parse(raw.split("\n").pop())
      root.ready = !!data.ready
      root.hasLocalStats = data.hasLocalStats === true

      root.todayPrompts = data.todayPrompts || 0
      root.todaySessions = data.todaySessions || 0
      root.todayTotalTokens = data.todayTotalTokens || 0
      root.todayTokensByModel = data.todayTokensByModel || ({})
      root.recentDays = data.recentDays || []
      root.totalPrompts = data.totalPrompts || 0
      root.totalSessions = data.totalSessions || 0
      root.activeDays = data.activeDays || 0
      root.activeDates = data.activeDates || []
      root.modelUsage = data.modelUsage || ({})

      root.rateLimitPercent = data.rateLimitPercent ?? -1
      root.rateLimitLabel = data.rateLimitLabel || ""
      root.rateLimitResetAt = data.rateLimitResetAt || ""
      root.rateLimitSpent = data.rateLimitSpent || 0
      root.rateLimitLimit = data.rateLimitLimit || 0
      root.secondaryRateLimitPercent = data.secondaryRateLimitPercent ?? -1
      root.secondaryRateLimitLabel = data.secondaryRateLimitLabel || ""
      root.secondaryRateLimitResetAt = data.secondaryRateLimitResetAt || ""
      root.secondaryRateLimitSpent = data.secondaryRateLimitSpent || 0
      root.secondaryRateLimitLimit = data.secondaryRateLimitLimit || 0
      root.tertiaryRateLimitPercent = data.tertiaryRateLimitPercent ?? -1
      root.tertiaryRateLimitLabel = data.tertiaryRateLimitLabel || ""
      root.tertiaryRateLimitResetAt = data.tertiaryRateLimitResetAt || ""
      root.tertiaryRateLimitSpent = data.tertiaryRateLimitSpent || 0
      root.tertiaryRateLimitLimit = data.tertiaryRateLimitLimit || 0

      root.tierLabel = data.tierLabel || ""
      root.usageStatusText = data.usageStatusText || ""
      root.usageNote = data.usageNote || ""
      root.authHelpText = data.authHelpText || "Connect OpenCode Go to restore usage data."
    } catch (e) {
      console.error("model-usage/opencode-go", "Failed to parse scanner output:", e, raw)
      root.usageStatusText = "OpenCode Go scan failed"
      root.authHelpText = String(e)
      root.ready = true
    }
  }

  function formatResetTime(isoTimestamp) {
    if (!isoTimestamp)
      return ""
    const reset = new Date(isoTimestamp)
    const diffMs = reset.getTime() - Date.now()
    if (diffMs <= 0)
      return "now"
    const hours = Math.floor(diffMs / 3600000)
    const mins = Math.floor((diffMs % 3600000) / 60000)
    if (hours > 24)
      return Math.floor(hours / 24) + "d " + (hours % 24) + "h"
    if (hours > 0)
      return hours + "h " + mins + "m"
    return mins + "m"
  }
}
