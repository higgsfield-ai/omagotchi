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
  property bool replaceAvatar: false

  readonly property var barIdentity: hostWidget || root
  readonly property var svc: root.bar && root.bar.shell && root.bar.shell.serviceFor
    ? root.bar.shell.serviceFor("higgsfield.signals")
    : null
  readonly property bool generating: root.svc ? !!root.svc.generating : false
  readonly property bool picking: root.svc ? !!root.svc.picking : false
  readonly property bool capturing: root.svc ? !!root.svc.capturing : false
  readonly property int photoRev: root.svc ? Number(root.svc.photoRev || 0) : 0
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
  readonly property bool hasGeneratedPet: {
    if (!root.svc) return false
    if (root.svc.hasGeneratedPet) return true
    var path = String(root.svc.lastResultPath || "")
    return path.charAt(0) === "/"
  }
  readonly property bool showGenerate: !root.hasGeneratedPet || root.replaceAvatar || root.generating || root.loggingIn || root.lastError !== ""
  readonly property real hunger: root.svc ? Number(root.svc.careHunger) : 0
  readonly property real hygiene: root.svc ? Number(root.svc.careHygiene) : 0
  readonly property real mood: root.svc ? Number(root.svc.careMood) : 0
  readonly property real energy: root.svc ? Number(root.svc.careEnergy) : 0
  readonly property real health: root.svc ? Number(root.svc.careHealth) : 0
  readonly property real attention: root.svc ? Number(root.svc.careAttention) : 0
  readonly property real excitement: root.svc ? Number(root.svc.careExcitement) : 0
  readonly property real focus: root.svc ? Number(root.svc.careFocus) : 0
  readonly property real music: root.svc ? Number(root.svc.careMusic) : 0
  readonly property real bond: root.svc ? Number(root.svc.careBond) : 0
  readonly property real weight: root.svc ? Number(root.svc.careWeight) : 50
  readonly property string ageText: root.svc
    ? Model.ageLabel(root.svc.careBornMs, root.svc.nowMs || Date.now())
    : "newborn"
  readonly property bool petDocked: root.svc ? !!root.svc.petDocked : false
  readonly property bool petRecalling: root.svc ? !!root.svc.petRecalling : false
  readonly property bool petReleasing: root.svc ? !!root.svc.petReleasing : false
  readonly property var atlas: root.svc && root.svc.atlas
    ? root.svc.atlas
    : Model.normalizeAtlas(null)
  readonly property string nestMode: Model.nestMode(root.svc ? String(root.svc.mode || "idle") : "idle")
  readonly property var nestFrames: Model.framesForMode(root.atlas, root.nestMode)
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  onHasGeneratedPetChanged: {
    if (root.hasGeneratedPet && !root.generating) root.replaceAvatar = false
  }

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

  function takePhoto() {
    if (!root.loggedIn) {
      if (root.svc) root.svc.login()
      return
    }
    if (root.svc && typeof root.svc.captureWebcam === "function")
      root.svc.captureWebcam()
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
    contentHeight: panel.fittedContentHeight(Math.min(
      Math.max(content.implicitHeight, Style.space(180)),
      Style.space(520)
    ))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
          id: content
          width: flick.width
          spacing: Style.space(10)

          Text {
            width: parent.width
            text: "Tamagotchi"
            color: root.barForeground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Column {
            width: parent.width
            visible: root.hasGeneratedPet
            spacing: Style.space(8)
            height: visible ? implicitHeight : 0

            Rectangle {
              id: nest
              width: parent.width
              height: Style.space(112)
              radius: Math.min(8, Style.cornerRadius)
              color: Qt.rgba(0, 0, 0, 0.18)
              border.width: 1
              border.color: Qt.rgba(1, 1, 1, 0.1)
              clip: true
              property int nestFrame: 0
              property real nestLift: 0
              property real nestFade: 1
              property string modeKey: root.nestMode
              onModeKeyChanged: nest.nestFrame = 0

              Connections {
                target: root.svc
                function onPetDockedChanged() {
                  if (root.petDocked && !root.petReleasing) {
                    nest.nestLift = -30
                    nest.nestFade = 0
                    nestEnterAnim.restart()
                  }
                }
              }

              ParallelAnimation {
                id: nestEnterAnim
                NumberAnimation {
                  target: nest
                  property: "nestLift"
                  to: 0
                  duration: 440
                  easing.type: Easing.OutCubic
                }
                NumberAnimation {
                  target: nest
                  property: "nestFade"
                  to: 1
                  duration: 280
                  easing.type: Easing.OutQuad
                }
              }

              ParallelAnimation {
                id: nestExitAnim
                NumberAnimation {
                  target: nest
                  property: "nestLift"
                  to: -40
                  duration: 380
                  easing.type: Easing.InCubic
                }
                NumberAnimation {
                  target: nest
                  property: "nestFade"
                  to: 0
                  duration: 320
                  easing.type: Easing.InQuad
                }
                onFinished: {
                  if (root.svc && typeof root.svc.releasePet === "function")
                    root.svc.releasePet()
                }
              }

              Text {
                anchors.centerIn: parent
                width: parent.width - Style.space(16)
                horizontalAlignment: Text.AlignHCenter
                visible: nest.nestFade < 0.15 || !root.petDocked
                text: root.petRecalling
                  ? "Coming home…"
                  : (root.petReleasing ? "Heading out…" : "On the desktop")
                color: root.barForeground
                opacity: 0.55
                wrapMode: Text.WordWrap
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
              }

              Item {
                id: nestPet
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round((nest.height - nestPet.height) / 2 + nest.nestLift)
                width: root.nestFrames.displayWidth
                height: root.nestFrames.displayHeight
                opacity: root.petDocked ? nest.nestFade : 0
                visible: opacity > 0.02

                Image {
                  anchors.fill: parent
                  source: {
                    var abs = Model.atlasImageSource(root.atlas.file)
                    var src = abs.indexOf("file://") === 0 ? abs : Qt.resolvedUrl(root.atlas.file)
                    var rev = root.svc ? Number(root.svc.atlasRev || 0) : 0
                    return src + "?r=" + rev
                  }
                  sourceClipRect: Qt.rect(
                    root.nestFrames.frameX + nest.nestFrame * root.nestFrames.frameWidth,
                    root.nestFrames.frameY,
                    root.nestFrames.frameWidth,
                    root.nestFrames.frameHeight
                  )
                  fillMode: Image.Stretch
                  smooth: false
                  mipmap: false
                  asynchronous: false
                  cache: false
                }
              }

              Timer {
                interval: {
                  if (root.nestMode === "happy") return 110
                  if (root.nestMode === "eat" || root.nestMode === "wash") return 140
                  if (root.nestMode === "night" || root.nestMode === "sleep") return 220
                  if (root.nestMode === "grumpy" || root.nestMode === "sick") return 160
                  return 180
                }
                running: nestPet.visible
                repeat: true
                onTriggered: nest.nestFrame = (nest.nestFrame + 1) % Math.max(1, root.nestFrames.frameCount)
              }
            }

            WidgetButton {
              bar: root.bar
              text: root.petDocked || root.petRecalling ? "Release to desktop" : "Hide in panel"
              tooltipText: root.petDocked
                ? "Drop the pet onto the focused window"
                : "Levitate the pet back into this panel"
              onPressed: function(buttonCode) {
                if (buttonCode !== Qt.LeftButton) return
                if (!root.svc) return
                if (root.petRecalling || root.petReleasing || nestExitAnim.running) return
                if (root.petDocked) {
                  nest.nestLift = 0
                  nest.nestFade = 1
                  nestExitAnim.restart()
                  return
                }
                root.svc.recallPet()
              }
            }

            CareStatRow {
              width: parent.width
              label: "Hunger"
              value: root.hunger
              foreground: root.barForeground
              fontFamily: root.fontFamily
            }

            CareStatRow {
              width: parent.width
              label: "Hygiene"
              value: root.hygiene
              foreground: root.barForeground
              fontFamily: root.fontFamily
            }

            CareStatRow {
              width: parent.width
              label: "Mood"
              value: root.mood
              foreground: root.barForeground
              fontFamily: root.fontFamily
            }

            WidgetButton {
              bar: root.bar
              text: "Feed"
              tooltipText: "Feed the pet"
              onPressed: function(buttonCode) {
                if (buttonCode !== Qt.LeftButton) return
                if (root.svc && typeof root.svc.feedPet === "function") root.svc.feedPet()
              }
            }

            WidgetButton {
              bar: root.bar
              text: "Wash"
              tooltipText: "Wash the pet"
              onPressed: function(buttonCode) {
                if (buttonCode !== Qt.LeftButton) return
                if (root.svc && typeof root.svc.washPet === "function") root.svc.washPet()
              }
            }

            WidgetButton {
              bar: root.bar
              text: "Play"
              tooltipText: "Play with the pet"
              onPressed: function(buttonCode) {
                if (buttonCode !== Qt.LeftButton) return
                if (root.svc && typeof root.svc.playPet === "function") root.svc.playPet()
              }
            }

            Text {
              width: parent.width
              text: "Wellbeing"
              color: root.barForeground
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }

            CareStatRow {
              width: parent.width
              label: "Energy"
              value: root.energy
              foreground: root.barForeground
              fontFamily: root.fontFamily
            }

            CareStatRow {
              width: parent.width
              label: "Health"
              value: root.health
              foreground: root.barForeground
              fontFamily: root.fontFamily
            }

            CareStatRow {
              width: parent.width
              label: "Attention"
              value: root.attention
              foreground: root.barForeground
              fontFamily: root.fontFamily
            }

            CareStatRow {
              width: parent.width
              label: "Excitement"
              value: root.excitement
              foreground: root.barForeground
              fontFamily: root.fontFamily
            }

            CareStatRow {
              width: parent.width
              label: "Focus"
              value: root.focus
              foreground: root.barForeground
              fontFamily: root.fontFamily
            }

            CareStatRow {
              width: parent.width
              label: "Music"
              value: root.music
              foreground: root.barForeground
              fontFamily: root.fontFamily
            }

            CareStatRow {
              width: parent.width
              label: "Bond"
              value: root.bond
              foreground: root.barForeground
              fontFamily: root.fontFamily
            }

            CareStatRow {
              width: parent.width
              label: "Weight"
              value: root.weight
              foreground: root.barForeground
              fontFamily: root.fontFamily
            }

            Text {
              width: parent.width
              text: "Age  " + root.ageText
              color: root.barForeground
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              opacity: 0.75
            }

            WidgetButton {
              bar: root.bar
              visible: !root.showGenerate
              text: "Replace avatar"
              tooltipText: "Pick a new photo and generate again"
              onPressed: function(buttonCode) {
                if (buttonCode !== Qt.LeftButton) return
                root.replaceAvatar = true
              }
            }
          }

          Text {
            width: parent.width
            visible: root.showGenerate
            text: root.loggedIn
              ? "Take a webcam photo or upload one, then generate. The new pet replaces the one on your desktop."
              : "Log in to Higgsfield to unlock photo capture and Generate my avatar."
            color: root.barForeground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            wrapMode: Text.WordWrap
            opacity: 0.75
          }

          Rectangle {
            width: parent.width
            height: Style.space(132)
            visible: root.showGenerate
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
              source: root.hasPhoto ? ("file://" + root.photoPath + "?r=" + root.photoRev) : ""
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
              visible: !root.hasPhoto || !root.loggedIn || root.capturing
              width: parent.width - Style.space(16)
              horizontalAlignment: Text.AlignHCenter
              text: !root.loggedIn
                ? "Photo capture unlocks after login"
                : (root.capturing
                  ? "Smile…"
                  : (root.picking ? "Opening picker…" : "Click to choose a photo, or Take photo"))
              color: root.barForeground
              opacity: 0.55
              wrapMode: Text.WordWrap
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
            }

            MouseArea {
              anchors.fill: parent
              z: 2
              cursorShape: root.loggedIn ? Qt.PointingHandCursor : Qt.ArrowCursor
              enabled: root.loggedIn && !root.generating && !root.capturing
              onClicked: root.choosePhoto()
            }
          }

          Text {
            width: parent.width
            visible: root.showGenerate && root.loggedIn && root.hasPhoto
            text: root.photoName
            color: root.barForeground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            elide: Text.ElideMiddle
            opacity: 0.7
          }

          WidgetButton {
            bar: root.bar
            visible: root.showGenerate && root.loggedIn && !root.generating && !root.loggingIn
            text: root.capturing ? "Capturing…" : "Take photo"
            tooltipText: "Capture a still from the webcam"
            onPressed: function(buttonCode) {
              if (buttonCode !== Qt.LeftButton) return
              root.takePhoto()
            }
          }

          WidgetButton {
            bar: root.bar
            visible: root.showGenerate && (root.lastError === "" || root.generating || root.loggingIn)
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
            height: visible ? implicitHeight : 0

            Text {
              width: parent.width
              visible: root.generateError.message !== ""
              text: root.generateError.message
              color: root.barForeground
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              wrapMode: Text.WordWrap
              opacity: 0.9
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
}
