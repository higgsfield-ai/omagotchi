import QtQuick
import Quickshell
import Quickshell.Wayland
import "Model.js" as Model

// keepLoaded overlay. Desktop Tamagotchi on the focused monitor.
// IPC stays on the service — a second IpcHandler on this target would go silent.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property var svc: root.shell && root.shell.serviceFor
    ? root.shell.serviceFor("higgsfield.signals")
    : null
  readonly property var atlas: Model.normalizeAtlas(null)

  function open(payloadJson) {}
  function close() {}

  component PetWindow: PanelWindow {
    id: window

    required property var modelData

    screen: modelData
    visible: root.svc && root.svc.petVisible && (
      !root.svc.focusedMonitor
      || root.svc.focusedMonitor === ""
      || (modelData && modelData.name === root.svc.focusedMonitor)
    )
    color: "transparent"
    WlrLayershell.namespace: "higgsfield-signals-pet"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    anchors { top: true; bottom: true; left: true; right: true }

    readonly property string mode: root.svc ? String(root.svc.mode || "idle") : "idle"
    readonly property var frames: Model.framesForMode(root.atlas, window.mode)
    readonly property real peak: root.svc ? Number(root.svc.audioPeak) : 0
    readonly property int bounce: window.mode === "walk" ? 0 : Math.round(Math.max(0, window.peak) * 32)

    property real petX: 64
    property int facing: 1
    property int frame: 0

    onModeChanged: window.frame = 0
    onVisibleChanged: if (window.visible && window.petX < 8) window.petX = 64

    function stepWalk() {
      var w = window.frames.displayWidth
      window.petX += window.facing * 18
      if (window.petX > window.width - w) {
        window.petX = window.width - w
        window.facing = -1
      } else if (window.petX < 0) {
        window.petX = 0
        window.facing = 1
      }
      window.frame = (window.frame + 1) % Math.max(1, window.frames.frameCount)
    }

    Connections {
      target: root.svc
      enabled: window.visible
      function onKeyCountChanged() { window.stepWalk() }
    }

    Timer {
      interval: {
        if (window.mode === "walk") return 1000
        if (window.mode === "dance" || window.mode === "flip")
          return Math.max(40, Math.round(1000 / Model.danceFps(window.peak)))
        return 140
      }
      running: window.visible && window.mode !== "walk"
      repeat: true
      onTriggered: window.frame = (window.frame + 1) % Math.max(1, window.frames.frameCount)
    }

    Item {
      id: pet
      width: window.frames.displayWidth
      height: window.frames.displayHeight
      x: Math.round(window.petX)
      y: Math.round(window.height - height - 40 - window.bounce)
      transform: Scale {
        origin.x: pet.width / 2
        origin.y: pet.height / 2
        xScale: window.facing
      }

      Image {
        anchors.fill: parent
        source: Qt.resolvedUrl(root.atlas.file)
        sourceClipRect: Qt.rect(
          window.frames.frameX + window.frame * window.frames.frameWidth,
          window.frames.frameY,
          window.frames.frameWidth,
          window.frames.frameHeight
        )
        fillMode: Image.Stretch
        smooth: false
        mipmap: false
        asynchronous: false
        cache: false
      }
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      PetWindow {}
    }
  }
}
