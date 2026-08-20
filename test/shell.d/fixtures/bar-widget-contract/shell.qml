import QtQuick
import Quickshell
import qs.Commons

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("OMARCHY_QML_TEST_RESULT")
  readonly property string rootPath: Quickshell.env("OMARCHY_PATH")
  property var failures: []
  property var createdIds: []
  property var createdObjects: []

  function fail(message) {
    failures.push(String(message))
  }

  function assertTrue(condition, message) {
    if (!condition) fail(message)
  }

  function assertEqual(actual, expected, message) {
    if (actual !== expected) fail(message + " expected=" + expected + " actual=" + actual)
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function writeResult() {
    var payload = JSON.stringify({
      ok: failures.length === 0,
      failures: failures,
      created: createdIds
    })

    if (resultPath) {
      Quickshell.execDetached(["bash", "-lc", "printf '%s' " + shellQuote(payload) + " > " + shellQuote(resultPath)])
    }
  }

  function widgets() {
    try {
      return JSON.parse(Qt.atob(Quickshell.env("OMARCHY_QML_BAR_WIDGETS") || "W10="))
    } catch (error) {
      fail("bar widget list failed to parse: " + error)
      return []
    }
  }

  function safeCall(item, method, entry) {
    if (!item || typeof item[method] !== "function") return
    try {
      item[method]()
    } catch (error) {
      fail(entry.id + " " + method + "() threw: " + error)
    }
  }

  function finiteDimension(value) {
    var n = Number(value)
    return isFinite(n) && n >= 0
  }

  function loadWidget(entry) {
    var component = Qt.createComponent(entry.url, Component.PreferSynchronous)
    if (component.status !== Component.Ready) {
      fail(entry.id + " failed to load: " + component.errorString())
      return
    }

    var item = component.createObject(host, {
      moduleName: entry.id,
      settings: {}
    })
    if (!item) {
      fail(entry.id + " failed to instantiate without bar: " + component.errorString())
      return
    }

    if ("bar" in item) {
      root.assertTrue(item.bar === null || item.bar === undefined, entry.id + " starts without injected bar")
      item.bar = fakeBar
      root.assertTrue(item.bar === fakeBar, entry.id + " accepts delayed bar injection")
    }
    if ("moduleName" in item) {
      item.moduleName = entry.id
      root.assertEqual(item.moduleName, entry.id, entry.id + " accepts moduleName injection")
    }
    if ("settings" in item) {
      item.settings = {}
      root.assertTrue(item.settings !== null && item.settings !== undefined, entry.id + " accepts settings injection")
    }
    if (typeof item.setting === "function") {
      root.assertEqual(item.setting("missing", "fallback"), "fallback", entry.id + " exposes setting fallback")
    }
    if (entry.id === "omarchy.model-usage" && typeof item.iconSourceForProvider === "function") {
      var darkIcon = String(item.iconSourceForProvider({ providerId: "codex" }, Qt.color("#1a1b26")))
      var lightIcon = String(item.iconSourceForProvider({ providerId: "codex" }, Qt.color("#ffffff")))
      root.assertTrue(darkIcon.indexOf("codex.svg") >= 0 && darkIcon.indexOf("codex-light.svg") < 0, entry.id + " uses the dark-theme Codex icon on dark surfaces")
      root.assertTrue(lightIcon.indexOf("codex-light.svg") >= 0, entry.id + " uses the light-theme Codex icon on light surfaces")
      var openCodeIcon = String(item.iconSourceForProvider({ providerId: "opencode-go" }, Qt.color("#1a1b26")))
      root.assertTrue(openCodeIcon.indexOf("opencode.svg") >= 0, entry.id + " exposes an OpenCode Go icon")
      var usageTooltip = item.providerTooltip({
        providerName: "Codex",
        tierLabel: "Pro",
        rateLimitPercent: 0.25,
        rateLimitLabel: "Session (5-hour)",
        rateLimitResetAt: "",
        todayTotalTokens: 1200,
        todayPrompts: 3
      })
      root.assertTrue(usageTooltip.indexOf("Codex · Pro") >= 0, entry.id + " labels AI usage by provider and plan")
      root.assertTrue(usageTooltip.indexOf("Session: 25% used · 75% left") >= 0, entry.id + " shows the remaining AI allowance")
      root.assertTrue(usageTooltip.indexOf("Today: 1.2K tokens · 3 prompts") >= 0, entry.id + " includes today's AI activity")
      var monthlyLimit = item.providerLimit({
        tertiaryRateLimitPercent: 0.4,
        tertiaryRateLimitLabel: "Monthly window",
        tertiaryRateLimitResetAt: ""
      }, "Monthly")
      root.assertTrue(monthlyLimit && monthlyLimit.percent === 0.4, entry.id + " maps provider windows into the shared table")
      root.assertEqual(item.limitUsageText(monthlyLimit), "40% / 60%", entry.id + " formats table cells as used and left")
      root.assertEqual(item.windowTitle("30-day window"), "Monthly", entry.id + " maps 30-day limits to the monthly column")
      root.assertEqual(item.providerStatus({
        tierLabel: "Pro",
        usageStatusText: "Limits unavailable"
      }), "Limits unavailable", entry.id + " keeps provider errors visible over stale plan labels")
    }

    safeCall(item, "refresh", entry)
    safeCall(item, "close", entry)

    createdObjects.push(item)
    createdIds.push(entry.id)
  }

  Item { id: host }

  QtObject {
    id: mockShell
    property var bar: fakeBar
    property var barConfig: ({ position: "top" })
    property var shellConfig: ({ version: 1, idle: {}, plugins: [], bar: { layout: { left: [], center: [], right: [] } } })
    function firstPartyServiceFor(id) { return null }
    function serviceFor(id) { return null }
    function summon(id, payloadJson) { return true }
    function hide(id) { return true }
    function toggle(id, payloadJson) { return true }
    function updateEntryInline(moduleName, settings) { return true }
  }

  QtObject {
    id: fakeBar
    property bool vertical: false
    property int barSize: 26
    property string omarchyPath: root.rootPath
    property string fontFamily: "monospace"
    property color foreground: "white"
    property color background: "black"
    property color urgent: "red"
    property var shell: mockShell
    function run(command) {}
    function showTooltip(target, text) {}
    function hideTooltip(target) {}
    function requestPopout(owner) {}
    function releasePopout(owner) {}
    function registerClickTarget(target) {}
    function unregisterClickTarget(target) {}
  }

  Timer {
    interval: 1
    running: true
    repeat: false
    onTriggered: {
      var entries = widgets()
      root.assertTrue(entries.length > 0, "bar widget list is not empty")
      for (var i = 0; i < entries.length; i++) root.loadWidget(entries[i])

      Qt.callLater(function() {
        for (var j = 0; j < root.createdObjects.length; j++) {
          var item = root.createdObjects[j]
          var id = root.createdIds[j]
          root.assertTrue(root.finiteDimension(item.implicitWidth), id + " has a finite implicitWidth")
          root.assertTrue(root.finiteDimension(item.implicitHeight), id + " has a finite implicitHeight")
        }

        fakeBar.vertical = true
        fakeBar.barSize = Style.bar.sizeVertical

        Qt.callLater(function() {
          for (var k = 0; k < root.createdObjects.length; k++) {
            var verticalItem = root.createdObjects[k]
            var verticalId = root.createdIds[k]
            if (verticalId === "omarchy.clock")
              root.assertEqual(verticalItem.implicitHeight, Style.bar.iconSlot * 3, verticalId + " uses one slot per line")
            else if (verticalId === "omarchy.weather" || verticalId === "omarchy.system-update")
              root.assertEqual(verticalItem.implicitHeight, Style.bar.statusSlot, verticalId + " uses one compact status slot")
            if (verticalItem && typeof verticalItem.destroy === "function") verticalItem.destroy()
          }
          root.assertTrue(root.createdIds.length === entries.length, "all bar widgets instantiate")
          root.writeResult()
        })
      })
    }
  }
}
