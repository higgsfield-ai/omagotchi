import QtQuick
import qs.Commons

Column {
  id: root
  spacing: Style.space(8)

  property var bar: null
  property color foreground: "#ffffff"
  property bool generating: false
  property bool loggingIn: false
  property int percent: 0
  property int step: 0
  property int steps: 0
  property string statusText: ""

  readonly property bool active: root.generating || root.loggingIn
  readonly property real progress: Math.min(1, Math.max(0, root.percent / 100))
  readonly property int cells: 16
  readonly property int filled: Math.round(root.progress * root.cells)
  readonly property bool indeterminate: root.active && root.percent <= 0
  property int sweep: 0
  property int dots: 0

  Timer {
    interval: 120
    running: root.indeterminate
    repeat: true
    onTriggered: root.sweep = (root.sweep + 1) % (root.cells + 5)
  }

  Timer {
    interval: 420
    running: root.active
    repeat: true
    onTriggered: root.dots = (root.dots + 1) % 4
  }

  function cellOn(index) {
    if (root.indeterminate)
      return index >= root.sweep - 3 && index < root.sweep
    return index < root.filled
  }

  Row {
    width: parent.width
    spacing: Style.space(8)

    Text {
      id: percentLabel
      text: root.percent > 0 ? (root.percent + "%") : (root.active ? "…" : "")
      color: root.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.subtitle + 6
      font.bold: true
      visible: root.active || root.percent > 0
    }

    Text {
      id: statusLabel
      width: Math.max(40, parent.width - percentLabel.width - parent.spacing)
      text: {
        var label = root.statusText || (root.loggingIn ? "Waiting for browser" : (root.generating ? "Working" : ""))
        if (!root.active) return label
        return label.replace(/\.+$/, "") + ["", ".", "..", "..."][root.dots]
      }
      color: root.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.subtitle
      wrapMode: Text.WordWrap
      opacity: 0.88
      verticalAlignment: Text.AlignVCenter
      anchors.verticalCenter: parent.verticalCenter

      SequentialAnimation on opacity {
        running: root.generating
        loops: Animation.Infinite
        NumberAnimation { to: 0.4; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
        onStopped: statusLabel.opacity = 0.88
      }
    }
  }

  Item {
    id: track
    width: parent.width
    height: Style.space(14)
    clip: true

    Row {
      id: cellRow
      anchors.fill: parent
      spacing: 2

      Repeater {
        model: root.cells
        Rectangle {
          width: Math.max(2, (track.width - (root.cells - 1) * cellRow.spacing) / root.cells)
          height: track.height
          radius: 1
          color: root.foreground
          opacity: root.cellOn(index) ? 1 : 0.14
          scale: root.cellOn(index) && (root.indeterminate || index === root.filled - 1) ? 1.08 : 1
          Behavior on opacity { NumberAnimation { duration: 140 } }
          Behavior on scale { NumberAnimation { duration: 140 } }
        }
      }
    }

    Rectangle {
      id: sheen
      width: Math.max(24, track.width * 0.18)
      height: track.height
      visible: root.active
      color: Qt.rgba(1, 1, 1, 0.28)
      x: -width

      SequentialAnimation on x {
        running: root.active && track.width > 8
        loops: Animation.Infinite
        NumberAnimation {
          from: -sheen.width
          to: track.width
          duration: 1500
          easing.type: Easing.InOutSine
        }
        PauseAnimation { duration: 280 }
      }
    }
  }

  Text {
    width: parent.width
    visible: root.generating && root.steps > 0
    text: "Clip " + root.step + " / " + root.steps
    color: root.foreground
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.subtitle
    opacity: 0.55
  }
}
