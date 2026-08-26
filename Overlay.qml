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
    property real carScale: 1
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

    width: Math.round(410 * Math.max(0.85, carScale / 0.7))
    height: panel.height + post.height

    Rectangle {
      id: post
      width: Math.max(10, Math.round(12 * board.carScale / 0.7))
      height: Math.round(86 * board.carScale / 0.7)
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      color: "#2a2318"
    }
    Rectangle {
      id: panel
      anchors.bottom: post.top
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width
      height: col.height + 28
      color: "#12100c"
      border.color: "#f5c518"
      border.width: 3
      radius: 2

      Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 8
        Text {
          text: board.numberText
          color: "#f5c518"
          font.pixelSize: Math.max(18, Math.round(22 * board.carScale / 0.7))
          font.bold: true
          font.family: "monospace"
        }
        Text {
          width: parent.width
          text: board.titleText
          color: "#f4f1ea"
          wrapMode: Text.WordWrap
          font.pixelSize: Math.max(16, Math.round(20 * board.carScale / 0.7))
          font.bold: true
        }
        Text {
          width: parent.width
          text: board.bodyText
          color: "#c8c0b0"
          wrapMode: Text.WordWrap
          font.pixelSize: Math.max(12, Math.round(13 * board.carScale / 0.7))
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

    readonly property real carScale: Math.max(0.48, Math.min(0.82, Math.min(width * 0.40, 720) / root.car.width))
    readonly property real carW: root.car.width * carScale
    readonly property real carH: root.car.height * carScale
    readonly property real roadH: Math.max(88, Math.round(height * 0.15))
    readonly property real speed: 3.2
    readonly property var catalog: Catalog.all()
    readonly property int catalogCount: catalog && catalog.length ? catalog.length : 0

    property int tick: 0
    property real scroll: 0
    property real wheelAngle: 0
    property real boardAX: 40
    property real boardBX: -900
    property int boardIndexA: 0
    property int boardIndexB: 1

    readonly property real carX: width * 0.52
    readonly property real carY: height - roadH - carH * 0.70 + Math.round(Math.sin(tick * 0.28) * 2)
    readonly property real boardSpacing: Math.max(width * 0.9, 860)

    function resetScene() {
      window.tick = 0
      window.scroll = 0
      window.wheelAngle = 0
      var start = root.svc && root.svc.currentId >= 0 ? root.svc.currentId : 0
      window.boardIndexA = start
      window.boardIndexB = window.catalogCount > 0 ? (start + 1) % window.catalogCount : 0
      window.boardAX = 36
      window.boardBX = 36 - window.boardSpacing
    }

    function step() {
      window.tick += 1
      window.scroll += window.speed
      window.wheelAngle = (window.wheelAngle + 17) % 360
      window.boardAX += window.speed
      window.boardBX += window.speed
      if (window.boardAX > window.width + 60) {
        window.boardAX = window.boardBX - window.boardSpacing
        window.boardIndexA = Model.nextBillboardIndex(window.boardIndexA, window.boardIndexB, window.catalogCount)
      }
      if (window.boardBX > window.width + 60) {
        window.boardBX = window.boardAX - window.boardSpacing
        window.boardIndexB = Model.nextBillboardIndex(window.boardIndexA, window.boardIndexB, window.catalogCount)
      }
    }

    onVisibleChanged: if (window.visible) window.resetScene()

    Timer {
      interval: 16
      running: window.visible
      repeat: true
      onTriggered: window.step()
    }

    // Billboard road — world scrolls right because the car faces left.
    SignalBoard {
      x: Math.round(window.boardAX)
      y: Math.round(window.height - window.roadH - height + 18)
      z: 1
      signalIndex: window.boardIndexA
      carScale: window.carScale
      catalog: window.catalog
    }
    SignalBoard {
      x: Math.round(window.boardBX)
      y: Math.round(window.height - window.roadH - height + 18)
      z: 1
      signalIndex: window.boardIndexB
      carScale: window.carScale
      catalog: window.catalog
    }

    // Speed lines behind the car (to the right).
    Repeater {
      model: 9
      Rectangle {
        required property int index
        z: 2
        width: 18 + (index * 7 + window.tick * 3) % 70
        height: 2
        color: index % 2 === 0 ? "#80fff6d0" : "#55ff8a3a"
        x: window.carX + window.carW * 0.72 + ((window.tick * 14 + index * 97) % Math.max(120, window.width - window.carX))
        y: window.carY + window.carH * 0.28 + (index * 14) % Math.round(window.carH * 0.55)
        visible: window.visible
      }
    }

    Rectangle {
      id: road
      z: 3
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: window.roadH
      color: "#161616"
      Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 4
        color: "#2c2c2c"
      }
      Repeater {
        model: Math.ceil(window.width / 72) + 3
        Rectangle {
          required property int index
          width: 36
          height: 5
          color: "#e6c84a"
          y: Math.round(road.height * 0.46)
          x: -40 + ((index * 72 + Math.floor(window.scroll)) % (window.width + 72))
        }
      }
    }

    Item {
      id: carItem
      z: 4
      x: Math.round(window.carX)
      y: Math.round(window.carY)
      width: window.carW
      height: window.carH

      // Underglow
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(parent.height * 0.08)
        width: parent.width * 0.72
        height: Math.round(18 * window.carScale / 0.7)
        radius: height / 2
        color: "#ff3b00"
        opacity: 0.28 + 0.18 * Math.sin(window.tick * 0.2)
      }

      Image {
        id: rearWheel
        source: Qt.resolvedUrl("wheel.png")
        width: (root.car.wheels[1].r * 2 + 1) * window.carScale
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
        width: (root.car.wheels[0].r * 2 + 1) * window.carScale
        height: width
        x: root.car.wheels[0].cx * window.carScale - width / 2
        y: root.car.wheels[0].cy * window.carScale - height / 2
        smooth: true
        mipmap: false
        asynchronous: false
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
        smooth: false
        mipmap: false
        asynchronous: false
        cache: true
      }

      // Headlight cone (nose is on the left).
      Rectangle {
        x: root.car.headlight.x * window.carScale - width
        y: root.car.headlight.y * window.carScale - height / 2
        width: Math.round(160 * window.carScale / 0.7)
        height: Math.round(28 * window.carScale / 0.7)
        radius: 8
        rotation: 0
        opacity: 0.35 + 0.12 * Math.sin(window.tick * 0.15)
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: "#00ffe08a" }
          GradientStop { position: 0.45; color: "#88ffe9a0" }
          GradientStop { position: 1.0; color: "#ccfff6d8" }
        }
      }

      // Exhaust flames — rear is on the right.
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

      // Sparks off the rear tire.
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

      // Taillight pulse.
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
