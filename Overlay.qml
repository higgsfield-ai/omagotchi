import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "Model.js" as Model

// keepLoaded panel. Same shape as omarchy.osd: IpcHandler + PanelWindow
// on one Item. A separate service looking up panelLoaders returned empty IPC.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property var signals: []
  property var current: null

  readonly property var idleConfig: shell && shell.shellConfig && shell.shellConfig.idle
    ? shell.shellConfig.idle
    : ({})
  readonly property int screensaverTimeoutSeconds: Model.screensaverSeconds(idleConfig, 150)
  readonly property string numberText: root.current ? Model.formatNumber(root.current.id) : ""
  readonly property string titleText: root.current && root.current.title ? String(root.current.title) : ""
  readonly property string bodyText: root.current && root.current.body ? String(root.current.body) : ""

  function copyList(raw) {
    var out = []
    if (!raw) return out
    var n = Number(raw.length)
    if (!isFinite(n) || n <= 0) return out
    for (var i = 0; i < n; i++) {
      var item = raw[i]
      if (item && item.title && item.body) out.push(item)
    }
    return out
  }

  function loadSignals() {
    try {
      var xhr = new XMLHttpRequest()
      xhr.open("GET", Qt.resolvedUrl("signals.json"), false)
      xhr.send()
      root.signals = root.copyList(JSON.parse(xhr.responseText))
    } catch (e) {
      root.signals = []
    }
  }

  function pickNew() {
    if (!root.signals || root.signals.length === 0) root.loadSignals()
    var count = root.signals ? root.signals.length : 0
    if (count === 0) return
    var exceptId = root.current ? Number(root.current.id) : NaN
    var next = null
    for (var t = 0; t < 16; t++) {
      next = root.signals[Math.floor(Math.random() * count)]
      if (!next) continue
      if (!isFinite(exceptId) || Number(next.id) !== exceptId || count === 1) break
    }
    if (next) root.current = next
  }

  function open(payloadJson) {
    try {
      if (!root.signals || !root.signals.length) root.loadSignals()
      // Empty "{}" must not count as a chosen essay — every reveal/next rolls again.
      var requested = null
      if (payloadJson && payloadJson !== "{}") {
        try { requested = JSON.parse(payloadJson) } catch (e) { requested = null }
      }
      var chosen = requested && requested.title && requested.body
        && String(requested.title).length > 0
        && String(requested.body).length > 0
      if (chosen) root.current = requested
      else root.pickNew()
      root.opened = true
    } catch (e) {
      console.warn("higgsfield.signals open() threw:", e)
    }
  }

  function close() {
    root.opened = false
  }

  Component.onCompleted: root.loadSignals()

  IpcHandler {
    target: "higgsfield.signals"

    // No-arg show/hide collide with Qt Window.show/hide and return empty.
    // OSD takes a string payload for the same reason.
    function show(payloadJson: string): string {
      root.open(payloadJson)
      return "ok"
    }

    function reveal(): string {
      root.open("{}")
      return "ok"
    }

    function close(): string {
      root.close()
      return "ok"
    }

    function next(): string {
      root.open("{}")
      return "ok"
    }

    function ping(): string {
      return "ok"
    }
  }

  IdleMonitor {
    id: idleMonitor
    timeout: root.screensaverTimeoutSeconds
    respectInhibitors: true
    onIsIdleChanged: {
      if (idleMonitor.isIdle) root.open("{}")
    }
  }

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

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: root.opened
      Keys.onPressed: function(event) {
        root.close()
        event.accepted = true
      }

      Flickable {
        id: scroller
        anchors.fill: parent
        anchors.leftMargin: Math.max(48, width * 0.12)
        anchors.rightMargin: Math.max(48, width * 0.12)
        anchors.topMargin: 64
        anchors.bottomMargin: 64
        contentWidth: width
        contentHeight: essay.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
          id: essay
          width: Math.min(680, scroller.width)
          spacing: 20

          Text {
            text: "37signals"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }

          Text {
            width: parent.width
            visible: root.numberText.length > 0
            text: root.numberText + "."
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            topPadding: 28
          }

          Text {
            width: parent.width
            text: root.titleText
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.display
            font.bold: true
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            text: root.bodyText
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            wrapMode: Text.WordWrap
            lineHeight: 1.45
            topPadding: 8
          }
        }

        MouseArea {
          width: essay.width
          height: Math.max(essay.height, scroller.height)
          onClicked: root.close()
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
