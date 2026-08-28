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
  readonly property bool picking: root.svc ? !!root.svc.picking : false
  readonly property bool loggedIn: root.svc ? !!root.svc.loggedIn : false
  readonly property bool loggingIn: root.svc ? !!root.svc.loggingIn : false
  readonly property bool runtimeReady: root.svc ? !!root.svc.runtimeReady : false
  readonly property string photoPath: root.svc ? String(root.svc.photoPath || "") : ""
  readonly property string photoName: root.svc ? String(root.svc.photoName || "") : ""
  readonly property bool hasPhoto: Model.isImagePath(root.photoPath)
  readonly property string statusText: root.svc ? String(root.svc.generateStatus || "") : ""
  readonly property int percent: root.svc ? Number(root.svc.generatePercent || 0) : 0
  readonly property int step: root.svc ? Number(root.svc.generateStep || 0) : 0
  readonly property int steps: root.svc ? Number(root.svc.generateSteps || 0) : 0
  readonly property string lastError: root.svc ? String(root.svc.lastError || "") : ""
  readonly property var generateError: Model.classifyGenerateError(root.lastError)
  readonly property string generateLog: root.svc ? String(root.svc.generateLog || "") : ""
  readonly property bool canGenerate: root.loggedIn && root.hasPhoto && !root.generating && !root.loggingIn

  function open() {
    root.openedFromHotkey = false
    root.controller.show()
    if (root.svc && typeof root.svc.checkAuth === "function") root.svc.checkAuth()
  }

  function openFromHotkey() {
    root.openedFromHotkey = true
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened && root.bar && "centerHoverRevealSuppressed" in root.bar)
        root.bar.centerHoverRevealSuppressed = true
    })
    if (root.svc && typeof root.svc.checkAuth === "function") root.svc.checkAuth()
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

  function choosePhoto() {
    if (!root.loggedIn) {
      if (root.svc) root.svc.login()
      return
    }
    if (root.svc && typeof root.svc.pickPhoto === "function") {
      root.svc.pickPhoto()
      return
    }
    var dlg = photoDialogLoader.item
    if (dlg && typeof dlg.open === "function") dlg.open()
  }

  function onDialogPicked(path) {
    if (root.svc && typeof root.svc.setPhoto === "function") root.svc.setPhoto(path)
  }

  Loader {
    id: photoDialogLoader
    source: Qt.resolvedUrl("PhotoDialog.qml")
    onStatusChanged: {
      if (status === Loader.Error && String(source).indexOf("PhotoDialogNative.qml") === -1)
        source = Qt.resolvedUrl("PhotoDialogNative.qml")
    }
  }

  Connections {
    target: photoDialogLoader.item
    function onPicked(path) { root.onDialogPicked(path) }
  }

  function submitAvatar() {
    if (!root.svc || root.generating || root.loggingIn) return
    if (!root.loggedIn) {
      root.svc.login()
      return
    }
    if (!root.hasPhoto) {
      root.choosePhoto()
      return
    }
    root.svc.generateSprite(root.photoPath, "", false)
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(10)

        Text {
          width: parent.width
          text: "Tamagotchi"
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Text {
          width: parent.width
          text: root.loggedIn
            ? "Upload a photo, then generate. The new pet replaces the one on your desktop."
            : "Log in to Higgsfield to unlock photo upload and Generate my avatar."
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          wrapMode: Text.WordWrap
          opacity: 0.75
        }

        Rectangle {
          width: parent.width
          height: Style.space(132)
          radius: Math.min(8, Style.cornerRadius)
          opacity: root.loggedIn ? 1 : 0.45
          color: Qt.rgba(0, 0, 0, 0.18)
          border.width: 1
          border.color: Qt.rgba(1, 1, 1, 0.1)
          clip: true

          Image {
            anchors.fill: parent
            anchors.margins: Style.space(6)
            visible: root.loggedIn && root.hasPhoto
            source: root.hasPhoto ? ("file://" + root.photoPath) : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            opacity: root.generating ? 0.72 : 1
            Behavior on opacity { NumberAnimation { duration: 240 } }
          }

          Rectangle {
            visible: root.generating && root.hasPhoto
            z: 1
            width: parent.width
            height: 10
            color: Qt.rgba(1, 1, 1, 0.22)

            SequentialAnimation on y {
              running: root.generating && root.hasPhoto
              loops: Animation.Infinite
              NumberAnimation {
                from: -12
                to: Style.space(132)
                duration: 1600
                easing.type: Easing.InOutSine
              }
            }
          }

          Text {
            anchors.centerIn: parent
            visible: !root.hasPhoto || !root.loggedIn
            width: parent.width - Style.space(16)
            horizontalAlignment: Text.AlignHCenter
            text: !root.loggedIn
              ? "Photo upload unlocks after login"
              : (root.picking ? "Opening picker…" : "Click to choose a photo")
            color: root.barForeground
            opacity: 0.55
            wrapMode: Text.WordWrap
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.subtitle
          }

          MouseArea {
            anchors.fill: parent
            z: 2
            cursorShape: root.loggedIn ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: root.loggedIn && !root.generating
            onClicked: root.choosePhoto()
          }
        }

        Text {
          width: parent.width
          visible: root.loggedIn && root.hasPhoto
          text: root.photoName
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          elide: Text.ElideMiddle
          opacity: 0.7
        }

        WidgetButton {
          bar: root.bar
          visible: root.lastError === "" || root.generating || root.loggingIn
          text: {
            if (root.loggingIn) return "Waiting for browser…"
            if (root.generating) return "Generating…"
            if (!root.loggedIn) return "Generate my avatar"
            return "Generate my avatar"
          }
          tooltipText: !root.loggedIn
            ? "Opens the Higgsfield login browser"
            : (root.hasPhoto ? "Build the sheet and replace the desktop pet" : "Choose a photo first")
          onPressed: function(buttonCode) {
            if (buttonCode !== Qt.LeftButton) return
            root.submitAvatar()
          }
        }

        Column {
          width: parent.width
          visible: root.lastError !== "" && !root.generating
          spacing: Style.space(8)

          Text {
            width: parent.width
            visible: !!root.generateError.showTitle
            text: root.generateError.title
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            visible: root.generateError.message !== "" && root.generateError.message !== root.generateError.title
            text: root.generateError.message
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.subtitle
            wrapMode: Text.WordWrap
            opacity: 0.85
          }

          Text {
            width: parent.width
            visible: root.generateLog !== ""
            text: "Log: " + root.generateLog
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.subtitle
            wrapMode: Text.WrapAnywhere
            opacity: 0.5
          }

          WidgetButton {
            bar: root.bar
            text: "Retry"
            tooltipText: root.hasPhoto ? "Run generate again with the same photo" : "Choose a photo, then retry"
            onPressed: function(buttonCode) {
              if (buttonCode !== Qt.LeftButton) return
              if (root.svc && typeof root.svc.retryGenerate === "function")
                root.svc.retryGenerate()
              else
                root.submitAvatar()
            }
          }

          WidgetButton {
            bar: root.bar
            visible: !!root.generateError.showUpgrade
            text: "Upgrade plan"
            tooltipText: "Open Higgsfield pricing"
            onPressed: function(buttonCode) {
              if (buttonCode !== Qt.LeftButton) return
              Qt.openUrlExternally(root.generateError.pricingUrl)
            }
          }
        }

        GenerateProgress {
          width: parent.width
          visible: (root.generating || root.loggingIn) && root.lastError === ""
          bar: root.bar
          foreground: root.barForeground
          generating: root.generating
          loggingIn: root.loggingIn
          percent: root.percent
          step: root.step
          steps: root.steps
          statusText: root.statusText
        }
      }
    }
  }
}
