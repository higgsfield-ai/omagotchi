import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "higgsfield.pet"

  readonly property var petService: root.bar && root.bar.shell && root.bar.shell.serviceFor
    ? root.bar.shell.serviceFor("higgsfield.pet")
    : null

  readonly property var atlas: petService ? petService.atlas : Model.normalizeAtlas(null)
  readonly property string mode: petService ? petService.mode : "idle"
  readonly property string placement: petService ? petService.placement : "focus"
  readonly property bool followPointer: petService ? petService.followPointer : false
  readonly property bool followFocus: petService ? petService.followFocus : true
  readonly property bool desktopVisible: petService ? petService.desktopVisible : true

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
    if (root.petService) root.petService.setMode(mode)
  }

  function clearOverride() {
    if (root.petService) root.petService.clearOverride()
  }

  function setFollow(enabled) {
    if (root.petService) root.petService.setFollow(enabled)
  }

  function setPlacement(value) {
    if (root.petService) root.petService.setPlacement(value)
  }

  function setDesktopVisible(enabled) {
    if (root.petService) root.petService.setDesktopVisible(enabled)
  }

  function pinHere() {
    if (root.petService) root.petService.pinHere()
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
    target: "higgsfield.pet.bar"

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
}
