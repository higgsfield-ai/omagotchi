import QtQuick
import Quickshell
import Quickshell.Wayland
import "Model.js" as Model

// keepLoaded overlay. Click-through runner on top of the ASCII screensaver.
// IPC stays on the service — a second IpcHandler on this target would go silent.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property var svc: root.shell && root.shell.serviceFor
    ? root.shell.serviceFor("higgsfield.signals")
    : null
  readonly property bool desktopVisible: svc ? svc.desktopVisible === true : false
  readonly property var atlas: Model.normalizeAtlas(null)
  readonly property var runFrames: Model.framesForMode(root.atlas, "run")

  function open(payloadJson) {
    if (root.svc && root.svc.reveal) root.svc.reveal()
  }

  function close() {
    if (root.svc && root.svc.hide) root.svc.hide()
  }

  component RunnerWindow: PanelWindow {
    id: window

    required property var modelData

    screen: modelData
    visible: root.desktopVisible
    color: "transparent"
    WlrLayershell.namespace: "higgsfield-signals-pet"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    anchors { top: true; bottom: true; left: true; right: true }

    property int frame: 0
    property real runnerX: -root.runFrames.displayWidth

    onVisibleChanged: {
      if (window.visible) {
        window.frame = 0
        window.runnerX = -root.runFrames.displayWidth
      }
    }

    Timer {
      interval: Math.max(40, Math.round(1000 / root.runFrames.frameRate))
      running: window.visible
      repeat: true
      onTriggered: window.frame = (window.frame + 1) % root.runFrames.frameCount
    }

    Timer {
      interval: 16
      running: window.visible
      repeat: true
      onTriggered: {
        window.runnerX += 8
        if (window.runnerX > window.width)
          window.runnerX = -root.runFrames.displayWidth
      }
    }

    Image {
      id: pet
      x: Math.round(window.runnerX)
      y: Math.round(window.height - height - Math.max(48, window.height * 0.08))
      width: root.runFrames.displayWidth
      height: root.runFrames.displayHeight
      source: Qt.resolvedUrl(root.atlas.file)
      sourceClipRect: Qt.rect(
        root.runFrames.frameX + window.frame * root.runFrames.frameWidth,
        root.runFrames.frameY,
        root.runFrames.frameWidth,
        root.runFrames.frameHeight
      )
      fillMode: Image.Stretch
      smooth: false
      mipmap: false
      asynchronous: false
      cache: false
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      RunnerWindow {}
    }
  }
}
