import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Model.js" as Model

// Plugin panel entry (keepLoaded). Nested PanelWindows inside a bar chip
// do not become desktop surfaces — this file is loaded by the shell host.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property var petService: root.shell && root.shell.serviceFor
    ? root.shell.serviceFor("higgsfield.pet")
    : null
  readonly property var atlas: petService ? petService.atlas : Model.normalizeAtlas(null)
  readonly property string mode: petService ? petService.mode : "idle"
  readonly property string placement: petService ? petService.placement : "focus"
  readonly property bool followPointer: root.placement === "pointer"
  readonly property bool followFocus: root.placement === "focus"
  readonly property bool desktopVisible: petService ? petService.desktopVisible : true
  readonly property real pinX: petService ? petService.pinX : -1
  readonly property real pinY: petService ? petService.pinY : -1
  readonly property bool clickThrough: Model.isClickThrough(root.placement)

  property int displaySize: 96
  property int cursorOffset: 20
  property real cursorX: 0
  property real cursorY: 0
  property real focusX: 0
  property real focusY: 0

  property bool opened: root.desktopVisible

  function open(payloadJson) {
    if (root.petService) root.petService.desktopVisible = true
  }

  function close() {
  }

  readonly property real restX: root.pinX >= 0
    ? root.pinX
    : Math.max(0, window.width - root.displaySize - 24)
  readonly property real restY: root.pinY >= 0
    ? root.pinY
    : Math.max(0, window.height - root.displaySize - 24)

  readonly property real targetX: {
    if (root.followPointer) return root.cursorX + root.cursorOffset
    if (root.followFocus) return root.focusX
    return root.restX
  }

  readonly property real targetY: {
    if (root.followPointer) return root.cursorY + root.cursorOffset
    if (root.followFocus) return root.focusY
    return root.restY
  }

  function clampX(x) {
    return Math.max(0, Math.min(x, Math.max(0, window.width - root.displaySize)))
  }

  function clampY(y) {
    return Math.max(0, Math.min(y, Math.max(0, window.height - root.displaySize)))
  }

  function applyFocusJson(text) {
    var box = Model.parseActiveWindow(text)
    if (!box) return
    var pos = Model.focusAnchor(box, root.displaySize, 12)
    root.focusX = pos.x
    root.focusY = pos.y
  }

  PanelWindow {
    id: window
    visible: root.desktopVisible
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "higgsfield-pet"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: root.clickThrough ? emptyMask : petMask

    Region { id: emptyMask }

    Region {
      id: petMask
      item: petFrame
    }

    Rectangle {
      id: petFrame
      width: root.displaySize
      height: root.displaySize
      color: "#00000000"
      border.width: 2
      border.color: "#ff4db8"

      Binding on x {
        value: root.clampX(root.targetX)
        when: !dragArea.pressed
      }

      Binding on y {
        value: root.clampY(root.targetY)
        when: !dragArea.pressed
      }

      Pet {
        anchors.fill: parent
        anchors.margins: 2
        displaySize: root.displaySize - 4
        atlas: root.atlas
        mode: root.mode
      }

      MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: !root.clickThrough
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.OpenHandCursor
        drag.target: petFrame
        onReleased: {
          if (!root.petService) return
          root.petService.placement = "pin"
          root.petService.pinX = petFrame.x
          root.petService.pinY = petFrame.y
        }
      }
    }
  }

  Timer {
    interval: 32
    running: root.desktopVisible && root.followPointer
    repeat: true
    onTriggered: {
      cursorProc.running = false
      cursorProc.running = true
    }
  }

  Timer {
    interval: 80
    running: root.desktopVisible && root.followFocus
    repeat: true
    onTriggered: {
      focusProc.running = false
      focusProc.running = true
    }
  }

  Process {
    id: cursorProc
    command: ["hyprctl", "cursorpos"]
    stdout: SplitParser {
      onRead: function(data) {
        var text = String(data).trim()
        var parts = text.split(/[,\s]+/)
        if (parts.length < 2) return
        var x = Number(parts[0])
        var y = Number(parts[1])
        if (!isFinite(x) || !isFinite(y)) return
        root.cursorX = x
        root.cursorY = y
      }
    }
  }

  Process {
    id: focusProc
    command: ["hyprctl", "-j", "activewindow"]
    stdout: StdioCollector {
      onStreamFinished: root.applyFocusJson(this.text)
    }
  }
}
