import QtQuick

// The Higgsfield mark as a pixel dot-grid, decoded from the CLI's braille
// banner and drawn as rectangles — crisp at any scale, no image asset to
// key or theme. Default color is the brand lime the CLI prints it in.
Item {
  id: root

  property color color: "#d1fe17"
  property int cell: 2
  // Fraction of each cell left as gap, so the dots read as a matrix like
  // the terminal banner instead of fusing into solid strokes.
  property real dotInset: 0.25

  readonly property var bitmap: [
    ".....XXXX...........",
    "...XXXXXXX..........",
    "..XXXX.XXX..........",
    "XXXXX..XXX..........",
    "XXXX...XXX..XXXX....",
    "XXX...XXX..XXXXXX...",
    "....XXXX..XXXXXXXX..",
    "...XXXX..XXXX..XXX..",
    "..XXXX...XXX....XX..",
    "..XXX...XXX.....XXXX",
    ".XXX...XXX....XXXXXX",
    ".XXXX.XXX....XXXXXXX",
    ".XXXXXXXX...XXXXXXX.",
    "..XXXXXX...XXX..XX..",
    "...XXXX...XXX...XX..",
    "..........XXX..XXX..",
    "..........XXX..XXX..",
    "..........XXXXXXX...",
    "..........XXXXXXX...",
    "...........XXXX....."
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
      width: Math.max(1, root.cell * (1 - root.dotInset))
      height: Math.max(1, root.cell * (1 - root.dotInset))
      color: root.color
    }
  }
}
