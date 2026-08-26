import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import "Model.js" as Model

// Bar chip + host for the debug panel. Shell summon/hide/toggle require
// open/close/opened/toggle/closeForPopoutSwitch on this root (clock contract).
BarWidget {
  id: root
  moduleName: "higgsfield.pet"

  property string overrideMode: ""
  property bool locked: false
  property bool mediaPlaying: false
  property real keysPerSec: 0
  property bool followPointer: true
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

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  readonly property int petSize: {
    var slot = root.bar && root.bar.barSize ? root.bar.barSize : 28
    return Math.max(20, Math.round(slot - 8))
  }

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function setMode(mode) {
    var name = String(mode || "")
    if (!Model.isKnownMode(name)) return
    root.overrideMode = name
  }

  function clearOverride() {
    root.overrideMode = ""
  }

  function setFollow(enabled) {
    root.followPointer = enabled === true || enabled === "true"
  }

  function setDesktopVisible(enabled) {
    root.desktopVisible = enabled === true || enabled === "true"
  }

  function pinHere() {
    root.followPointer = false
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

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  Component.onCompleted: root.loadAtlas()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "higgsfield.pet"

    function setMode(mode: string): void { root.setMode(mode) }
    function clearOverride(): void { root.clearOverride() }
    function setFollow(enabled: string): void { root.setFollow(enabled) }
    function setDesktopVisible(enabled: string): void { root.setDesktopVisible(enabled) }
    function pinHere(): void { root.pinHere() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    tooltipText: "Higgsfield Pet — " + root.mode
    implicitWidth: root.petSize + 12
    implicitHeight: root.petSize + 4

    Pet {
      id: pet
      anchors.centerIn: parent
      displaySize: root.petSize
      atlas: root.atlas
      mode: root.mode
      onFinished: {
        if (Model.isOneShot(root.mode)) root.clearOverride()
      }
    }

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }

  DesktopPet {
    atlas: root.atlas
    mode: root.mode
    followPointer: root.followPointer
    desktopVisible: root.desktopVisible
    pinX: root.pinX
    pinY: root.pinY
    onDraggedTo: function(x, y) {
      root.followPointer = false
      root.pinX = x
      root.pinY = y
    }
  }
}
