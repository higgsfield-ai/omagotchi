import QtQuick

// Pixel-art HF monogram, drawn as rectangles so it tints with the bar
// foreground and stays crisp at any scale — no image asset to key or theme.
Item {
  id: root

  property color color: "#ffffff"
  property int cell: 3

  readonly property var bitmap: [
    "X..X.XXXX",
    "X..X.X...",
    "XXXX.XXX.",
    "X..X.X...",
    "X..X.X..."
  ]
  readonly property int cols: bitmap[0].length

  implicitWidth: cols * cell
  implicitHeight: bitmap.length * cell

  Repeater {
    model: root.bitmap.length * root.cols

    Rectangle {
      required property int index
      readonly property int r: Math.floor(index / root.cols)
      readonly property int c: index % root.cols
      visible: root.bitmap[r].charAt(c) === "X"
      x: c * root.cell
      y: r * root.cell
      width: root.cell
      height: root.cell
      color: root.color
    }
  }
}
