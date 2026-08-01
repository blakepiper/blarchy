import QtQuick
import qs.Commons
import qs.Ui

BarIndicator {
  id: root

  readonly property var notificationService: bar?.shell?.firstPartyServiceFor("omarchy.notifications")
  readonly property bool dnd: notificationService ? notificationService.doNotDisturb : false

  active: dnd
  activeText: "󰂛"
  inactiveText: "󰂛"
  activeTooltipText: "Notification history · right-click to allow notifications"
  inactiveTooltipText: "Notification history · right-click to silence notifications"

  onPressed: function(button) {
    if (button === Qt.RightButton && root.notificationService) {
      root.notificationService.setDoNotDisturb(!root.notificationService.doNotDisturb)
    } else if (root.bar) {
      root.bar.run("omarchy-shell notifications showHistory")
    }
  }
}
