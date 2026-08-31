import QtQuick
import qs.Ui

// Bar chip that opens the generate panel. IPC stays on Service.qml —
// a second IpcHandler on higgsfield.signals would go silent.
BarWidget {
  id: root
  moduleName: "higgsfield.signals"

  readonly property var svc: root.bar && root.bar.shell && root.bar.shell.serviceFor
    ? root.bar.shell.serviceFor("higgsfield.signals")
    : null

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false
  readonly property bool generating: root.svc ? !!root.svc.generating : false

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey)
      panelLoader.item.openFromHotkey()
    else if (panelLoader.item)
      panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    z: 1
    bar: root.bar
    text: {
      if (!root.generating) return "HF"
      var p = root.svc ? Number(root.svc.generatePercent || 0) : 0
      return p > 0 ? (p + "%") : "…"
    }
    tooltipText: root.generating
      ? (root.svc && root.svc.generateStatus ? String(root.svc.generateStatus) : "Generating Tamagotchi…")
      : "Generate my avatar"

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }

  Rectangle {
    id: chipTrack
    visible: root.generating
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 3
    z: 0
    color: Qt.rgba(1, 1, 1, 0.14)
    clip: true

    Rectangle {
      id: chipFill
      height: parent.height
      width: {
        var p = root.svc ? Number(root.svc.generatePercent || 0) : 0
        if (p <= 0) return Math.max(8, parent.width * 0.3)
        return parent.width * Math.min(1, p / 100)
      }
      color: root.bar && "foreground" in root.bar ? root.bar.foreground : "#fff"
      x: 0
      Behavior on width { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

      SequentialAnimation on x {
        running: root.generating && chipTrack.width > 8 && (!root.svc || Number(root.svc.generatePercent || 0) <= 0)
        loops: Animation.Infinite
        NumberAnimation {
          from: -chipFill.width
          to: chipTrack.width
          duration: 1100
          easing.type: Easing.InOutSine
        }
        onStopped: chipFill.x = 0
      }
    }
  }
}
