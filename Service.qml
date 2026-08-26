import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null

  property string overrideMode: ""
  property bool locked: false
  property bool mediaPlaying: false
  property real keysPerSec: 0
  property string placement: "focus"
  property bool desktopVisible: true
  property real pinX: -1
  property real pinY: -1
  property var atlasSpec: null

  readonly property var atlas: Model.normalizeAtlas(root.atlasSpec)
  readonly property string mode: Model.resolveMode({
    override: root.overrideMode,
    locked: root.locked,
    mediaPlaying: root.mediaPlaying,
    keysPerSec: root.keysPerSec
  })
  readonly property bool followPointer: root.placement === "pointer"
  readonly property bool followFocus: root.placement === "focus"

  function setMode(mode) {
    var name = String(mode || "")
    if (!Model.isKnownMode(name)) return
    root.overrideMode = name
  }

  function clearOverride() {
    root.overrideMode = ""
  }

  function setFollow(enabled) {
    root.setPlacement(enabled)
  }

  function setPlacement(value) {
    root.placement = Model.normalizePlacement(value)
  }

  function setDesktopVisible(enabled) {
    root.desktopVisible = enabled === true || enabled === "true"
  }

  function pinHere() {
    root.placement = "pin"
    root.pinX = -1
    root.pinY = -1
  }

  function loadAtlas() {
    var xhr = new XMLHttpRequest()
    xhr.open("GET", Qt.resolvedUrl("atlas.json"), false)
    xhr.send()
    if (xhr.status !== 200 && xhr.status !== 0) return
    try {
      root.atlasSpec = JSON.parse(xhr.responseText)
    } catch (e) {
      root.atlasSpec = null
    }
  }

  Component.onCompleted: root.loadAtlas()

  IpcHandler {
    target: "higgsfield.pet"

    function setMode(mode: string): void { root.setMode(mode) }
    function clearOverride(): void { root.clearOverride() }
    function setFollow(enabled: string): void { root.setFollow(enabled) }
    function setPlacement(value: string): void { root.setPlacement(value) }
    function setDesktopVisible(enabled: string): void { root.setDesktopVisible(enabled) }
    function pinHere(): void { root.pinHere() }
  }
}
