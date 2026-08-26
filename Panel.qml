import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "higgsfield.pet"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property var atlas: hostWidget && hostWidget.atlas
    ? hostWidget.atlas
    : Model.normalizeAtlas(null)
  readonly property string currentMode: hostWidget && hostWidget.mode
    ? hostWidget.mode
    : "idle"
  readonly property bool placeholder: atlas.placeholder === true

  function open() {
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function pickMode(mode) {
    if (root.hostWidget && typeof root.hostWidget.setMode === "function")
      root.hostWidget.setMode(mode)
  }

  function clearOverride() {
    if (root.hostWidget && typeof root.hostWidget.clearOverride === "function")
      root.hostWidget.clearOverride()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(280))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(8)

        Text {
          width: parent.width
          text: "Higgsfield Pet"
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Text {
          width: parent.width
          text: root.placeholder
            ? "Placeholder atlas — color rows, not a generated pet."
            : "Playing the saved atlas. Appearance is frozen until you customize."
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          wrapMode: Text.WordWrap
          opacity: 0.8
        }

        Text {
          width: parent.width
          text: "Now: " + root.currentMode
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
        }

        Pet {
          anchors.horizontalCenter: parent.horizontalCenter
          displaySize: 96
          atlas: root.atlas
          mode: root.currentMode
        }

        Flow {
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: Model.MODE_ORDER

            WidgetButton {
              required property string modelData
              bar: root.bar
              text: modelData
              tooltipText: "Play " + modelData
              onPressed: function(buttonCode) {
                if (buttonCode === Qt.LeftButton) root.pickMode(modelData)
              }
            }
          }
        }

        WidgetButton {
          bar: root.bar
          text: "Clear override"
          tooltipText: "Return to sensor-driven mode (idle until sensors exist)"
          onPressed: function(buttonCode) {
            if (buttonCode === Qt.LeftButton) root.clearOverride()
          }
        }

        WidgetButton {
          bar: root.bar
          text: root.hostWidget && root.hostWidget.followPointer ? "Following pointer" : "Follow pointer"
          tooltipText: "Sit next to the mouse. Click-through so typing still works."
          onPressed: function(buttonCode) {
            if (buttonCode === Qt.LeftButton && root.hostWidget)
              root.hostWidget.setFollow(true)
          }
        }

        WidgetButton {
          bar: root.bar
          text: "Pin on desktop"
          tooltipText: "Stop following. Drag the overlay pet to move it."
          onPressed: function(buttonCode) {
            if (buttonCode === Qt.LeftButton && root.hostWidget)
              root.hostWidget.pinHere()
          }
        }

        WidgetButton {
          bar: root.bar
          text: root.hostWidget && root.hostWidget.desktopVisible ? "Hide overlay pet" : "Show overlay pet"
          tooltipText: "Toggle the desktop overlay. The bar chip stays."
          onPressed: function(buttonCode) {
            if (buttonCode === Qt.LeftButton && root.hostWidget)
              root.hostWidget.setDesktopVisible(!(root.hostWidget.desktopVisible === true))
          }
        }

        Text {
          width: parent.width
          text: "IPC: omarchy-shell higgsfield.pet setFollow true"
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          wrapMode: Text.WordWrap
          opacity: 0.7
        }
      }
    }
  }
}
