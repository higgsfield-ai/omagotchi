import QtQuick
import Quickshell
import Quickshell.Wayland
import "Model.js" as Model
import "Catalog.js" as Catalog

// keepLoaded overlay. Click-through JOTA car on the ASCII screensaver.
// IPC stays on the service — a second IpcHandler on this target would go silent.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property var svc: root.shell && root.shell.serviceFor
    ? root.shell.serviceFor("higgsfield.signals")
    : null
  readonly property bool desktopVisible: svc ? svc.desktopVisible === true : false
  readonly property var car: Model.defaultCar()

  function open(payloadJson) {
    if (root.svc && root.svc.reveal) root.svc.reveal()
  }

  function close() {
    if (root.svc && root.svc.hide) root.svc.hide()
  }

  component SignalBoard: Item {
    id: board
    property int signalIndex: 0
    property real depthScale: 1
    property real yaw: 18
    property real fog: 1
    property var catalog: []

    readonly property var entry: {
      var list = board.catalog
      var n = list && list.length ? list.length : 0
      if (n === 0) return ({ id: 0, title: "", body: "" })
      var i = ((board.signalIndex % n) + n) % n
      return list[i]
    }
    readonly property string numberText: Model.formatNumber(entry && entry.id)
    readonly property string titleText: entry && entry.title ? String(entry.title) : ""
    readonly property string bodyText: Model.billboardBody(entry && entry.body ? entry.body : "")
    readonly property real s: Math.max(0.18, board.depthScale)

    width: Math.round(390 * s)
    height: panel.height + post.height
    opacity: 0.28 + 0.72 * board.fog
    transform: Rotation {
      origin.x: board.width * 0.55
      origin.y: board.height
      axis { x: 0; y: 1; z: 0 }
      angle: board.yaw
    }

    Rectangle {
      id: post
      width: Math.max(6, Math.round(11 * board.s))
      height: Math.round(78 * board.s)
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      color: "#2a2318"
      transform: Scale {
        origin.x: post.width / 2
        origin.y: 0
        yScale: 1.15
      }
    }
    Rectangle {
      id: panel
      anchors.bottom: post.top
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width
      height: col.height + Math.round(24 * board.s)
      color: "#12100c"
      border.color: "#f5c518"
      border.width: Math.max(2, Math.round(3 * board.s))
      radius: 2

      Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(4, Math.round(6 * board.s))
        color: "#000000"
        opacity: 0.35
      }

      Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Math.round(12 * board.s)
        spacing: Math.round(6 * board.s)
        Text {
          text: board.numberText
          color: "#f5c518"
          font.pixelSize: Math.max(11, Math.round(22 * board.s))
          font.bold: true
          font.family: "monospace"
        }
        Text {
          width: parent.width
          text: board.titleText
          color: "#f4f1ea"
          wrapMode: Text.WordWrap
          font.pixelSize: Math.max(10, Math.round(18 * board.s))
          font.bold: true
        }
        Text {
          width: parent.width
          visible: board.s > 0.45
          text: board.bodyText
          color: "#c8c0b0"
          wrapMode: Text.WordWrap
          font.pixelSize: Math.max(9, Math.round(12 * board.s))
        }
      }
    }
  }

  component DriveWindow: PanelWindow {
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

    readonly property real carScale: Math.max(0.48, Math.min(0.78, Math.min(width * 0.38, 680) / root.car.width))
    readonly property real carW: root.car.width * carScale
    readonly property real carH: root.car.height * carScale
    readonly property real speed: 0.0017
    readonly property var catalog: Catalog.all()
    readonly property int catalogCount: catalog && catalog.length ? catalog.length : 0
    readonly property real vpX: width * 0.09
    readonly property real vpY: height * 0.31
    readonly property real nearX: width * 0.57
    readonly property real nearY: height - 28
    readonly property real nearHalf: width * 0.52

    property int tick: 0
    property real scroll: 0
    property real wheelAngle: 0
    property real boardAT: 0.2
    property real boardBT: 0.7
    property int boardIndexA: 0
    property int boardIndexB: 1

    readonly property var carGround: Model.projectTrack(0.90, vpX, vpY, nearX, nearY)
    readonly property real carX: carGround.x - carW * 0.42
    readonly property real carY: carGround.y - carH * 0.84 + Math.round(Math.sin(tick * 0.28) * 2)

    function project(t) {
      return Model.projectTrack(t, window.vpX, window.vpY, window.nearX, window.nearY)
    }

    function resetScene() {
      window.tick = 0
      window.scroll = 0
      window.wheelAngle = 0
      var start = root.svc && root.svc.currentId >= 0 ? root.svc.currentId : 0
      window.boardIndexA = start
      window.boardIndexB = window.catalogCount > 0 ? (start + 1) % window.catalogCount : 0
      window.boardAT = 0.2
      window.boardBT = 0.7
    }

    function wrapBoard(t, indexA, indexB) {
      var nextT = t + window.speed
      var idx = indexA
      if (nextT > 1) {
        nextT -= 1
        idx = Model.nextBillboardIndex(indexA, indexB, window.catalogCount)
      }
      return { t: nextT, index: idx }
    }

    function step() {
      window.tick += 1
      window.scroll += 1.8
      window.wheelAngle = (window.wheelAngle + 17) % 360
      var a = window.wrapBoard(window.boardAT, window.boardIndexA, window.boardIndexB)
      window.boardAT = a.t
      window.boardIndexA = a.index
      var b = window.wrapBoard(window.boardBT, window.boardIndexB, window.boardIndexA)
      window.boardBT = b.t
      window.boardIndexB = b.index
      roadCanvas.requestPaint()
    }

    onVisibleChanged: {
      if (window.visible) {
        window.resetScene()
        roadCanvas.requestPaint()
      }
    }

    Timer {
      interval: 16
      running: window.visible
      repeat: true
      onTriggered: window.step()
    }

    Canvas {
      id: roadCanvas
      anchors.fill: parent
      z: 0
      renderStrategy: Canvas.Cooperative
      onPaint: {
        var ctx = getContext("2d")
        var w = roadCanvas.width
        var h = roadCanvas.height
        ctx.clearRect(0, 0, w, h)
        var vpX = window.vpX
        var vpY = window.vpY
        var nearX = window.nearX
        var nearY = window.nearY
        var segments = 22
        var scroll = window.scroll
        for (var i = 0; i < segments; i++) {
          var t0 = i / segments
          var t1 = (i + 1) / segments
          var p0 = Model.projectTrack(t0, vpX, vpY, nearX, nearY)
          var p1 = Model.projectTrack(t1, vpX, vpY, nearX, nearY)
          var half0 = 14 + t0 * t0 * window.nearHalf
          var half1 = 14 + t1 * t1 * window.nearHalf
          var stripe = (i + Math.floor(scroll / 7)) % 2 === 0
          ctx.beginPath()
          ctx.moveTo(p0.x - half0, p0.y)
          ctx.lineTo(p0.x + half0, p0.y)
          ctx.lineTo(p1.x + half1, p1.y)
          ctx.lineTo(p1.x - half1, p1.y)
          ctx.closePath()
          ctx.fillStyle = stripe ? "#1c1c20" : "#151518"
          ctx.fill()

          var curb0 = 10 + t0 * t0 * 22
          var curb1 = 10 + t1 * t1 * 22
          ctx.beginPath()
          ctx.moveTo(p0.x - half0 - curb0, p0.y)
          ctx.lineTo(p0.x - half0, p0.y)
          ctx.lineTo(p1.x - half1, p1.y)
          ctx.lineTo(p1.x - half1 - curb1, p1.y)
          ctx.closePath()
          ctx.fillStyle = stripe ? "#d92b2b" : "#f2f2f2"
          ctx.fill()
          ctx.beginPath()
          ctx.moveTo(p0.x + half0, p0.y)
          ctx.lineTo(p0.x + half0 + curb0, p0.y)
          ctx.lineTo(p1.x + half1 + curb1, p1.y)
          ctx.lineTo(p1.x + half1, p1.y)
          ctx.closePath()
          ctx.fillStyle = stripe ? "#d92b2b" : "#f2f2f2"
          ctx.fill()

          if (stripe && t1 > 0.08) {
            var d0 = 3 + t0 * t0 * 10
            var d1 = 3 + t1 * t1 * 10
            ctx.beginPath()
            ctx.moveTo(p0.x - d0, p0.y)
            ctx.lineTo(p0.x + d0, p0.y)
            ctx.lineTo(p1.x + d1, p1.y)
            ctx.lineTo(p1.x - d1, p1.y)
            ctx.closePath()
            ctx.fillStyle = "#e6c84a"
            ctx.fill()
          }
        }
      }
    }

    // Fog toward the vanishing point so the ASCII still reads above the horizon.
    Rectangle {
      z: 1
      x: window.vpX - 90
      y: window.vpY - 70
      width: 180
      height: 110
      radius: 80
      opacity: 0.22
      gradient: Gradient {
        GradientStop { position: 0.0; color: "#000000" }
        GradientStop { position: 1.0; color: "#00000000" }
      }
    }

    Repeater {
      model: 2
      SignalBoard {
        required property int index
        readonly property real t: index === 0 ? window.boardAT : window.boardBT
        readonly property var p: window.project(t)
        z: 2 + Math.round(t * 10)
        x: Math.round(p.x - width * 0.52)
        y: Math.round(p.y - height + 8)
        signalIndex: index === 0 ? window.boardIndexA : window.boardIndexB
        depthScale: p.scale
        yaw: 16 + t * 10
        fog: p.fog
        catalog: window.catalog
      }
    }

    Repeater {
      model: 8
      Rectangle {
        required property int index
        z: 3
        readonly property real t: 0.55 + (index / 20)
        readonly property var p: window.project(t)
        width: 10 + t * 50
        height: 2
        color: index % 2 === 0 ? "#66fff6d0" : "#44ff8a3a"
        x: p.x + window.carW * 0.25 + ((window.tick * 10 + index * 80) % 140)
        y: p.y - 40 - index * 8
        visible: window.visible
        opacity: 0.35 + 0.4 * t
      }
    }

    Rectangle {
      id: shadow
      z: 12
      x: Math.round(window.carX + window.carW * 0.10)
      y: Math.round(window.carY + window.carH * 0.78)
      width: window.carW * 0.82
      height: Math.round(window.carH * 0.18)
      radius: height / 2
      color: "#000000"
      opacity: 0.42
      transform: Scale {
        origin.x: shadow.width / 2
        origin.y: shadow.height / 2
        yScale: 0.38
        xScale: 1.08
      }
    }

    Item {
      id: carItem
      z: 13
      x: Math.round(window.carX)
      y: Math.round(window.carY)
      width: window.carW
      height: window.carH
      transform: [
        Rotation {
          origin.x: carItem.width * 0.78
          origin.y: carItem.height * 0.92
          axis { x: 0; y: 1; z: 0 }
          angle: -18
        },
        Rotation {
          origin.x: carItem.width / 2
          origin.y: carItem.height
          axis { x: 1; y: 0; z: 0 }
          angle: 9
        }
      ]

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(parent.height * 0.10)
        width: parent.width * 0.68
        height: Math.round(16 * window.carScale / 0.7)
        radius: height / 2
        color: "#ff3b00"
        opacity: 0.22 + 0.16 * Math.sin(window.tick * 0.2)
      }

      Image {
        id: rearWheel
        source: Qt.resolvedUrl("wheel.png")
        width: (root.car.wheels[1].r * 2 + 1) * window.carScale * 1.08
        height: width
        x: root.car.wheels[1].cx * window.carScale - width / 2
        y: root.car.wheels[1].cy * window.carScale - height / 2
        smooth: true
        mipmap: false
        asynchronous: false
        transform: Rotation {
          origin.x: rearWheel.width / 2
          origin.y: rearWheel.height / 2
          angle: window.wheelAngle
        }
      }
      Image {
        id: frontWheel
        source: Qt.resolvedUrl("wheel.png")
        width: (root.car.wheels[0].r * 2 + 1) * window.carScale * 0.86
        height: width
        x: root.car.wheels[0].cx * window.carScale - width / 2
        y: root.car.wheels[0].cy * window.carScale - height / 2 + 6
        smooth: true
        mipmap: false
        asynchronous: false
        opacity: 0.95
        transform: Rotation {
          origin.x: frontWheel.width / 2
          origin.y: frontWheel.height / 2
          angle: window.wheelAngle
        }
      }

      Image {
        id: body
        anchors.fill: parent
        source: Qt.resolvedUrl("car-body.png")
        fillMode: Image.Stretch
        smooth: true
        mipmap: false
        asynchronous: false
        cache: true
      }

      Rectangle {
        x: root.car.headlight.x * window.carScale - width
        y: root.car.headlight.y * window.carScale - height / 2
        width: Math.round(220 * window.carScale / 0.7)
        height: Math.round(36 * window.carScale / 0.7)
        radius: 12
        rotation: -8
        opacity: 0.32 + 0.12 * Math.sin(window.tick * 0.15)
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: "#00ffe08a" }
          GradientStop { position: 0.55; color: "#77ffe9a0" }
          GradientStop { position: 1.0; color: "#ccfff6d8" }
        }
      }

      Repeater {
        model: 8
        Rectangle {
          required property int index
          property real flicker: 0.55 + 0.45 * Math.abs(Math.sin(window.tick * 0.55 + index * 0.9))
          x: root.car.exhaust.x * window.carScale + 6 + index * Math.round(11 * window.carScale / 0.7)
          y: root.car.exhaust.y * window.carScale - 6 + ((index * 3 + window.tick) % 7) - 3
          width: Math.round((18 - index) * window.carScale / 0.7 * flicker)
          height: Math.round((7 + (index % 3) * 2) * window.carScale / 0.7)
          radius: 2
          color: index < 2 ? "#fff1a8" : (index < 5 ? "#ff7a18" : "#ff2a00")
          opacity: 0.95 - index * 0.08
        }
      }

      Repeater {
        model: 6
        Rectangle {
          required property int index
          visible: (window.tick + index * 5) % 11 < 5
          x: root.car.wheels[1].cx * window.carScale + 8 + ((window.tick * 3 + index * 13) % 28)
          y: root.car.wheels[1].cy * window.carScale + root.car.wheels[1].r * window.carScale * 0.35 + (index % 4) * 3
          width: 3
          height: 3
          color: index % 2 === 0 ? "#ffe566" : "#ff9a2a"
        }
      }

      Rectangle {
        x: parent.width - Math.round(18 * window.carScale / 0.7)
        y: parent.height * 0.38
        width: Math.round(10 * window.carScale / 0.7)
        height: Math.round(7 * window.carScale / 0.7)
        color: "#ff1c1c"
        opacity: 0.45 + 0.55 * ((window.tick % 14) < 7 ? 1 : 0.2)
      }
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      DriveWindow {}
    }
  }
}
