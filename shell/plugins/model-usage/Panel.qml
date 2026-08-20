import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "omarchy.model-usage"
  ipcTarget: "omarchy.model-usage"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var providers: usage.enabledProviders
  property double nowMs: Date.now()

  readonly property int providerColumnWidth: Style.space(132)
  readonly property int limitColumnWidth: Style.space(112)
  readonly property int todayColumnWidth: Style.space(118)
  readonly property int tableSpacing: Style.space(10)
  readonly property int tableWidth: providerColumnWidth + limitColumnWidth * 3
    + todayColumnWidth + tableSpacing * 4

  function clamp(value, lo, hi) {
    return Math.max(lo, Math.min(hi, value))
  }

  function validPercent(value) {
    var percent = Number(value)
    return isFinite(percent) && percent >= 0 ? clamp(percent, 0, 1) : -1
  }

  function windowIsLong(text) {
    return text.indexOf("week") >= 0 || text.indexOf("7-day") >= 0 || text.indexOf("seven") >= 0
      || text.indexOf("month") >= 0 || text.indexOf("30-day") >= 0
  }

  function windowSpanMs(label) {
    var text = String(label || "").toLowerCase()
    if (text.indexOf("month") >= 0 || text.indexOf("30-day") >= 0) return 30 * 24 * 3600 * 1000
    if (windowIsLong(text)) return 7 * 24 * 3600 * 1000
    var hours = text.match(/(\d+)\s*-?\s*h(?:our)?\b/)
    if (hours) return Number(hours[1]) * 3600 * 1000
    var minutes = text.match(/(\d+)\s*-?\s*m(?:in(?:ute)?s?)?\b/)
    if (minutes) return Number(minutes[1]) * 60 * 1000
    return 0
  }

  function windowTitle(label) {
    var text = String(label || "").toLowerCase()
    if (text.indexOf("month") >= 0 || text.indexOf("30-day") >= 0) return "Monthly"
    if (windowIsLong(text)) return "Weekly"
    if (text.indexOf("session") >= 0 || windowSpanMs(label) > 0) return "Session"
    var plain = String(label || "").replace(/\s*\(.*\)\s*/, "").trim()
    return plain === "" ? "Limit" : plain
  }

  function limitWindow(label, percent, resetAt) {
    return {
      title: windowTitle(label),
      percent: validPercent(percent),
      resetAt: String(resetAt || "")
    }
  }

  function limitWindows(provider) {
    if (!provider) return []
    var result = []
    if (validPercent(provider.rateLimitPercent) >= 0)
      result.push(limitWindow(provider.rateLimitLabel, provider.rateLimitPercent, provider.rateLimitResetAt))
    if (validPercent(provider.secondaryRateLimitPercent) >= 0)
      result.push(limitWindow(provider.secondaryRateLimitLabel, provider.secondaryRateLimitPercent, provider.secondaryRateLimitResetAt))
    if (validPercent(provider.tertiaryRateLimitPercent) >= 0)
      result.push(limitWindow(provider.tertiaryRateLimitLabel, provider.tertiaryRateLimitPercent, provider.tertiaryRateLimitResetAt))
    return result
  }

  function providerLimit(provider, title) {
    var windows = limitWindows(provider)
    for (var i = 0; i < windows.length; i++) {
      if (windows[i].title === title) return windows[i]
    }
    return null
  }

  function resetMsFor(window) {
    if (!window || window.resetAt === "") return -1
    var resetMs = new Date(window.resetAt).getTime()
    return isFinite(resetMs) ? resetMs - root.nowMs : -1
  }

  function formatDuration(ms) {
    if (!(ms > 0)) return "now"
    var minutes = Math.floor(ms / 60000)
    var hours = Math.floor(minutes / 60)
    var days = Math.floor(hours / 24)
    if (days > 0) return days + "d " + (hours % 24) + "h"
    if (hours > 0) return hours + "h " + (minutes % 60) + "m"
    return Math.max(1, minutes) + "m"
  }

  function limitUsageText(window) {
    if (!window || window.percent < 0) return "\u2014"
    var used = Math.round(window.percent * 100)
    return used + "% / " + (100 - used) + "%"
  }

  function limitResetText(window) {
    var remaining = resetMsFor(window)
    return remaining > 0 ? "resets " + formatDuration(remaining) : ""
  }

  function providerStatus(provider) {
    if (!provider) return ""
    var status = String(provider.usageStatusText || "").trim()
    if (status !== "") return status
    var tier = String(provider.tierLabel || "").trim()
    return tier !== "" ? tier : "No signed-in data"
  }

  function providerTooltip(provider) {
    if (!provider) return ""
    var lines = []
    var tier = String(provider.tierLabel || "")
    lines.push(provider.providerName + (tier !== "" ? " \u00b7 " + tier : ""))
    var status = String(provider.usageStatusText || "").trim()
    if (status !== "") lines.push("  " + status)

    var windows = limitWindows(provider)
    for (var i = 0; i < windows.length; i++) {
      var window = windows[i]
      var reset = limitResetText(window)
      lines.push("  " + window.title + ": " + Math.round(window.percent * 100) + "% used \u00b7 "
        + Math.round((1 - window.percent) * 100) + "% left"
        + (reset !== "" ? " \u00b7 " + reset : ""))
    }

    if (windows.length === 0 && status === "") lines.push("  No signed-in usage data")
    lines.push("  Today: " + usage.formatTokenCount(Number(provider.todayTotalTokens || 0))
      + " tokens \u00b7 " + Number(provider.todayPrompts || 0) + " prompts")
    return lines.join("\n")
  }

  readonly property var usagePercents: {
    var values = []
    for (var i = 0; i < providers.length; i++) {
      var windows = limitWindows(providers[i])
      for (var j = 0; j < windows.length; j++) values.push(windows[j].percent)
    }
    return values
  }

  readonly property real highestUsage: usagePercents.length > 0
    ? Math.max.apply(Math, usagePercents)
    : -1
  readonly property bool alarming: highestUsage >= 0.9
  readonly property string barSummary: highestUsage >= 0
    ? "AI " + Math.round((1 - highestUsage) * 100) + "% left"
    : "AI usage"
  readonly property string barTooltip: {
    var sections = [barSummary]
    for (var i = 0; i < providers.length; i++) sections.push(providerTooltip(providers[i]))
    sections.push("\nLeft click: details \u00b7 Right click: refresh")
    return sections.join("\n\n")
  }

  function refreshNow() {
    usage.refreshAll(true)
  }

  function updatedText() {
    if (usage.refreshing) return "Refreshing provider cache\u2026"
    if (!(usage.lastRefreshedAtMs > 0)) return "Waiting for first refresh"
    var age = Math.max(0, root.nowMs - usage.lastRefreshedAtMs)
    if (age < 60000) return "Updated just now"
    return "Updated " + formatDuration(age) + " ago"
  }

  function refreshIntervalText() {
    var seconds = usage.refreshIntervalSec
    if (seconds % 60 === 0) return (seconds / 60) + " min"
    return seconds + " sec"
  }

  function colorChannelLuminance(value) {
    var channel = Number(value)
    if (!isFinite(channel)) return 0
    return channel <= 0.03928 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
  }

  function colorLuminance(color) {
    return 0.2126 * colorChannelLuminance(color.r)
      + 0.7152 * colorChannelLuminance(color.g)
      + 0.0722 * colorChannelLuminance(color.b)
  }

  // Kept as part of the widget's QML API even though the compact table uses
  // provider names instead of logos.
  function iconSourceForProvider(provider, surfaceColor) {
    if (!provider) return ""
    if (provider.providerId === "claude") return Qt.resolvedUrl("assets/claude.svg")
    if (provider.providerId === "codex")
      return colorLuminance(surfaceColor || Color.background) >= 0.5
        ? Qt.resolvedUrl("assets/codex-light.svg")
        : Qt.resolvedUrl("assets/codex.svg")
    if (provider.providerId === "opencode-go")
      return colorLuminance(surfaceColor || Color.background) >= 0.5
        ? Qt.resolvedUrl("assets/opencode-light.svg")
        : Qt.resolvedUrl("assets/opencode.svg")
    return ""
  }

  visible: providers.length > 0
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    nowMs = Date.now()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Main {
    id: usage
    settings: root.settings
  }

  Timer {
    interval: 30000
    running: root.opened
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refreshNow(); return "ok" }
    function next(): string { return "all providers shown" }
    function state(): string { return root.opened ? "open" : "closed" }
    function debug(): string {
      return JSON.stringify({
        opened: root.opened,
        panelVisible: panel.visible,
        panelWidth: panel.width,
        panelHeight: panel.height,
        contentWidth: panel.contentWidth,
        contentHeight: panel.contentHeight,
        cardX: panel.cardOrigin.x,
        cardY: panel.cardOrigin.y,
        screenWidth: panel.screenW,
        screenHeight: panel.screenH,
        anchorX: panel.anchorScreenPos.x,
        anchorY: panel.anchorScreenPos.y,
        providers: root.providers.length,
        buttonWidth: button.width,
        buttonHeight: button.height
      })
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󱢣"
    active: root.alarming
    tooltipText: root.barTooltip
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.refreshNow()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(root.tableWidth)
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: root.refreshNow()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) { if (text === "r" || text === "R") root.refreshNow() }

      Column {
        id: contentColumn
        width: parent.width
        spacing: Style.space(12)

        Item {
          width: parent.width
          implicitHeight: Math.max(titleText.implicitHeight + subtitleText.implicitHeight + Style.space(2), refreshText.implicitHeight)

          Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              id: titleText
              text: "AI Usage"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              id: subtitleText
              text: "All providers \u00b7 cached every " + root.refreshIntervalText()
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Text {
            id: refreshText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.updatedText()
            color: usage.refreshing ? root.foreground : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        PanelSeparator {
          width: parent.width
          foreground: root.foreground
        }

        Row {
          width: parent.width
          spacing: root.tableSpacing

          TableHeader { width: root.providerColumnWidth; title: "PROVIDER" }
          TableHeader { width: root.limitColumnWidth; title: "SESSION"; detail: "USED / LEFT" }
          TableHeader { width: root.limitColumnWidth; title: "WEEKLY"; detail: "USED / LEFT" }
          TableHeader { width: root.limitColumnWidth; title: "MONTHLY"; detail: "USED / LEFT" }
          TableHeader { width: root.todayColumnWidth; title: "TODAY" }
        }

        Repeater {
          model: root.providers

          Column {
            required property var modelData
            required property int index

            width: contentColumn.width
            spacing: Style.space(10)

            Rectangle {
              visible: index > 0
              width: parent.width
              height: Style.spacing.hairline
              color: root.foreground
              opacity: 0.12
            }

            Row {
              width: parent.width
              spacing: root.tableSpacing

              ProviderCell {
                width: root.providerColumnWidth
                provider: modelData
              }

              LimitCell {
                width: root.limitColumnWidth
                window: root.providerLimit(modelData, "Session")
              }

              LimitCell {
                width: root.limitColumnWidth
                window: root.providerLimit(modelData, "Weekly")
              }

              LimitCell {
                width: root.limitColumnWidth
                window: root.providerLimit(modelData, "Monthly")
              }

              TodayCell {
                width: root.todayColumnWidth
                provider: modelData
              }
            }
          }
        }

        Text {
          visible: usage.syncStatusText !== ""
          width: parent.width
          text: usage.syncStatusText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }
      }
    }
  }

  component TableHeader: Column {
    property string title: ""
    property string detail: ""

    spacing: Style.space(1)

    Text {
      width: parent.width
      text: parent.title
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      elide: Text.ElideRight
    }

    Text {
      visible: parent.detail !== ""
      width: parent.width
      text: parent.detail
      color: root.dim
      opacity: 0.7
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  component ProviderCell: Column {
    property var provider: null

    spacing: Style.space(2)

    Text {
      width: parent.width
      text: parent.provider ? parent.provider.providerName : ""
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      text: root.providerStatus(parent.provider)
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  component LimitCell: Column {
    property var window: null

    spacing: Style.space(2)

    Text {
      width: parent.width
      text: root.limitUsageText(parent.window)
      color: parent.window && parent.window.percent >= 0.9 ? root.urgent : root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      text: root.limitResetText(parent.window)
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  component TodayCell: Column {
    property var provider: null

    spacing: Style.space(2)

    Text {
      width: parent.width
      text: usage.formatTokenCount(Number(parent.provider ? parent.provider.todayTotalTokens || 0 : 0)) + " tokens"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      text: Number(parent.provider ? parent.provider.todayPrompts || 0 : 0) + " prompts"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }
}
