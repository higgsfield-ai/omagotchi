import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Model.js" as Model

// Overlay sprite, not the bar dropdown. Follows the Hyprland pointer.
// It cannot follow the text caret — Wayland does not expose that.
Item {
  id: root

  property var atlas: Model.normalizeAtlas(null)
  property string mode: "idle"
  property bool followPointer: true
  property bool desktopVisible: true
  property real pinX: -1
  property real pinY: -1
  property int displaySize: 96
  property int cursorOffset: 20
  property real cursorX: 0
  property real cursorY: 0

  signal draggedTo(real x, real y)

  readonly property real restX: root.pinX >= 0
    ? root.pinX
    : Math.max(0, window.width - root.displaySize - 24)
  readonly property real restY: root.pinY >= 0
    ? root.pinY
    : Math.max(0, window.height - root.displaySize - 24)
  readonly property real followX: root.cursorX + root.cursorOffset
  readonly property real followY: root.cursorY + root.cursorOffset

  function clampX(x) {
    return Math.max(0, Math.min(x, Math.max(0, window.width - root.displaySize)))
  }

  function clampY(y) {
    return Math.max(0, Math.min(y, Math.max(0, window.height - root.displaySize)))
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
    mask: root.followPointer ? emptyMask : petMask

    Region { id: emptyMask }

    Region {
      id: petMask
      item: pet
    }

    Pet {
      id: pet
      displaySize: root.displaySize
      atlas: root.atlas
      mode: root.mode

      Binding on x {
        value: root.clampX(root.followPointer ? root.followX : root.restX)
        when: !dragArea.pressed
      }

      Binding on y {
        value: root.clampY(root.followPointer ? root.followY : root.restY)
        when: !dragArea.pressed
      }

      MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: !root.followPointer
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.OpenHandCursor
        drag.target: pet
        onReleased: root.draggedTo(pet.x, pet.y)
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

  Process {
    id: cursorProc
    command: ["hyprctl", "cursorpos"]
    stdout: StdioCollector {
      onStreamFinished: {
        var text = String(this.text).trim()
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
}
