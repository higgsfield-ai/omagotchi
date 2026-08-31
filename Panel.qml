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
  readonly property bool hasCustomAvatar: {
    if (!root.svc) return false
    if (root.svc.hasCustomAvatar) return true
    var path = String(root.svc.lastResultPath || "")
    return path.charAt(0) === "/"
  }
  readonly property bool showGenerate: root.replaceAvatar || root.generating || root.loggingIn || root.lastError !== ""
  readonly property real hunger: root.svc ? Number(root.svc.careHunger) : 0
  readonly property real hygiene: root.svc ? Number(root.svc.careHygiene) : 0
  readonly property real mood: root.svc ? Number(root.svc.careMood) : 0
  readonly property real energy: root.svc ? Number(root.svc.careEnergy) : 0
  readonly property real health: root.svc ? Number(root.svc.careHealth) : 0
  readonly property real attention: root.svc ? Number(root.svc.careAttention) : 0
  readonly property real bond: root.svc ? Number(root.svc.careBond) : 0
  readonly property real weight: root.svc ? Number(root.svc.careWeight) : 50
  readonly property bool petDocked: root.svc ? !!root.svc.petDocked : false
  readonly property bool petRecalling: root.svc ? !!root.svc.petRecalling : false
  readonly property bool petReleasing: root.svc ? !!root.svc.petReleasing : false
  readonly property var atlas: root.svc && root.svc.atlas
    ? root.svc.atlas
    : Model.normalizeAtlas(null)
  readonly property string nestMode: Model.nestMode(root.svc ? String(root.svc.mode || "idle") : "idle")
  readonly property var nestFrames: Model.framesForMode(root.atlas, root.nestMode)
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property color errorColor: "#ef5350"
  // Brand lime, matching HfLogo's default; popup background doubles as the
  // dark text color on filled buttons.
  readonly property color limeColor: "#d1fe17"
  readonly property color darkText: Color.popups.background
  readonly property bool mediaBusy: root.svc ? !!root.svc.mediaBusy : false
  readonly property string mediaStatus: root.svc ? String(root.svc.mediaStatus || "") : ""
  readonly property string mediaError: root.svc ? String(root.svc.mediaError || "") : ""
  readonly property string mediaRef: root.svc ? String(root.svc.mediaRefPath || "") : ""
  readonly property string lastMedia: root.svc ? String(root.svc.lastMediaPath || "") : ""
  readonly property int lastMediaRev: root.svc ? Number(root.svc.lastMediaRev || 0) : 0
  readonly property int credits: root.svc ? Number(root.svc.credits) : -1

  onGeneratingChanged: {
    if (!root.generating && root.lastError === "") root.replaceAvatar = false
  }

  onHasCustomAvatarChanged: {
    if (root.hasCustomAvatar && !root.generating) root.replaceAvatar = false
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

  function onDialogPicked(path) {
    if (root.svc && typeof root.svc.setPhoto === "function") root.svc.setPhoto(path)
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
      blocked: promptField.activeFocus
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

          Row {
            width: parent.width
            spacing: Style.space(8)

            HfLogo {
              anchors.verticalCenter: parent.verticalCenter
              cell: 2
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Tamagotchi"
              color: root.barForeground
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(8)

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

              WidgetButton {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Style.space(4)
                z: 3
                bar: root.bar
                fontSize: Style.font.caption
                text: root.generating || root.replaceAvatar ? "Cancel" : "Change avatar"
                tooltipText: root.generating
                  ? "Stop this generation"
                  : (root.replaceAvatar ? "Keep the current avatar" : "Pick a new photo and generate again")
                onPressed: function(buttonCode) {
                  if (buttonCode !== Qt.LeftButton) return
                  if (root.generating) {
                    if (root.svc && typeof root.svc.cancelGenerate === "function")
                      root.svc.cancelGenerate()
                    root.replaceAvatar = false
                    return
                  }
                  if (root.replaceAvatar) {
                    root.replaceAvatar = false
                    return
                  }
                  root.replaceAvatar = true
                  if (root.svc && typeof root.svc.checkAuth === "function") root.svc.checkAuth()
                }
              }

              Image {
                anchors.fill: parent
                anchors.margins: Style.space(6)
                z: 1
                visible: (root.replaceAvatar || root.generating) && root.hasPhoto
                source: root.hasPhoto ? ("file://" + root.photoPath + "?r=" + root.photoRev) : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                opacity: root.generating ? 0.72 : 1
              }

              MouseArea {
                anchors.fill: parent
                z: 2
                visible: root.replaceAvatar && !root.generating
                cursorShape: Qt.PointingHandCursor
                enabled: !root.capturing
                onClicked: root.choosePhoto()
              }

              WidgetButton {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: Style.space(4)
                z: 3
                bar: root.bar
                fontSize: Style.font.caption
                visible: !root.replaceAvatar && !root.generating
                text: root.petDocked || root.petRecalling ? "Release" : "Return to home"
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
                visible: (root.replaceAvatar && !root.hasPhoto && !root.generating)
                  || (!root.replaceAvatar && !root.generating && (nest.nestFade < 0.15 || !root.petDocked))
                text: {
                  if (root.replaceAvatar && !root.hasPhoto) {
                    if (!root.loggedIn) return "Log in to Higgsfield to unlock photo capture"
                    return root.capturing ? "Smile…" : (root.picking ? "Opening picker…" : "Click to choose a photo, or Take photo")
                  }
                  if (root.petRecalling) return "Coming home…"
                  return root.petReleasing ? "Heading out…" : "On the desktop"
                }
                color: root.barForeground
                opacity: 0.55
                wrapMode: Text.WordWrap
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
              }

              Item {
                id: nestPet
                anchors.horizontalCenter: parent.horizontalCenter
                // Floor-anchored like the desktop, so lying poses rest on
                // the island instead of hovering mid-air.
                y: Math.round(nest.height - nestPet.height - Style.space(6) + nest.nestLift)
                width: root.nestFrames.displayWidth
                height: root.nestFrames.displayHeight
                opacity: ((root.replaceAvatar || root.generating) && root.hasPhoto)
                  ? 0 : (root.petDocked ? nest.nestFade : 0)
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
                  if (root.nestMode === "sleep") return 220
                  if (root.nestMode === "grumpy" || root.nestMode === "sick") return 160
                  return 180
                }
                running: nestPet.visible
                repeat: true
                onTriggered: nest.nestFrame = (nest.nestFrame + 1) % Math.max(1, root.nestFrames.frameCount)
              }
            }

            Row {
              spacing: Style.space(8)
              visible: root.showGenerate

              ChipButton {
                visible: root.loggedIn && !root.generating && !root.loggingIn
                outlined: false
                text: root.capturing ? "Capturing…" : "Take photo"
                tooltipText: "Capture a still from the webcam"
                onChipPressed: function(buttonCode) {
                  if (buttonCode !== Qt.LeftButton) return
                  root.takePhoto()
                }
              }

              ChipButton {
                fill: root.limeColor
                textColor: root.darkText
                text: {
                  if (root.loggingIn) return "Waiting for browser…"
                  if (root.generating) return "Generating…"
                  if (root.lastError !== "") return "Retry"
                  return "Generate my avatar"
                }
                tooltipText: {
                  if (root.lastError !== "") return "Run the whole flow again from the base sprite"
                  if (!root.loggedIn) return "Opens the Higgsfield login browser"
                  return root.hasPhoto ? "Build the sheet and replace the desktop pet" : "Choose a photo first"
                }
                onChipPressed: function(buttonCode) {
                  if (buttonCode !== Qt.LeftButton) return
                  if (root.generating) return
                  if (root.lastError !== "") {
                    if (root.svc && typeof root.svc.retryGenerate === "function") root.svc.retryGenerate()
                    else root.submitAvatar()
                    return
                  }
                  root.submitAvatar()
                }
              }
            }

            Text {
              width: parent.width
              visible: root.lastError !== "" && !root.generating && root.generateError.message !== ""
              text: root.generateError.message
              color: root.errorColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              wrapMode: Text.WordWrap
              opacity: 0.9
            }

            Row {
              spacing: Style.space(8)
              visible: root.lastError !== "" && !root.generating && !!root.generateError.showUpgrade

              ChipButton {
                visible: !!root.generateError.showUpgrade
                text: "Upgrade plan"
                tooltipText: "Open Higgsfield pricing"
                onChipPressed: function(buttonCode) {
                  if (buttonCode !== Qt.LeftButton) return
                  Qt.openUrlExternally(root.generateError.pricingUrl)
                }
              }
            }

            Row {
              spacing: Style.space(8)

              Repeater {
                model: [
                  { label: "Feed", tip: "Feed the pet", act: "feedPet" },
                  { label: "Wash", tip: "Wash the pet", act: "washPet" },
                  { label: "Play", tip: "Play with the pet", act: "playPet" }
                ]

                ChipButton {
                  required property var modelData
                  text: modelData.label
                  tooltipText: modelData.tip
                  onChipPressed: function(buttonCode) {
                    if (buttonCode !== Qt.LeftButton) return
                    if (root.svc && typeof root.svc[modelData.act] === "function")
                      root.svc[modelData.act]()
                  }
                }
              }
            }

            Text {
              width: parent.width
              text: "Activity"
              color: root.barForeground
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }

            Row {
              spacing: Style.space(8)

              Repeater {
                model: [
                  { label: "Stand", value: "standing" },
                  { label: "Walk", value: "walking" },
                  { label: "Run", value: "running" }
                ]

                ChipButton {
                  required property var modelData
                  text: modelData.label
                  selected: root.svc && String(root.svc.petActivity) === modelData.value
                  onChipPressed: function(buttonCode) {
                    if (buttonCode !== Qt.LeftButton) return
                    if (root.svc && typeof root.svc.setActivity === "function")
                      root.svc.setActivity(modelData.value)
                  }
                }
              }
            }

            Grid {
              id: statGrid
              width: parent.width
              columns: 2
              columnSpacing: Style.space(12)
              rowSpacing: Style.space(6)
              readonly property real cellWidth: (width - columnSpacing) / 2

              CareStatRow { width: statGrid.cellWidth; label: "Hunger"; value: root.hunger }
              CareStatRow { width: statGrid.cellWidth; label: "Hygiene"; value: root.hygiene }
              CareStatRow { width: statGrid.cellWidth; label: "Mood"; value: root.mood }
              CareStatRow { width: statGrid.cellWidth; label: "Energy"; value: root.energy }
              CareStatRow { width: statGrid.cellWidth; label: "Health"; value: root.health }
              CareStatRow { width: statGrid.cellWidth; label: "Attention"; value: root.attention }
              CareStatRow { width: statGrid.cellWidth; label: "Bond"; value: root.bond }
              CareStatRow { width: statGrid.cellWidth; label: "Weight"; value: root.weight }
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

          Text {
            width: parent.width
            text: "Generate media"
            color: root.barForeground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          TextField {
            id: promptField
            width: parent.width
            enabled: !root.mediaBusy
            placeholderText: "Prompt (optional with a reference)"
            font.pixelSize: Style.font.subtitle
          }

          Row {
            spacing: Style.space(8)

            ChipButton {
              outlined: false
              text: root.mediaRef === ""
                ? "Add reference"
                : Model.fileBaseName(root.mediaRef)
              tooltipText: root.mediaRef === "" ? "Pick a reference image" : "Pick a different reference image"
              onChipPressed: function(buttonCode) {
                if (buttonCode !== Qt.LeftButton) return
                if (root.svc && typeof root.svc.pickMediaRef === "function") root.svc.pickMediaRef()
              }
            }

            ChipButton {
              visible: root.mediaRef !== ""
              text: "Clear"
              tooltipText: "Drop the reference image"
              onChipPressed: function(buttonCode) {
                if (buttonCode !== Qt.LeftButton) return
                if (root.svc && typeof root.svc.clearMediaRef === "function") root.svc.clearMediaRef()
              }
            }
          }

          Row {
            spacing: Style.space(8)

            ChipButton {
              fill: root.limeColor
              textColor: root.darkText
              text: {
                if (root.mediaBusy) return "Generating…"
                return root.credits >= 0 ? ("Generate · " + root.credits) : "Generate"
              }
              tooltipText: root.credits >= 0
                ? (root.credits + " credits on the account")
                : "Generate an image with Higgsfield"
              onChipPressed: function(buttonCode) {
                if (buttonCode !== Qt.LeftButton) return
                if (root.mediaBusy) return
                if (root.svc && typeof root.svc.generateMedia === "function")
                  root.svc.generateMedia(promptField.text, root.mediaRef)
              }
            }

            ChipButton {
              visible: root.mediaBusy
              text: "Cancel"
              tooltipText: "Stop this generation"
              onChipPressed: function(buttonCode) {
                if (buttonCode !== Qt.LeftButton) return
                if (root.svc && typeof root.svc.cancelMedia === "function") root.svc.cancelMedia()
              }
            }
          }

          Text {
            width: parent.width
            visible: root.mediaBusy && root.mediaStatus !== ""
            text: root.mediaStatus
            color: root.barForeground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            opacity: 0.7
          }

          Text {
            width: parent.width
            visible: root.mediaError !== ""
            text: root.mediaError
            color: root.errorColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            wrapMode: Text.WordWrap
          }

          Rectangle {
            width: parent.width
            height: Style.space(140)
            visible: root.lastMedia !== ""
            radius: Math.min(8, Style.cornerRadius)
            color: Qt.rgba(0, 0, 0, 0.18)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.1)
            clip: true

            Image {
              anchors.fill: parent
              anchors.margins: Style.space(6)
              source: root.lastMedia !== ""
                ? ("file://" + root.lastMedia + "?r=" + root.lastMediaRev)
                : ""
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: false
            }
          }
        }
      }
    }
  }

  component ChipButton: Rectangle {
    id: chip
    property alias text: chipBtn.text
    property alias tooltipText: chipBtn.tooltipText
    property bool selected: false
    property bool outlined: true
    property color fill: "transparent"
    property color textColor: root.barForeground
    readonly property bool filled: chip.fill.a > 0
    signal chipPressed(int button)
    radius: 0
    color: chip.selected ? Qt.alpha(root.barForeground, 0.16) : chip.fill
    border.width: 1
    border.color: chip.selected ? root.barForeground
      : (chip.filled ? chip.fill
        : (chip.outlined ? Qt.alpha(root.barForeground, 0.35) : "transparent"))
    implicitWidth: chipBtn.implicitWidth + Style.space(6)
    implicitHeight: chipBtn.implicitHeight

    WidgetButton {
      id: chipBtn
      anchors.fill: parent
      bar: root.bar
      foreground: chip.textColor
      onPressed: function(buttonCode) { chip.chipPressed(buttonCode) }
    }
  }

  component CareStatRow: Column {
    id: stat
    property string label: ""
    property real value: 0
    spacing: Style.space(3)

    Item {
      width: parent.width
      height: nameLabel.implicitHeight

      Text {
        id: nameLabel
        anchors.left: parent.left
        text: stat.label
        color: root.barForeground
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        opacity: 0.8
      }

      Text {
        anchors.right: parent.right
        text: Math.round(Math.max(0, Math.min(100, stat.value))) + "%"
        color: root.barForeground
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        opacity: 0.7
      }
    }

    Rectangle {
      width: parent.width
      height: 8
      radius: 4
      color: Qt.rgba(1, 1, 1, 0.12)

      Rectangle {
        width: Math.max(0, Math.min(1, stat.value / 100)) * parent.width
        height: parent.height
        radius: parent.radius
        color: root.barForeground
        opacity: 0.85
        Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
      }
    }
  }
}
