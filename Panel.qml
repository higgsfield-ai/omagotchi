import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "higgsfield.signals"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property bool openedFromHotkey: false

  readonly property var barIdentity: hostWidget || root
  readonly property var svc: {
    if (root.bar && root.bar.shell && root.bar.shell.serviceFor)
      return root.bar.shell.serviceFor("higgsfield.signals")
    return null
  }
  readonly property bool generating: root.svc ? !!root.svc.generating : false
  readonly property string statusText: root.svc ? String(root.svc.generateStatus || "") : ""
  readonly property string resultPath: root.svc ? String(root.svc.lastResultPath || "") : ""
  readonly property bool showPreview: Model.isImagePath(root.resultPath)

  function open() {
    root.openedFromHotkey = false
    root.controller.show()
    Qt.callLater(function() {
      if (pathField) pathField.forceActiveFocus()
    })
  }

  function openFromHotkey() {
    root.openedFromHotkey = true
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened && root.bar && "centerHoverRevealSuppressed" in root.bar)
        root.bar.centerHoverRevealSuppressed = true
      if (pathField) pathField.forceActiveFocus()
    })
  }

  function close() {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = false
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function submit(smoke) {
    if (!root.svc || root.generating) return
    var imagePath = Model.trimPrompt(pathField.text)
    if (!imagePath) return
    root.svc.generateSprite(imagePath, notesField.text, smoke === true)
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: pathField
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: pathField.activeFocus || notesField.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(8)

        Text {
          width: parent.width
          text: "Sprite sheet"
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Text {
          width: parent.width
          text: "1 image → nano_banana_2 base + seedance_2_0_mini clips"
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          wrapMode: Text.WordWrap
          opacity: 0.7
        }

        TextField {
          id: pathField
          width: parent.width
          placeholderText: "~/Pictures/character.png"
          foreground: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              root.close()
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.submit(false)
              event.accepted = true
            }
          }
        }

        Rectangle {
          width: parent.width
          height: Style.space(56)
          radius: Math.min(6, Style.cornerRadius)
          color: Qt.rgba(0, 0, 0, 0.18)
          border.width: 1
          border.color: Qt.rgba(1, 1, 1, 0.08)

          Text {
            anchors.fill: notesField
            visible: notesField.text.length === 0
            text: "Optional notes (outfit, hair)…"
            color: root.barForeground
            opacity: 0.4
            font.family: notesField.font.family
            font.pixelSize: notesField.font.pixelSize
            wrapMode: Text.WordWrap
          }

          TextEdit {
            id: notesField
            anchors.fill: parent
            anchors.margins: Style.space(8)
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.subtitle
            text: ""
          }
        }

        Row {
          spacing: Style.space(8)

          WidgetButton {
            bar: root.bar
            text: root.generating ? "Working…" : "Generate sheet"
            tooltipText: "18 clips · several minutes · Higgsfield CLI"
            onPressed: function(buttonCode) {
              if (buttonCode === Qt.LeftButton) root.submit(false)
            }
          }

          WidgetButton {
            bar: root.bar
            text: "Walk test"
            tooltipText: "Base sprite + one walk clip only"
            onPressed: function(buttonCode) {
              if (buttonCode === Qt.LeftButton) root.submit(true)
            }
          }
        }

        Text {
          width: parent.width
          visible: root.statusText !== ""
          text: root.statusText
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          wrapMode: Text.WordWrap
          opacity: 0.85
        }

        Image {
          width: parent.width
          visible: root.showPreview
          source: root.showPreview ? ("file://" + root.resultPath) : ""
          fillMode: Image.PreserveAspectFit
          height: visible ? Style.space(120) : 0
          asynchronous: true
        }

        Text {
          width: parent.width
          visible: root.resultPath !== ""
          text: root.resultPath
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          wrapMode: Text.WrapAnywhere
          opacity: 0.7
        }
      }
    }
  }
}
