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
  readonly property var atlas: root.svc && root.svc.atlas
    ? root.svc.atlas
    : Model.normalizeAtlas(null)

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
    readonly property bool airborne: window.dragging || window.falling
    readonly property string mode: {
      if (window.collapsed) return "collapse"
      if (window.dragging) return "drag"
      if (window.falling) return "sick"
      return root.svc ? String(root.svc.mode || "idle") : "idle"
    }
    readonly property var frames: Model.framesForMode(root.atlas, window.mode)
    readonly property var pace: Model.movePace(window.mode)
    readonly property real peak: root.svc ? Number(root.svc.audioPeak) : 0
    readonly property int bounce: {
      if (window.airborne || window.collapsed) return 0
      if (Model.isMoveMode(window.mode) || window.mode === "greet" || window.mode === "grumpy" || window.mode === "sick")
        return 0
      return Math.round(Math.max(0, window.peak) * 16)
    }
    readonly property real floorY: Model.petBottomY(window.frames.displayHeight, window.stageRect.h, 4)

    property real petX: 12
    property real petY: 0
    property real fallVel: 0
    property int facing: 1
    property int frame: 0
    property bool dragging: false
    property bool falling: false

    onModeChanged: window.frame = 0
    onVisibleChanged: if (window.visible) window.snapInside()
    onFloorYChanged: if (!window.airborne) window.petY = window.floorY

    function maxPetX() {
      return Math.max(0, window.stageRect.w - window.frames.displayWidth)
    }

    function snapInside() {
      window.petX = Model.clampPetX(window.petX, window.frames.displayWidth, window.stageRect.w)
      if (!window.airborne)
        window.petY = window.floorY
    }

    function stopFall() {
      if (fallAnim.running) fallAnim.stop()
      window.falling = false
      window.fallVel = 0
    }

    function startFall() {
      if (fallAnim.running) fallAnim.stop()
      window.falling = true
      window.dragging = false
      window.fallVel = 0
      fallAnim.from = window.petY
      fallAnim.to = window.floorY
      fallAnim.duration = Model.fallDurationMs(window.floorY - window.petY)
      fallAnim.start()
    }

    function land() {
      if (!window.falling) return
      window.petY = window.floorY
      window.falling = false
      window.fallVel = 0
      if (root.svc && root.svc.onDroppedFromHeight)
        root.svc.onDroppedFromHeight()
    }

    function stepMove() {
      if (window.collapsed || window.airborne) return
      if (!Model.isMoveMode(window.mode)) return
      var maxX = window.maxPetX()
      window.petX += window.facing * window.pace.step
      if (window.petX > maxX) {
        window.petX = maxX
        window.facing = -1
      } else if (window.petX < 0) {
        window.petX = 0
        window.facing = 1
      }
      window.frame = (window.frame + 1) % Math.max(1, window.frames.frameCount)
    }

    NumberAnimation {
      id: fallAnim
      target: window
      property: "petY"
      easing.type: Easing.InCubic
      onFinished: window.land()
    }

    Connections {
      target: root.svc
      enabled: window.visible
      function onWinXChanged() { window.snapInside() }
      function onWinYChanged() { window.snapInside() }
      function onWinWChanged() { window.snapInside() }
      function onWinHChanged() { window.snapInside() }
    }

    Timer {
      interval: window.pace.interval
      running: window.visible && Model.isMoveMode(window.mode) && !window.airborne
      repeat: true
      onTriggered: window.stepMove()
    }

    Timer {
      interval: {
        if (window.mode === "dance" || window.mode === "flip")
          return Math.max(40, Math.round(1000 / Model.danceFps(window.peak)))
        if (window.mode === "drag" || window.mode === "collapse") return 240
        if (window.mode === "look" || window.mode === "greet") return 140
        if (window.mode === "grumpy" || window.mode === "sick") return 160
        return 180
      }
      running: window.visible && !Model.isMoveMode(window.mode)
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
        y: Math.round(window.petY - window.bounce)

        Image {
          anchors.fill: parent
          source: {
            var abs = Model.atlasImageSource(root.atlas.file)
            var src = abs.indexOf("file://") === 0 ? abs : Qt.resolvedUrl(root.atlas.file)
            var rev = root.svc ? Number(root.svc.atlasRev || 0) : 0
            return src + "?r=" + rev
          }
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
            if (window.falling) {
              window.stopFall()
              window.dragging = true
              didMove = true
            }
          }
          onPositionChanged: function(mouse) {
            var g = mapToItem(stage, mouse.x, mouse.y)
            var nx = g.x - grabX
            var ny = g.y - grabY
            if (!didMove && Math.abs(nx - window.petX) < 5 && Math.abs(ny - window.petY) < 5)
              return
            didMove = true
            window.stopFall()
            window.dragging = true
            window.petX = Model.clampPetX(nx, pet.width, stage.width)
            window.petY = Model.clamp(ny, 0, Math.max(0, stage.height - pet.height))
          }
          onReleased: function() {
            if (!didMove) {
              window.dragging = false
              if (root.svc && root.svc.onPetClicked)
                root.svc.onPetClicked()
              return
            }
            if (Model.shouldFall(window.petY, window.floorY, 8)) {
              window.startFall()
              return
            }
            window.dragging = false
            window.petY = window.floorY
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
