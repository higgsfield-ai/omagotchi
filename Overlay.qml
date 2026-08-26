import QtQuick
import Quickshell
import Quickshell.Wayland
import "Model.js" as Model

// keepLoaded overlay. Desktop Tamagotchi on the focused window.
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
    visible: root.svc && root.svc.petVisible && window.winW > 16 && window.winH > 16 && (
      !root.svc.focusedMonitor
      || root.svc.focusedMonitor === ""
      || (modelData && modelData.name === root.svc.focusedMonitor)
    )
    color: "transparent"
    WlrLayershell.namespace: "higgsfield-signals-pet"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    mask: Region { item: pet }
    anchors { top: true; bottom: true; left: true; right: true }

    readonly property real winX: root.svc ? Number(root.svc.winX) : 0
    readonly property real winY: root.svc ? Number(root.svc.winY) : 0
    readonly property real winW: root.svc ? Number(root.svc.winW) : 0
    readonly property real winH: root.svc ? Number(root.svc.winH) : 0
    readonly property var stageRect: Model.clipWindowRect({
      x: window.winX,
      y: window.winY,
      w: window.winW,
      h: window.winH
    }, window.width, window.height)
    readonly property bool collapsed: root.svc ? !!root.svc.collapsed : false
    readonly property string mode: {
      if (window.collapsed) return "collapse"
      if (window.dragging) return "drag"
      return root.svc ? String(root.svc.mode || "idle") : "idle"
    }
    readonly property var frames: Model.framesForMode(root.atlas, window.mode)
    readonly property real peak: root.svc ? Number(root.svc.audioPeak) : 0
    readonly property int bounce: {
      if (window.dragging || window.collapsed || window.mode === "walk") return 0
      return Math.round(Math.max(0, window.peak) * 16)
    }

    property real petX: 12
    property real petY: 0
    property int facing: 1
    property int frame: 0
    property bool dragging: false

    onModeChanged: window.frame = 0
    onVisibleChanged: if (window.visible) window.snapInside()

    function maxPetX() {
      return Math.max(0, window.stageRect.w - window.frames.displayWidth)
    }

    function snapInside() {
      window.petX = Model.clampPetX(window.petX, window.frames.displayWidth, window.stageRect.w)
      if (!window.dragging)
        window.petY = Model.petBottomY(window.frames.displayHeight, window.stageRect.h, 4)
    }

    function stepWalk() {
      if (window.collapsed || window.dragging) return
      var maxX = window.maxPetX()
      window.petX += window.facing * 8
      if (window.petX > maxX) {
        window.petX = maxX
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
      function onWinXChanged() { window.snapInside() }
      function onWinYChanged() { window.snapInside() }
      function onWinWChanged() { window.snapInside() }
      function onWinHChanged() { window.snapInside() }
    }

    Timer {
      interval: {
        if (window.mode === "walk") return 1000
        if (window.mode === "dance" || window.mode === "flip")
          return Math.max(40, Math.round(1000 / Model.danceFps(window.peak)))
        if (window.mode === "collapse" || window.mode === "drag") return 240
        return 180
      }
      running: window.visible && window.mode !== "walk"
      repeat: true
      onTriggered: window.frame = (window.frame + 1) % Math.max(1, window.frames.frameCount)
    }

    Item {
      id: stage
      x: Math.round(window.stageRect.x)
      y: Math.round(window.stageRect.y)
      width: Math.round(window.stageRect.w)
      height: Math.round(window.stageRect.h)
      clip: true
      visible: width > 8 && height > 8

      Item {
        id: pet
        width: window.frames.displayWidth
        height: window.frames.displayHeight
        x: Math.round(window.petX)
        y: Math.round(window.dragging
          ? window.petY
          : (Model.petBottomY(height, stage.height, 4) - window.bounce))

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
          mirror: window.facing < 0
          smooth: false
          mipmap: false
          asynchronous: false
          cache: false
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
          property real grabX: 0
          property real grabY: 0
          property bool didMove: false

          onPressed: function(mouse) {
            grabX = mouse.x
            grabY = mouse.y
            didMove = false
            window.petY = pet.y
          }
          onPositionChanged: function(mouse) {
            var g = mapToItem(stage, mouse.x, mouse.y)
            var nx = g.x - grabX
            var ny = g.y - grabY
            if (!didMove && Math.abs(nx - window.petX) < 5 && Math.abs(ny - window.petY) < 5)
              return
            didMove = true
            window.dragging = true
            window.petX = Model.clampPetX(nx, pet.width, stage.width)
            window.petY = Model.clamp(ny, 0, Math.max(0, stage.height - pet.height))
          }
          onReleased: function() {
            if (!didMove && root.svc && root.svc.toggleCollapsed)
              root.svc.toggleCollapsed()
            window.dragging = false
            window.snapInside()
          }
        }
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
