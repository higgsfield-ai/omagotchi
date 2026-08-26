import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "Model.js" as Model
import "Catalog.js" as Catalog

// keepLoaded panel. Same shape as omarchy.osd: IpcHandler + PanelWindow
// on one Item. Catalog.js holds the essays as a real JS array.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property int currentId: -1
  property string currentTitle: ""
  property string currentBody: ""

  readonly property var idleConfig: shell && shell.shellConfig && shell.shellConfig.idle
    ? shell.shellConfig.idle
    : ({})
  readonly property int screensaverTimeoutSeconds: Model.screensaverSeconds(idleConfig, 150)
  readonly property string numberText: root.currentId >= 0 ? Model.formatNumber(root.currentId) : ""
  readonly property string titleText: root.currentTitle
  readonly property string bodyText: root.currentBody

  function applySignal(signal) {
    if (!signal) return false
    root.currentId = Number(signal.id)
    root.currentTitle = String(signal.title || "")
    root.currentBody = String(signal.body || "")
    return root.currentTitle.length > 0
  }

  function pickNew() {
    root.applySignal(Catalog.pick(root.currentId))
  }

  function open(payloadJson) {
    try {
      root.pickNew()
      root.opened = true
    } catch (e) {
      console.warn("higgsfield.signals open() threw:", e)
    }
  }

  function close() {
    root.opened = false
  }

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
