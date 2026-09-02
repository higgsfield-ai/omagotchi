import QtQuick
import qs.Commons
import qs.Ui

// Bar chip that opens the generate panel. IPC stays on Service.qml —
// a second IpcHandler on higgsfield-omagotchi would go silent.
BarWidget {
  id: root
  moduleName: "higgsfield-omagotchi"

  readonly property var svc: root.bar && root.bar.shell && root.bar.shell.serviceFor
    ? root.bar.shell.serviceFor("higgsfield-omagotchi")
    : null

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false
  readonly property bool generating: root.svc ? !!root.svc.generating : false
  readonly property int genPercent: root.svc ? Number(root.svc.generatePercent || 0) : 0
  // Chip states: idle logo / pulsing logo (generating, no percent yet) /
  // percent text (generating with progress).
  readonly property bool showPercent: root.generating && root.genPercent > 0

  // The QML error that killed Panel.qml, surfaced on the chip tooltip so a
  // broken panel can be diagnosed with a hover instead of a journal dive.
  property string panelLoadError: ""

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey)
      panelLoader.item.openFromHotkey()
    else if (panelLoader.item)
      panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) {
      panelLoader.item.toggle()
      return
    }
    // A dead chip is the worst failure mode: say why, then try once more so
    // a transient load error does not leave HF mute until a shell restart.
    console.warn("higgsfield-omagotchi: HF click with no panel; loader status", panelLoader.status)
    if (panelLoader.status === Loader.Error) {
      panelLoader.active = false
      panelLoader.active = true
      if (panelLoader.item) panelLoader.item.toggle()
    }
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
    onStatusChanged: {
      if (status === Loader.Ready) {
        root.panelLoadError = ""
        return
      }
      if (status !== Loader.Error) return
      var detail = ""
      try {
        if (panelLoader.errorString) detail = String(panelLoader.errorString())
        if (!detail && panelLoader.sourceComponent && panelLoader.sourceComponent.errorString)
          detail = String(panelLoader.sourceComponent.errorString())
      } catch (e) {}
      root.panelLoadError = (detail || "unknown error").substring(0, 300)
      console.warn("higgsfield-omagotchi: Panel.qml failed to load:", detail)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    z: 1
    bar: root.bar
    text: root.showPercent ? (root.genPercent + "%") : ""
    hasVisualContent: true
    fixedWidth: root.showPercent ? -1 : Math.round(chipLogo.implicitWidth * chipLogo.scale) + 17

    // Sized and tinted like the native status icons (wifi, bluetooth):
    // foreground color, icon-font height, solid strokes instead of fat dots.
    HfLogo {
      id: chipLogo
      anchors.centerIn: parent
      visible: !root.showPercent
      cell: 1
      dotInset: 0
      color: button.foreground
      scale: Style.font.icon / chipLogo.implicitHeight

      SequentialAnimation on opacity {
        running: root.generating && !root.showPercent
        loops: Animation.Infinite
        NumberAnimation { to: 0.25; duration: 650; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
        onStopped: chipLogo.opacity = 1
      }
    }
    tooltipText: {
      if (panelLoader.status === Loader.Error)
        return "Panel failed: " + (root.panelLoadError || "unknown error")
      if (root.generating)
        return root.svc && root.svc.generateStatus ? String(root.svc.generateStatus) : "Generating avatar…"
      return "Higgsfield Omagotchi"
    }

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }
}
