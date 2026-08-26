import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property var signals: []
  property var current: null

  readonly property string numberText: root.current ? Model.formatNumber(root.current.id) : ""
  readonly property string titleText: root.current && root.current.title ? String(root.current.title) : ""
  readonly property string bodyText: root.current && root.current.body ? String(root.current.body) : ""

  function loadSignals() {
    var xhr = new XMLHttpRequest()
    xhr.open("GET", Qt.resolvedUrl("signals.json"), false)
    xhr.send()
    if (xhr.status !== 200 && xhr.status !== 0) return
    try {
      root.signals = Model.loadSignals(JSON.parse(xhr.responseText))
    } catch (e) {
      root.signals = []
    }
  }

  function pickNew() {
    var exceptId = root.current ? root.current.id : undefined
    var next = Model.pickRandom(root.signals, exceptId)
    if (next) root.current = next
  }

  function showFromPayload(payloadJson) {
    var payload = null
    if (payloadJson) {
      try { payload = JSON.parse(payloadJson) } catch (e) { payload = null }
    }
    if (payload && payload.title && payload.body) root.current = payload
    else root.pickNew()
    root.opened = true
  }

  function open(payloadJson) {
    if (!root.signals.length) root.loadSignals()
    root.showFromPayload(payloadJson)
  }

  function close() {
    root.opened = false
  }

  Component.onCompleted: root.loadSignals()

  PanelWindow {
    id: window
    visible: root.opened
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "higgsfield-signals"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
      anchors.fill: parent
      color: Color.background
    }

    MouseArea {
      id: keyCatcher
      anchors.fill: parent
      enabled: root.opened
      hoverEnabled: true
      focus: root.opened
      onClicked: root.close()
      Keys.onPressed: function(event) {
        root.close()
        event.accepted = true
      }

      Column {
        id: essay
        width: Math.min(Style.space(640), parent.width - Style.space(96))
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(16)

        Text {
          width: parent.width
          text: root.numberText
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.letterSpacing: 2
        }

        Text {
          width: parent.width
          text: root.titleText
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.displayLarge
          font.bold: true
          wrapMode: Text.WordWrap
        }

        Text {
          width: parent.width
          text: root.bodyText
          color: Color.foreground
          opacity: 0.88
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          wrapMode: Text.WordWrap
          lineHeight: 1.35
        }

        Text {
          width: parent.width
          text: "37signals"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          topPadding: Style.space(24)
        }
      }
    }
  }

  Timer {
    interval: 45000
    running: root.opened
    repeat: true
    onTriggered: root.pickNew()
  }

  onOpenedChanged: {
    if (root.opened) keyCatcher.forceActiveFocus()
  }
}
