import QtQuick
import qs.Commons

Column {
  id: stat
  property string label: ""
  property real value: 0
  property color foreground: "#ffffff"
  property string fontFamily: Style.font.family
  spacing: Style.space(3)

  Item {
    width: parent.width
    height: nameLabel.implicitHeight

    Text {
      id: nameLabel
      anchors.left: parent.left
      text: stat.label
      color: stat.foreground
      font.family: stat.fontFamily
      font.pixelSize: Style.font.subtitle
      opacity: 0.8
    }

    Text {
      anchors.right: parent.right
      text: Math.round(Math.max(0, Math.min(100, stat.value))) + "%"
      color: stat.foreground
      font.family: stat.fontFamily
      font.pixelSize: Style.font.subtitle
      opacity: 0.7
    }
  }

  Rectangle {
    width: parent.width
    height: 8
    radius: 4
    color: Qt.rgba(1, 1, 1, 0.12)

    Rectangle {
      width: Math.max(0, Math.min(1, stat.value / 100)) * parent.width
      height: parent.height
      radius: parent.radius
      color: stat.foreground
      opacity: 0.85
      Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
    }
  }
}
