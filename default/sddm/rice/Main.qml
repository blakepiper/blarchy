import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
  id: root
  width: 640
  height: 480
  color: "#1a1b26"

  function userName(index) {
    return (userModel.data(userModel.index(index, 0), Qt.UserRole + 1) || "").toString()
  }

  property string currentUser: {
    if (userModel.lastUser && userName(userModel.lastIndex) === userModel.lastUser)
      return userModel.lastUser
    if (userModel.rowCount() > 0)
      return userName(0)
    return ""
  }
  property bool loginFailed: false
  function sessionFile(index) {
    return (sessionModel.data(sessionModel.index(index, 0), Qt.UserRole + 2) || "").toString()
  }

  function sessionExec(index) {
    return (sessionModel.data(sessionModel.index(index, 0), Qt.UserRole + 5) || "").toString()
  }

  function preferredSessionIndex() {
    var lastIndex = sessionModel.lastIndex
    if (sessionFile(lastIndex) === "rice.desktop")
      return lastIndex

    for (var i = 0; i < sessionModel.rowCount(); i++) {
      if (sessionFile(i) === "rice.desktop")
        return i
    }

    for (var j = 0; j < sessionModel.rowCount(); j++) {
      if (sessionExec(j).indexOf("uwsm start -g -1 -e -D Hyprland") === 0)
        return j
    }
    return lastIndex
  }

  property int sessionIndex: preferredSessionIndex()

  Connections {
    target: sddm
    function onLoginFailed() {
      root.loginFailed = true
      password.text = ""
      password.focus = true
    }
    function onLoginSucceeded() {
      root.loginFailed = false
    }
  }

  Column {
    anchors.centerIn: parent
    spacing: 40

    Column {
      spacing: 4
      anchors.horizontalCenter: parent.horizontalCenter

      Text {
        text: "PERSONAL ARCH"
        color: "#c0caf5"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 52
        font.bold: true
        anchors.horizontalCenter: parent.horizontalCenter
      }

      Text {
        text: "HYPRLAND + XFCE"
        color: "#7aa2f7"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 16
        anchors.horizontalCenter: parent.horizontalCenter
      }
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 15

      Image {
        source: root.loginFailed ? "lock-failed.png" : "lock.png"
        width: 34
        height: 38
        fillMode: Image.PreserveAspectFit
        anchors.verticalCenter: parent.verticalCenter
      }

      Item {
        width: entry.width
        height: entry.height

        Image {
          id: entry
          source: root.loginFailed ? "entry-failed.png" : "entry.png"
          anchors.centerIn: parent
        }

        Row {
          anchors.left: parent.left
          anchors.leftMargin: 20
          anchors.verticalCenter: parent.verticalCenter
          spacing: 5

          Repeater {
            model: Math.min(password.text.length, 21)

            Image {
              source: "bullet.png"
              width: 7
              height: 7
            }
          }
        }

        TextInput {
          id: password
          anchors.fill: parent
          anchors.leftMargin: 20
          anchors.rightMargin: 20
          verticalAlignment: TextInput.AlignVCenter
          echoMode: TextInput.Password
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 24
          font.letterSpacing: 5
          passwordCharacter: "\u2022"
          color: "transparent"
          selectionColor: "transparent"
          selectedTextColor: "transparent"
          cursorDelegate: Item {}
          focus: true

          onTextChanged: root.loginFailed = false

          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              if (root.currentUser !== "")
                sddm.login(root.currentUser, password.text, root.sessionIndex)
              event.accepted = true
            }
          }
        }
      }
    }

  }

  Component.onCompleted: password.forceActiveFocus()
}
