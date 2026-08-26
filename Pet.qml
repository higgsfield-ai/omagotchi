import QtQuick
import Quickshell
import "Model.js" as Model

// Plays one row of atlas.png. Appearance is frozen until the atlas files change.
Item {
  id: root

  property string mode: "idle"
  property var atlas: Model.normalizeAtlas(null)
  property url source: Qt.resolvedUrl("atlas.png")
  property int displaySize: atlas.cell

  readonly property int frameWidth: atlas.cell
  readonly property int frameHeight: atlas.cell
  readonly property int frameCount: atlas.columns
  readonly property int frameRow: Model.rowForMode(mode, atlas)
  readonly property bool oneShot: Model.isOneShot(mode)

  signal finished()

  width: displaySize
  height: displaySize

  AnimatedSprite {
    id: sprite
    anchors.fill: parent
    source: root.source
    interpolate: false
    smooth: false
    frameX: 0
    frameY: root.frameRow * root.frameHeight
    frameWidth: root.frameWidth
    frameHeight: root.frameHeight
    frameCount: root.frameCount
    frameRate: root.atlas.fps
    loops: root.oneShot ? 1 : AnimatedSprite.Infinite
    running: true
    onFinished: root.finished()
  }

  onModeChanged: {
    sprite.currentFrame = 0
    sprite.running = true
  }

  onFrameRowChanged: {
    sprite.currentFrame = 0
    sprite.running = true
  }
}
