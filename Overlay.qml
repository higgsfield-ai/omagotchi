import QtQuick
import Quickshell
import Quickshell.Wayland
import "Model.js" as Model

// keepLoaded overlay. The pet is a tiny click-through window — never a
// fullscreen Top surface, which sat on the Omarchy bar and ate HF clicks.
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
    visible: root.svc && root.svc.petOnDesktop && window.stageRect.w > 16 && window.stageRect.h > 16
      && !!root.svc.focusedMonitor && modelData && modelData.name === root.svc.focusedMonitor
    color: "transparent"
    WlrLayershell.namespace: "higgsfield-signals-pet"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    // Empty mask: every pointer event passes through to the bar and windows.
    mask: Region {}
    anchors.left: true
    anchors.top: true
    margins.left: Math.round(window.stageRect.x + window.petX)
    margins.top: Math.max(40, Math.round(window.stageRect.y + window.petY - window.bounce))
    implicitWidth: Math.max(1, window.frames.displayWidth)
    implicitHeight: Math.max(1, window.frames.displayHeight)

    readonly property real screenW: modelData ? Number(modelData.width) : 0
    readonly property real screenH: modelData ? Number(modelData.height) : 0
    readonly property real winX: root.svc ? Number(root.svc.winX) : 0
    readonly property real winY: root.svc ? Number(root.svc.winY) : 0
    readonly property real winW: root.svc ? Number(root.svc.winW) : 0
    readonly property real winH: root.svc ? Number(root.svc.winH) : 0
    readonly property var stageRect: Model.clipWindowRect({
      x: window.winX,
      y: window.winY,
      w: window.winW,
      h: window.winH
    }, window.screenW, window.screenH)
    readonly property bool collapsed: root.svc ? !!root.svc.collapsed : false
    readonly property bool recalling: root.svc ? !!root.svc.petRecalling : false
    readonly property bool releasing: root.svc ? !!root.svc.petReleasing : false
    readonly property bool airborne: window.falling || window.recalling || window.releasing
    readonly property string mode: {
      if (window.recalling) return "drag"
      if (window.releasing && !window.falling) return "drag"
      if (window.collapsed) return "collapse"
      if (window.falling) return "drag"
      return root.svc ? String(root.svc.mode || "idle") : "idle"
    }
    readonly property var frames: Model.framesForMode(root.atlas, window.mode)
    readonly property var careStats: root.svc ? {
      hunger: Number(root.svc.careHunger),
      hygiene: Number(root.svc.careHygiene),
      mood: Number(root.svc.careMood),
      energy: Number(root.svc.careEnergy),
      health: Number(root.svc.careHealth),
      attention: Number(root.svc.careAttention),
      excitement: Number(root.svc.careExcitement),
      focus: Number(root.svc.careFocus),
      music: Number(root.svc.careMusic),
      bond: Number(root.svc.careBond),
      weight: Number(root.svc.careWeight),
      bornMs: Number(root.svc.careBornMs),
      updatedMs: Number(root.svc.careUpdatedMs)
    } : null
    readonly property var pace: Model.movePace(window.mode, window.careStats)
    readonly property real peak: root.svc ? Number(root.svc.audioPeak) : 0
    readonly property int bounce: {
      if (window.airborne || window.collapsed) return 0
      if (window.mode === "sleep" || window.mode === "trip" || window.mode === "eat" || window.mode === "wash")
        return 0
      if (Model.isMoveMode(window.mode) || window.mode === "greet" || window.mode === "grumpy" || window.mode === "sick" || window.mode === "happy")
        return 0
      return Math.round(Math.max(0, window.peak) * 16)
    }
    readonly property real floorY: Model.petBottomY(window.frames.displayHeight, window.stageRect.h, 4)

    property real petX: 12
    property real petY: 0
    property real fallVel: 0
    property real fallFromY: 0
    property int facing: 1
    property int frame: 0
    property bool falling: false

    onModeChanged: window.frame = 0
    onVisibleChanged: {
      if (!window.visible) return
      if (root.svc && root.svc.petReleasing) {
        window.startSpawnFall()
        return
      }
      pet.opacity = 1
      window.snapInside()
    }
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
      window.fallVel = 0
      window.fallFromY = window.petY
      fallAnim.from = window.petY
      fallAnim.to = window.floorY
      fallAnim.duration = Model.fallDurationMs(window.floorY - window.petY)
      fallAnim.start()
    }

    function startLevitate() {
      window.stopFall()
      if (spawnFade.running) spawnFade.stop()
      if (levitateAnim.running) levitateAnim.stop()
      window.falling = false
      pet.opacity = 1
      levY.from = window.petY
      levY.to = -Math.max(16, window.frames.displayHeight * 0.4)
      var dur = Model.levitateDurationMs(Math.max(0, window.petY))
      levY.duration = dur
      levFade.duration = dur
      levFade.from = pet.opacity
      levFade.to = 0
      levitateAnim.start()
    }

    function startSpawnFall() {
      if (!window.visible) return
      if (levitateAnim.running) levitateAnim.stop()
      if (spawnFade.running) spawnFade.stop()
      window.stopFall()
      pet.opacity = 0
      window.petY = window.floorY
      window.petX = Model.clampPetX(window.petX, window.frames.displayWidth, window.stageRect.w)
      spawnFade.start()
    }

    function land() {
      if (!window.falling) return
      window.petY = window.floorY
      window.falling = false
      window.fallVel = 0
      pet.opacity = 1
      if (root.svc && root.svc.petReleasing && typeof root.svc.finishRelease === "function")
        root.svc.finishRelease()
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

    NumberAnimation {
      id: spawnFade
      target: pet
      property: "opacity"
      from: 0
      to: 1
      duration: 280
      easing.type: Easing.OutQuad
    }

    ParallelAnimation {
      id: levitateAnim
      NumberAnimation {
        id: levY
        target: window
        property: "petY"
        easing.type: Easing.InCubic
      }
      NumberAnimation {
        id: levFade
        target: pet
        property: "opacity"
        easing.type: Easing.InQuad
      }
      onFinished: {
        if (root.svc && root.svc.petRecalling && typeof root.svc.finishRecall === "function")
          root.svc.finishRecall()
      }
    }

    Connections {
      target: root.svc
      function onWinXChanged() { if (window.visible && !window.airborne) window.snapInside() }
      function onWinYChanged() { if (window.visible && !window.airborne) window.snapInside() }
      function onWinWChanged() { if (window.visible && !window.airborne) window.snapInside() }
      function onWinHChanged() { if (window.visible && !window.airborne) window.snapInside() }
      function onPetRecallingChanged() {
        if (root.svc && root.svc.petRecalling) window.startLevitate()
        else if (levitateAnim.running) levitateAnim.stop()
      }
      function onPetReleasingChanged() {
        if (root.svc && root.svc.petReleasing) window.startSpawnFall()
      }
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
          return Math.max(40, Math.round(1000 / Model.danceFps(window.peak, window.careStats)))
        if (window.mode === "trip") return 90
        if (window.mode === "happy") return 110
        if (window.mode === "eat" || window.mode === "wash") return 140
        if (window.mode === "night") return 200
        if (window.mode === "drag" || window.mode === "collapse" || window.mode === "sleep") return 240
        if (window.mode === "look" || window.mode === "greet") return 140
        if (window.mode === "grumpy" || window.mode === "sick") return 160
        return 180
      }
      running: window.visible && !Model.isMoveMode(window.mode)
      repeat: true
      onTriggered: {
        if (window.mode === "trip") {
          if (window.frame + 1 >= window.frames.frameCount) {
            window.frame = Math.max(0, window.frames.frameCount - 1)
            if (root.svc && typeof root.svc.onTripFinished === "function")
              root.svc.onTripFinished()
            return
          }
          window.frame += 1
          return
        }
        window.frame = (window.frame + 1) % Math.max(1, window.frames.frameCount)
      }
    }

    Item {
      id: pet
      anchors.fill: parent

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
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      PetWindow {}
    }
  }
}
