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
  readonly property var svc: root.bar && root.bar.shell && root.bar.shell.serviceFor
    ? root.bar.shell.serviceFor("higgsfield.signals")
    : null
  readonly property bool generating: root.svc ? !!root.svc.generating : false
  readonly property bool picking: root.svc ? !!root.svc.picking : false
  readonly property bool capturing: root.svc ? !!root.svc.capturing : false
  readonly property int photoRev: root.svc ? Number(root.svc.photoRev || 0) : 0
  readonly property bool loggedIn: root.svc ? !!root.svc.loggedIn : false
  readonly property bool loggingIn: root.svc ? !!root.svc.loggingIn : false
  readonly property string photoPath: root.svc ? String(root.svc.photoPath || "") : ""
  readonly property string statusText: root.svc ? String(root.svc.generateStatus || "") : ""
  readonly property int percent: root.svc ? Number(root.svc.generatePercent || 0) : 0
  readonly property int step: root.svc ? Number(root.svc.generateStep || 0) : 0
  readonly property int steps: root.svc ? Number(root.svc.generateSteps || 0) : 0
  readonly property string lastError: root.svc ? String(root.svc.lastError || "") : ""
  readonly property var generateError: Model.classifyGenerateError(root.lastError)
  readonly property real hunger: root.svc ? Number(root.svc.careHunger) : 0
  readonly property real hygiene: root.svc ? Number(root.svc.careHygiene) : 0
  readonly property real mood: root.svc ? Number(root.svc.careMood) : 0
  readonly property real energy: root.svc ? Number(root.svc.careEnergy) : 0
  readonly property real health: root.svc ? Number(root.svc.careHealth) : 0
  readonly property real attention: root.svc ? Number(root.svc.careAttention) : 0
  readonly property real bond: root.svc ? Number(root.svc.careBond) : 0
  readonly property real weight: root.svc ? Number(root.svc.careWeight) : 50
  readonly property bool petRecalling: root.svc ? !!root.svc.petRecalling : false
  readonly property bool petReleasing: root.svc ? !!root.svc.petReleasing : false
  readonly property bool petOnDesktop: root.svc ? !!root.svc.petOnDesktop : false
  readonly property var atlas: root.svc && root.svc.atlas
    ? root.svc.atlas
    : Model.normalizeAtlas(null)
  readonly property string nestMode: Model.nestMode(root.svc ? String(root.svc.mode || "idle") : "idle")
  readonly property var nestFrames: Model.framesForMode(root.atlas, root.nestMode)
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property bool mediaBusy: root.svc ? !!root.svc.mediaBusy : false
  readonly property string mediaStatus: root.svc ? String(root.svc.mediaStatus || "") : ""
  readonly property string mediaError: root.svc ? String(root.svc.mediaError || "") : ""
  readonly property string lastMedia: root.svc ? String(root.svc.lastMediaPath || "") : ""
  readonly property int lastMediaRev: root.svc ? Number(root.svc.lastMediaRev || 0) : 0
  readonly property string lastMediaThumb: root.svc ? String(root.svc.lastMediaThumb || root.svc.lastMediaPath || "") : ""
  readonly property var avatarList: root.svc && root.svc.avatarList ? root.svc.avatarList : []
  readonly property string activeSheet: String(root.atlas.file || "")
  readonly property string mediaKind: root.svc && root.svc.mediaKind ? String(root.svc.mediaKind) : "image"
  readonly property int mediaPrice: root.svc && root.svc.mediaPrice !== undefined ? Number(root.svc.mediaPrice) : -1
  readonly property var mediaRefs: root.svc && root.svc.mediaRefs ? root.svc.mediaRefs : []
  readonly property string mediaRatio: root.svc
    ? String((root.mediaKind === "video" ? root.svc.mediaRatioVideo : root.svc.mediaRatioImage) || (root.mediaKind === "video" ? "16:9" : "1:1"))
    : "1:1"
  readonly property string mediaDuration: root.svc && root.svc.mediaDuration ? String(root.svc.mediaDuration) : "5s"
  readonly property var imageRatios: ["1:1", "4:5", "3:2", "9:16"]
  readonly property var videoRatios: ["16:9", "9:16", "1:1"]
  readonly property var videoDurations: ["5s", "10s"]

  // ---- mock palette (Downloads/tamagotchi-ui.html) ----
  readonly property color cPanel: "#15151f"
  readonly property color cInner: "#101019"
  readonly property color cBorder: "#4b4bff"
  readonly property color cLine: "#33333f"
  readonly property color cText: "#e8e8f0"
  readonly property color cMuted: "#8b8b9a"
  readonly property color cFaint: "#5c5c6b"
  readonly property color cBarBg: "#2c2c38"
  readonly property color cLow: "#f2555a"
  readonly property color cMid: "#f5c04a"
  readonly property color cHigh: "#7ee08a"
  readonly property color cAccent: "#d4f34a"
  readonly property color cHoverLine: "#5a5a6c"
  readonly property color cHoverBg: "#1b1b26"
  readonly property color cActiveBg: "#1e1e2a"

  // Set when the running service predates the panel: keepLoaded services
  // survive plugin hot reloads, so new functions need a shell restart.
  property bool staleService: false
  property string tab: "pet"
  // New-avatar creator state machine: idle -> live (webcam) -> review.
  property bool creatorOpen: false
  property string capState: "idle"
  property string capPhoto: ""
  property string capNote: ""
  readonly property string stagePane: root.generating
    ? "work" : (root.creatorOpen ? "creator" : "view")

  readonly property int avatarIndex: {
    var list = root.avatarList
    for (var i = 0; i < list.length; i++)
      if (String(list[i].sheet) === root.activeSheet) return i
    return -1
  }
  readonly property int avatarCount: root.avatarList.length

  function avatarAt(offset) {
    var n = root.avatarCount
    if (n < 1) return null
    var base = root.avatarIndex >= 0 ? root.avatarIndex : 0
    return root.avatarList[((base + offset) % n + n) % n]
  }

  function activateAvatar(entry) {
    if (!entry || !root.svc || root.generating) return
    if (typeof root.svc.setAvatar === "function") root.svc.setAvatar(entry.dir)
    else root.staleService = true
  }

  onOpenedChanged: {
    if (!root.opened && root.capState === "live") root.capState = "idle"
  }

  onGeneratingChanged: {
    if (!root.generating && root.lastError === "") {
      root.creatorOpen = false
      root.capState = "idle"
      root.capPhoto = ""
      root.capNote = ""
    }
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

  function openCreator() {
    root.creatorOpen = true
    root.capPhoto = ""
    root.capNote = ""
    // Offer the live view straight away, like the mock.
    root.capState = "live"
  }

  function closeCreator() {
    root.creatorOpen = false
    root.capState = "idle"
    root.capPhoto = ""
    root.capNote = ""
  }

  function choosePhoto() {
    if (root.svc && typeof root.svc.pickPhoto === "function") {
      root.svc.pickPhoto()
      return
    }
    var dlg = photoDialogLoader.item
    if (dlg && typeof dlg.open === "function") dlg.open()
  }

  function useCapturedPhoto() {
    if (!root.svc || root.capPhoto === "") return
    if (!root.loggedIn) {
      var hasCli = String(root.svc.hfPath || "") !== ""
      root.svc.login()
      root.capNote = hasCli
        ? "Log in in the browser window that just opened, then press Use photo again."
        : "Setting up the Higgsfield CLI — the login browser opens when it finishes."
      return
    }
    root.capNote = ""
    root.svc.setPhoto(root.capPhoto)
    root.svc.generateSprite(root.capPhoto, "", false)
  }

  function setMediaOption(name, value) {
    if (root.svc && typeof root.svc.setMediaOption === "function")
      root.svc.setMediaOption(name, value)
    else
      root.staleService = true
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
    function onPicked(path) {
      if (root.svc && typeof root.svc.setPhoto === "function") root.svc.setPhoto(path)
    }
  }

  Connections {
    target: root.svc
    function onPhotoRevChanged() {
      if (!root.creatorOpen || root.generating) return
      if (Model.isImagePath(root.photoPath)) {
        root.capPhoto = root.photoPath
        root.capState = "review"
        root.capNote = ""
      }
    }
  }

  // 12x12 pixel glyphs for the control bar, one string per row.
  readonly property var icons: ({
    feed: [
      "............", "......#.....", ".....#......", "..##...##...",
      ".####.####..", ".##########.", ".##########.", ".##########.",
      ".##########.", "..########..", "...##..##...", "............"
    ],
    wash: [
      "............", ".....##.....", ".....##.....", "....####....",
      "....####....", "...######...", "..########..", ".##########.",
      ".##########.", ".##########.", "..########..", "...######..."
    ],
    play: [
      "............", ".....##.....", "....####....", "....####....",
      ".....##.....", ".....##.....", ".....##.....", "...######...",
      "..########..", ".##########.", ".##########.", "............"
    ],
    stand: [
      "............", ".....##.....", ".....##.....", "............",
      "...######...", "...######...", "...######...", ".....##.....",
      "....#..#....", "....#..#....", "....#..#....", "...##..##..."
    ],
    walk: [
      "............", ".....##.....", ".....##.....", "............",
      "...######...", "...######...", "...######...", ".....##.....",
      ".....##.....", "....#..#....", "...#....#...", "...#....#..."
    ],
    run: [
      "............", "......##....", "......##....", "............",
      "...######...", "..#######...", "...#####....", "....##......",
      "...##..##...", "..##....##..", ".##......##.", "............"
    ]
  })

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    padding: 0
    contentWidth: panel.fittedContentWidth(360)
    contentHeight: panel.fittedContentHeight(Math.min(content.implicitHeight + 30, 660))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: promptEdit.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Rectangle {
        anchors.fill: parent
        color: root.cPanel
        radius: Math.max(0, Style.cornerRadius - 2)

        Flickable {
          id: flick
          anchors.fill: parent
          contentWidth: width
          contentHeight: content.implicitHeight + 30
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick

          Column {
            id: content
            x: 14
            y: 14
            width: flick.width - 28
            spacing: 0

            // ---- brand ----
            Row {
              spacing: 9

              HfLogo {
                anchors.verticalCenter: parent.verticalCenter
                cell: 1.35
                color: root.cAccent
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Higgsfield Omagotchi"
                color: root.cText
                font.family: root.fontFamily
                font.pixelSize: 15
                font.bold: true
              }
            }

            Item { width: 1; height: 13 }

            // ---- tabs ----
            Item {
              width: parent.width
              height: 29

              Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: root.cLine
              }

              Row {
                anchors.fill: parent

                Repeater {
                  model: [
                    { label: "Pet", key: "pet" },
                    { label: "Generate", key: "generate" }
                  ]

                  Item {
                    required property var modelData
                    width: content.width / 2
                    height: 29
                    readonly property bool on: root.tab === modelData.key

                    Text {
                      anchors.centerIn: parent
                      text: parent.modelData.label
                      color: parent.on ? root.cAccent : (tabHover.hovered ? root.cText : root.cMuted)
                      font.family: root.fontFamily
                      font.pixelSize: 12
                    }

                    Rectangle {
                      anchors.bottom: parent.bottom
                      width: parent.width
                      height: 2
                      color: root.cAccent
                      visible: parent.on
                    }

                    HoverHandler { id: tabHover; cursorShape: Qt.PointingHandCursor }

                    MouseArea {
                      anchors.fill: parent
                      onClicked: {
                        root.tab = parent.modelData.key
                        // Never leave the camera running behind another tab.
                        if (parent.modelData.key !== "pet" && root.capState === "live")
                          root.capState = "idle"
                      }
                    }
                  }
                }
              }
            }

            Item { width: 1; height: 13 }

            // =========================== PET TAB ===========================
            Column {
              width: parent.width
              visible: root.tab === "pet"
              spacing: 0

              // ---- avatar stage ----
              Rectangle {
                id: stage
                width: parent.width
                implicitHeight: stageContent.implicitHeight + 20
                radius: 4
                color: root.cInner
                border.width: 1
                border.color: root.cLine

                // speech bubble over the pet
                Rectangle {
                  visible: root.stagePane === "view" && root.svc
                    && String(root.svc.bubbleText || "") !== ""
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.top: parent.top
                  anchors.topMargin: 6
                  z: 4
                  width: stageSay.implicitWidth + 12
                  height: stageSay.implicitHeight + 7
                  radius: 3
                  color: root.cAccent

                  Text {
                    id: stageSay
                    anchors.centerIn: parent
                    text: root.svc ? String(root.svc.bubbleText || "") : ""
                    color: root.cPanel
                    font.family: root.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                  }
                }

                Column {
                  id: stageContent
                  x: 11
                  y: 9
                  width: parent.width - 22
                  spacing: 0

                  // ---- view: avatar carousel + stats ----
                  Column {
                    width: parent.width
                    visible: root.stagePane === "view"
                    spacing: 0

                    Item {
                      width: parent.width
                      height: 106

                      Row {
                        anchors.centerIn: parent
                        spacing: 9

                        RoundBtn {
                          anchors.verticalCenter: parent.verticalCenter
                          label: "+"
                          onTapped: root.openCreator()
                        }

                        Peek {
                          anchors.verticalCenter: parent.verticalCenter
                          visible: root.avatarCount >= 2
                          entry: root.avatarAt(-1)
                          onTapped: root.activateAvatar(root.avatarAt(-1))
                        }

                        Item {
                          id: avatarBox
                          anchors.verticalCenter: parent.verticalCenter
                          width: 86
                          height: 106
                          property int frame: 0
                          property real bob: 0
                          property string modeKey: root.nestMode
                          onModeKeyChanged: avatarBox.frame = 0

                          Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Math.round((parent.height - height) / 2 + avatarBox.bob)
                            width: 86
                            height: 86
                            source: {
                              var abs = Model.atlasImageSource(root.atlas.file)
                              var src = abs.indexOf("file://") === 0 ? abs : Qt.resolvedUrl(root.atlas.file)
                              var rev = root.svc ? Number(root.svc.atlasRev || 0) : 0
                              return src + "?r=" + rev
                            }
                            sourceClipRect: Qt.rect(
                              root.nestFrames.frameX + avatarBox.frame * root.nestFrames.frameWidth,
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

                          Timer {
                            interval: {
                              if (root.nestMode === "happy") return 110
                              if (root.nestMode === "eat" || root.nestMode === "wash") return 140
                              if (root.nestMode === "sleep") return 220
                              if (root.nestMode === "grumpy" || root.nestMode === "sick") return 160
                              return 180
                            }
                            running: root.opened && root.tab === "pet" && root.stagePane === "view"
                            repeat: true
                            onTriggered: avatarBox.frame =
                              (avatarBox.frame + 1) % Math.max(1, root.nestFrames.frameCount)
                          }

                          // idle bob, 1.8s two-step like the mock
                          Timer {
                            interval: 900
                            running: root.opened && root.tab === "pet" && root.stagePane === "view"
                            repeat: true
                            onTriggered: avatarBox.bob = avatarBox.bob === 0 ? -3 : 0
                          }
                        }

                        Peek {
                          anchors.verticalCenter: parent.verticalCenter
                          visible: root.avatarCount >= 2
                          entry: root.avatarAt(1)
                          onTapped: root.activateAvatar(root.avatarAt(1))
                        }

                        RoundBtn {
                          anchors.verticalCenter: parent.verticalCenter
                          visible: root.avatarCount >= 2
                          label: "›"
                          onTapped: root.activateAvatar(root.avatarAt(1))
                        }
                      }
                    }

                    Row {
                      anchors.horizontalCenter: parent.horizontalCenter
                      visible: root.avatarCount >= 2
                      spacing: 5

                      Repeater {
                        model: root.avatarList

                        Rectangle {
                          required property int index
                          width: 5
                          height: 5
                          radius: 2.5
                          color: index === root.avatarIndex ? root.cAccent : root.cBarBg
                        }
                      }
                    }

                    Item { width: 1; height: 9 }

                    Rectangle { width: parent.width; height: 1; color: root.cLine }

                    Item { width: 1; height: 10 }

                    Grid {
                      id: statGrid
                      width: parent.width
                      columns: 2
                      columnSpacing: 16
                      rowSpacing: 8
                      readonly property real cellWidth: (width - columnSpacing) / 2

                      StatCell { width: statGrid.cellWidth; label: "Hunger"; value: root.hunger }
                      StatCell { width: statGrid.cellWidth; label: "Hygiene"; value: root.hygiene }
                      StatCell { width: statGrid.cellWidth; label: "Mood"; value: root.mood }
                      StatCell { width: statGrid.cellWidth; label: "Energy"; value: root.energy }
                      StatCell { width: statGrid.cellWidth; label: "Health"; value: root.health }
                      StatCell { width: statGrid.cellWidth; label: "Attention"; value: root.attention }
                      StatCell { width: statGrid.cellWidth; label: "Bond"; value: root.bond }
                      StatCell { width: statGrid.cellWidth; label: "Weight"; value: root.weight }
                    }
                  }

                  // ---- creator: camera / upload ----
                  Column {
                    width: parent.width
                    visible: root.stagePane === "creator"
                    spacing: 0

                    Item {
                      width: parent.width
                      height: paneHeadLabel.implicitHeight

                      Text {
                        id: paneHeadLabel
                        anchors.left: parent.left
                        text: "New avatar"
                        color: root.cMuted
                        font.family: root.fontFamily
                        font.pixelSize: 11
                      }

                      LinkBtn {
                        anchors.right: parent.right
                        text: "Back"
                        onTapped: root.closeCreator()
                      }
                    }

                    Item { width: 1; height: 9 }

                    Rectangle {
                      id: captureBox
                      width: parent.width
                      height: 106
                      radius: 4
                      color: root.cPanel
                      border.width: 1
                      border.color: root.cLine
                      clip: true

                      Text {
                        anchors.centerIn: parent
                        width: parent.width - 24
                        visible: root.capState === "idle"
                        text: root.picking
                          ? "Opening picker…"
                          : "Take a photo with your camera, or upload one"
                        color: root.cFaint
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        font.family: root.fontFamily
                        font.pixelSize: 11
                      }

                      // square live viewfinder = the crop that gets used
                      Item {
                        anchors.centerIn: parent
                        width: 104
                        height: 104
                        clip: true
                        visible: root.capState === "live"

                        Loader {
                          id: cameraLoader
                          anchors.fill: parent
                          active: root.capState === "live" && root.opened && root.creatorOpen
                          source: Qt.resolvedUrl("CameraCapture.qml")
                          onLoaded: {
                            if (item && root.svc && typeof root.svc.dataDir === "function")
                              item.savePath = root.svc.dataDir() + "/webcam-live.jpg"
                          }
                          onStatusChanged: {
                            // No QtMultimedia here: fall back to the instant
                            // ffmpeg capture instead of a dead pane.
                            if (status === Loader.Error) {
                              root.capState = "idle"
                              root.capNote = "No live preview on this system — capturing directly."
                              if (root.svc && typeof root.svc.captureWebcam === "function")
                                root.svc.captureWebcam()
                            }
                          }
                        }
                      }

                      Image {
                        anchors.centerIn: parent
                        width: 104
                        height: 104
                        visible: root.capState === "review" && root.capPhoto !== ""
                        source: root.capPhoto !== ""
                          ? ("file://" + root.capPhoto + "?r=" + root.photoRev) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        clip: true
                      }
                    }

                    Item { width: 1; height: root.capNote !== "" ? 4 : 0 }

                    Text {
                      width: parent.width
                      visible: root.capNote !== ""
                      text: root.capNote
                      color: root.cLow
                      horizontalAlignment: Text.AlignHCenter
                      wrapMode: Text.WordWrap
                      font.family: root.fontFamily
                      font.pixelSize: 10
                    }

                    Item { width: 1; height: 9 }

                    Row {
                      anchors.horizontalCenter: parent.horizontalCenter
                      spacing: 8

                      Btn {
                        visible: root.capState === "idle"
                        label: root.capturing ? "Smile…" : "Take photo"
                        onTapped: {
                          root.capNote = ""
                          root.capState = "live"
                        }
                      }

                      LimeBtn {
                        visible: root.capState === "live"
                        label: "Capture"
                        onTapped: {
                          if (cameraLoader.item) cameraLoader.item.snap()
                        }
                      }

                      Btn {
                        visible: root.capState === "review"
                        label: "Retake"
                        onTapped: {
                          root.capPhoto = ""
                          root.capNote = ""
                          root.capState = "idle"
                        }
                      }

                      Btn {
                        visible: root.capState !== "review"
                        label: "Upload"
                        onTapped: {
                          root.capNote = ""
                          root.choosePhoto()
                        }
                      }

                      LimeBtn {
                        visible: root.capState === "review"
                        label: "Use photo"
                        onTapped: root.useCapturedPhoto()
                      }
                    }

                    Item { width: 1; height: root.loggingIn ? 8 : 0 }

                    Text {
                      width: parent.width
                      visible: root.loggingIn
                      horizontalAlignment: Text.AlignHCenter
                      text: root.statusText !== "" ? root.statusText : "Waiting for browser login…"
                      color: root.cMuted
                      font.family: root.fontFamily
                      font.pixelSize: 11
                    }

                    Connections {
                      target: cameraLoader.item
                      function onCaptured(path) {
                        root.capPhoto = String(path)
                        root.capState = "review"
                        root.capNote = ""
                      }
                      function onFailed(message) {
                        root.capState = "idle"
                        root.capNote = "Camera unavailable — use Upload instead."
                      }
                    }
                  }

                  // ---- work: generation in flight ----
                  Column {
                    width: parent.width
                    visible: root.stagePane === "work"
                    spacing: 0

                    Item {
                      width: parent.width
                      height: workHeadLabel.implicitHeight

                      Text {
                        id: workHeadLabel
                        anchors.left: parent.left
                        text: "Generating avatar"
                        color: root.cMuted
                        font.family: root.fontFamily
                        font.pixelSize: 11
                      }

                      LinkBtn {
                        anchors.right: parent.right
                        text: "Cancel"
                        hoverColor: root.cLow
                        onTapped: {
                          if (root.svc && typeof root.svc.cancelGenerate === "function")
                            root.svc.cancelGenerate()
                        }
                      }
                    }

                    Item { width: 1; height: 9 }

                    Rectangle {
                      width: parent.width
                      height: 106
                      radius: 4
                      color: root.cPanel
                      border.width: 1
                      border.color: root.cLine
                      clip: true

                      Image {
                        anchors.centerIn: parent
                        width: 104
                        height: 104
                        visible: Model.isImagePath(root.photoPath) && root.generating
                        source: Model.isImagePath(root.photoPath)
                          ? ("file://" + root.photoPath + "?r=" + root.photoRev) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        opacity: 0.72
                        clip: true
                      }
                    }

                    Item { width: 1; height: 9 }

                    GenerateProgress {
                      width: parent.width
                      bar: root.bar
                      foreground: root.cText
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

              // ---- generation error ----
              Column {
                width: parent.width
                visible: root.lastError !== "" && !root.generating && !root.loggingIn
                spacing: 8

                Item { width: 1; height: 5 }

                Text {
                  width: parent.width
                  visible: root.generateError.message !== ""
                  text: root.generateError.message
                  color: root.cLow
                  font.family: root.fontFamily
                  font.pixelSize: 11
                  wrapMode: Text.WordWrap
                }

                Text {
                  width: parent.width
                  visible: root.svc && Number(root.svc.failStreak) >= 2
                  text: "Two runs failed in a row — Retry starts everything fresh from the base sprite, which usually clears a bad streak."
                  color: root.cMuted
                  font.family: root.fontFamily
                  font.pixelSize: 11
                  wrapMode: Text.WordWrap
                }

                Row {
                  spacing: 8

                  LimeBtn {
                    label: "Retry"
                    onTapped: {
                      if (root.svc && typeof root.svc.retryGenerate === "function")
                        root.svc.retryGenerate()
                    }
                  }

                  Btn {
                    visible: !!root.generateError.showUpgrade
                    label: "Upgrade plan"
                    onTapped: Qt.openUrlExternally(root.generateError.pricingUrl)
                  }
                }
              }

              Item { width: 1; height: 13 }

              // ---- control bar: care actions | activity ----
              Row {
                id: barRow
                width: parent.width
                spacing: 5
                readonly property real actWidth: (width - 5 * 6 - 7) / 6

                ActButton {
                  width: barRow.actWidth
                  glyph: root.icons.feed
                  label: "Feed"
                  onTapped: if (root.svc && typeof root.svc.feedPet === "function") root.svc.feedPet()
                }

                ActButton {
                  width: barRow.actWidth
                  glyph: root.icons.wash
                  label: "Wash"
                  onTapped: if (root.svc && typeof root.svc.washPet === "function") root.svc.washPet()
                }

                ActButton {
                  width: barRow.actWidth
                  glyph: root.icons.play
                  label: "Play"
                  onTapped: if (root.svc && typeof root.svc.playPet === "function") root.svc.playPet()
                }

                Item {
                  width: 7
                  height: 42

                  Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 3
                    anchors.bottomMargin: 3
                    width: 1
                    color: root.cLine
                  }
                }

                ActButton {
                  width: barRow.actWidth
                  glyph: root.icons.stand
                  label: "Stand"
                  active: root.svc && String(root.svc.petActivity) === "standing"
                  onTapped: if (root.svc && typeof root.svc.setActivity === "function") root.svc.setActivity("standing")
                }

                ActButton {
                  width: barRow.actWidth
                  glyph: root.icons.walk
                  label: "Walk"
                  active: root.svc && String(root.svc.petActivity) === "walking"
                  onTapped: if (root.svc && typeof root.svc.setActivity === "function") root.svc.setActivity("walking")
                }

                ActButton {
                  width: barRow.actWidth
                  glyph: root.icons.run
                  label: "Run"
                  active: root.svc && String(root.svc.petActivity) === "running"
                  onTapped: if (root.svc && typeof root.svc.setActivity === "function") root.svc.setActivity("running")
                }
              }

              Item { width: 1; height: 13 }

              // ---- release / hide ----
              Row {
                width: parent.width
                spacing: 8
                readonly property real pillWidth: (width - 8) / 2

                PillBtn {
                  width: parent.pillWidth
                  label: "Release"
                  active: root.petOnDesktop
                  onTapped: {
                    if (root.svc && !root.petOnDesktop && !root.petReleasing)
                      root.svc.releasePet()
                  }
                }

                PillBtn {
                  width: parent.pillWidth
                  label: "Hide"
                  active: !root.petOnDesktop
                  onTapped: {
                    if (root.svc && root.petOnDesktop && !root.petRecalling)
                      root.svc.recallPet()
                  }
                }
              }

              Item { width: 1; height: 9 }

              Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: {
                  if (root.petRecalling) return "Coming home…"
                  if (root.petReleasing) return "Heading out…"
                  return root.petOnDesktop ? "Roaming your desktop" : "Tucked away in the app"
                }
                color: root.cFaint
                font.family: root.fontFamily
                font.pixelSize: 11
              }
            }

            // ======================== GENERATE TAB =========================
            Column {
              width: parent.width
              visible: root.tab === "generate"
              spacing: 0

              Item {
                width: parent.width
                height: Math.max(typeHead.implicitHeight, kindSeg.implicitHeight)

                Text {
                  id: typeHead
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Type"
                  color: root.cText
                  font.family: root.fontFamily
                  font.pixelSize: 13
                  font.bold: true
                }

                Row {
                  id: kindSeg
                  anchors.right: parent.right
                  spacing: 8

                  Btn {
                    label: "Image"
                    active: root.mediaKind === "image"
                    onTapped: {
                      if (root.svc && typeof root.svc.setMediaKind === "function")
                        root.svc.setMediaKind("image")
                      else root.staleService = true
                    }
                  }

                  Btn {
                    label: "Video"
                    active: root.mediaKind === "video"
                    onTapped: {
                      if (root.svc && typeof root.svc.setMediaKind === "function")
                        root.svc.setMediaKind("video")
                      else root.staleService = true
                    }
                  }
                }
              }

              Item { width: 1; height: 9 }

              // Model (one real backend model per type)
              Row {
                width: parent.width
                spacing: 10

                Text {
                  width: 58
                  topPadding: 7
                  text: "Model"
                  color: root.cMuted
                  font.family: root.fontFamily
                  font.pixelSize: 11
                }

                Rectangle {
                  width: parent.width - 68
                  height: modelName.implicitHeight + 14
                  radius: 4
                  color: root.cInner
                  border.width: 1
                  border.color: root.cLine

                  Text {
                    id: modelName
                    anchors.left: parent.left
                    anchors.leftMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.mediaKind === "video" ? "Seedance 2.0 Mini" : "Nano Banana 2"
                    color: root.cText
                    font.family: root.fontFamily
                    font.pixelSize: 12
                  }

                  Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    text: "▾"
                    color: root.cMuted
                    font.family: root.fontFamily
                    font.pixelSize: 10
                  }
                }
              }

              Item { width: 1; height: 8 }

              // Ratio
              Row {
                width: parent.width
                spacing: 10

                Text {
                  width: 58
                  topPadding: 7
                  text: "Ratio"
                  color: root.cMuted
                  font.family: root.fontFamily
                  font.pixelSize: 11
                }

                Flow {
                  width: parent.width - 68
                  spacing: 6

                  Repeater {
                    model: root.mediaKind === "video" ? root.videoRatios : root.imageRatios

                    Btn {
                      required property var modelData
                      mini: true
                      label: modelData
                      active: root.mediaRatio === modelData
                      onTapped: root.setMediaOption("ratio", modelData)
                    }
                  }
                }
              }

              Item { width: 1; height: root.mediaKind === "video" ? 8 : 0 }

              // Duration (video only)
              Row {
                width: parent.width
                visible: root.mediaKind === "video"
                spacing: 10

                Text {
                  width: 58
                  topPadding: 7
                  text: "Duration"
                  color: root.cMuted
                  font.family: root.fontFamily
                  font.pixelSize: 11
                }

                Flow {
                  width: parent.width - 68
                  spacing: 6

                  Repeater {
                    model: root.videoDurations

                    Btn {
                      required property var modelData
                      mini: true
                      label: modelData
                      active: root.mediaDuration === modelData
                      onTapped: root.setMediaOption("duration", modelData)
                    }
                  }
                }
              }

              Item { width: 1; height: 8 }

              // Prompt
              Rectangle {
                width: parent.width
                height: Math.max(62, promptEdit.implicitHeight + 18) + 2
                radius: 4
                color: root.cInner
                border.width: 1
                border.color: promptEdit.activeFocus ? root.cHoverLine : root.cLine

                TextEdit {
                  id: promptEdit
                  anchors.fill: parent
                  anchors.margins: 9
                  anchors.leftMargin: 11
                  anchors.rightMargin: 11
                  enabled: !root.mediaBusy
                  color: root.cText
                  selectionColor: root.cBorder
                  wrapMode: TextEdit.Wrap
                  font.family: root.fontFamily
                  font.pixelSize: 12
                }

                Text {
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.topMargin: 9
                  anchors.leftMargin: 11
                  width: parent.width - 22
                  wrapMode: Text.WordWrap
                  visible: promptEdit.text === "" && !promptEdit.activeFocus
                  text: "What should we make? A cosy pixel bedroom at sunset…"
                  color: root.cFaint
                  font.family: root.fontFamily
                  font.pixelSize: 12
                }

                MouseArea {
                  anchors.fill: parent
                  visible: !promptEdit.activeFocus
                  cursorShape: Qt.IBeamCursor
                  onClicked: promptEdit.forceActiveFocus()
                }
              }

              Item { width: 1; height: 11 }

              // Reference images
              Item {
                width: parent.width
                height: refHead.implicitHeight

                Text {
                  id: refHead
                  anchors.left: parent.left
                  text: "Reference"
                  color: root.cMuted
                  font.family: root.fontFamily
                  font.pixelSize: 11
                }

                Row {
                  anchors.right: parent.right
                  spacing: 9

                  Text {
                    text: root.mediaRefs.length + " / 50"
                    color: root.cFaint
                    font.family: root.fontFamily
                    font.pixelSize: 11
                  }

                  LinkBtn {
                    visible: root.mediaRefs.length > 0
                    text: "Clear all"
                    hoverColor: root.cLow
                    onTapped: {
                      if (root.svc && typeof root.svc.clearMediaRefs === "function")
                        root.svc.clearMediaRefs()
                      else root.staleService = true
                    }
                  }
                }
              }

              Item { width: 1; height: 6 }

              Item {
                width: parent.width
                height: Math.max(58, chipsFlow.implicitHeight + 16)

                DashedRect { anchors.fill: parent; stroke: root.cLine }

                Flow {
                  id: chipsFlow
                  x: 8
                  y: 8
                  width: parent.width - 16
                  spacing: 6

                  Repeater {
                    model: root.mediaRefs

                    Rectangle {
                      required property var modelData
                      required property int index
                      width: 40
                      height: 40
                      radius: 4
                      color: "transparent"
                      border.width: 1
                      border.color: root.cLine
                      clip: true

                      Image {
                        anchors.fill: parent
                        anchors.margins: 1
                        source: "file://" + modelData
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize.width: 80
                        sourceSize.height: 80
                      }

                      Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        width: 15
                        height: 15
                        color: chipXHover.hovered ? root.cLow : Qt.rgba(10 / 255, 10 / 255, 16 / 255, 0.82)

                        Text {
                          anchors.centerIn: parent
                          text: "×"
                          color: chipXHover.hovered ? root.cPanel : root.cText
                          font.family: root.fontFamily
                          font.pixelSize: 11
                        }

                        HoverHandler { id: chipXHover; cursorShape: Qt.PointingHandCursor }

                        MouseArea {
                          anchors.fill: parent
                          onClicked: {
                            if (root.svc && typeof root.svc.removeMediaRef === "function")
                              root.svc.removeMediaRef(parent.parent.index)
                            else root.staleService = true
                          }
                        }
                      }
                    }
                  }

                  Item {
                    width: 40
                    height: 40
                    visible: root.mediaRefs.length < 50

                    DashedRect {
                      anchors.fill: parent
                      stroke: chipAddHover.hovered ? root.cAccent : root.cLine
                    }

                    Text {
                      anchors.centerIn: parent
                      text: root.svc && root.svc.mediaPicking ? "…" : "+"
                      color: chipAddHover.hovered ? root.cAccent : root.cMuted
                      font.family: root.fontFamily
                      font.pixelSize: 15
                    }

                    HoverHandler { id: chipAddHover; cursorShape: Qt.PointingHandCursor }

                    MouseArea {
                      anchors.fill: parent
                      onClicked: {
                        if (root.svc && typeof root.svc.pickMediaRef === "function")
                          root.svc.pickMediaRef()
                        else root.staleService = true
                      }
                    }
                  }

                  Text {
                    visible: root.mediaRefs.length === 0
                    height: 40
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 2
                    text: "Tap + to add reference images"
                    color: root.cFaint
                    font.family: root.fontFamily
                    font.pixelSize: 11
                  }
                }
              }

              Item { width: 1; height: 12 }

              LimeBtn {
                width: parent.width
                wide: true
                enabledLook: !root.mediaBusy
                label: {
                  if (root.mediaBusy) return "Generating…"
                  return root.mediaPrice >= 0 ? ("Generate · " + root.mediaPrice) : "Generate"
                }
                onTapped: {
                  if (root.mediaBusy) return
                  if (root.svc && typeof root.svc.generateMedia === "function")
                    root.svc.generateMedia(promptEdit.text)
                  else root.staleService = true
                }
              }

              Item { width: 1; height: root.mediaBusy ? 8 : 0 }

              Item {
                width: parent.width
                visible: root.mediaBusy
                height: mediaBusyStatus.implicitHeight + 4

                Text {
                  id: mediaBusyStatus
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - 70
                  text: root.mediaStatus !== "" ? root.mediaStatus : "Working…"
                  color: root.cMuted
                  elide: Text.ElideRight
                  font.family: root.fontFamily
                  font.pixelSize: 11
                }

                LinkBtn {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Cancel"
                  hoverColor: root.cLow
                  onTapped: {
                    if (root.svc && typeof root.svc.cancelMedia === "function")
                      root.svc.cancelMedia()
                  }
                }
              }

              Item { width: 1; height: root.mediaError !== "" ? 8 : 0 }

              Text {
                width: parent.width
                visible: root.mediaError !== ""
                text: root.mediaError
                color: root.cLow
                font.family: root.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WordWrap
              }

              Item { width: 1; height: 12 }

              // Result: doorway to the media folder, not a gallery.
              Item {
                width: parent.width
                height: 128

                DashedRect { anchors.fill: parent; stroke: root.cLine }

                Text {
                  anchors.centerIn: parent
                  width: parent.width - 32
                  visible: root.lastMedia === ""
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.WordWrap
                  text: "Your creations will show up here"
                  color: root.cFaint
                  font.family: root.fontFamily
                  font.pixelSize: 11
                }

                Image {
                  anchors.fill: parent
                  anchors.margins: 6
                  visible: root.lastMedia !== ""
                  source: root.lastMediaThumb !== ""
                    ? ("file://" + root.lastMediaThumb + "?r=" + root.lastMediaRev) : ""
                  fillMode: Image.PreserveAspectFit
                  asynchronous: true
                  cache: false
                }

                MouseArea {
                  anchors.fill: parent
                  visible: root.lastMedia !== ""
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.svc && typeof root.svc.openMediaFolder === "function")
                      root.svc.openMediaFolder()
                    else root.staleService = true
                  }
                }
              }
            }

            Item { width: 1; height: root.staleService ? 10 : 0 }

            Text {
              width: parent.width
              visible: root.staleService
              text: "Plugin updated under a running shell — run omarchy-restart-shell to finish."
              color: root.cLow
              font.family: root.fontFamily
              font.pixelSize: 11
              wrapMode: Text.WordWrap
            }
          }
        }
      }
    }
  }

  // ---- building blocks matching the mock's CSS ----

  component PixelIcon: Canvas {
    id: pix
    property var rows: []
    property color fg: "#8b8b9a"
    width: 14
    height: 14
    onFgChanged: pix.requestPaint()
    onRowsChanged: pix.requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.fillStyle = String(pix.fg)
      var s = width / 12
      for (var y = 0; y < pix.rows.length; y++) {
        var row = String(pix.rows[y])
        for (var x = 0; x < row.length; x++) {
          if (row.charAt(x) !== "#") continue
          var w = 1
          while (row.charAt(x + w) === "#") w++
          ctx.fillRect(x * s, y * s, w * s, s + 0.4)
          x += w - 1
        }
      }
    }
  }

  component DashedRect: Canvas {
    id: dash
    property color stroke: "#33333f"
    onStrokeChanged: dash.requestPaint()
    onWidthChanged: dash.requestPaint()
    onHeightChanged: dash.requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.strokeStyle = String(dash.stroke)
      ctx.lineWidth = 1
      var on = 4, off = 3
      function line(x1, y1, x2, y2) {
        var len = Math.abs(x2 - x1) + Math.abs(y2 - y1)
        var dx = (x2 - x1) / len, dy = (y2 - y1) / len
        var t = 0
        ctx.beginPath()
        while (t < len) {
          var seg = Math.min(on, len - t)
          ctx.moveTo(x1 + dx * t, y1 + dy * t)
          ctx.lineTo(x1 + dx * (t + seg), y1 + dy * (t + seg))
          t += on + off
        }
        ctx.stroke()
      }
      line(0.5, 0.5, width - 0.5, 0.5)
      line(width - 0.5, 0.5, width - 0.5, height - 0.5)
      line(width - 0.5, height - 0.5, 0.5, height - 0.5)
      line(0.5, height - 0.5, 0.5, 0.5)
    }
  }

  component Btn: Rectangle {
    id: btn
    property string label: ""
    property bool active: false
    property bool mini: false
    signal tapped()
    radius: 4
    color: btn.active ? root.cActiveBg : (btnHover.hovered ? root.cHoverBg : "transparent")
    border.width: 1
    border.color: btn.active ? "#8f8fa5" : (btnHover.hovered ? root.cHoverLine : root.cLine)
    implicitWidth: btnText.implicitWidth + (btn.mini ? 18 : 26)
    implicitHeight: btnText.implicitHeight + (btn.mini ? 10 : 12)

    Text {
      id: btnText
      anchors.centerIn: parent
      text: btn.label
      color: root.cText
      font.family: root.fontFamily
      font.pixelSize: btn.mini ? 11 : 12
    }

    HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }
    MouseArea { anchors.fill: parent; onClicked: btn.tapped() }
  }

  component LimeBtn: Rectangle {
    id: lime
    property string label: ""
    property bool wide: false
    property bool enabledLook: true
    signal tapped()
    radius: 4
    color: limeMouse.pressed ? "#bfe038" : (limeHover.hovered ? "#e0ff5c" : root.cAccent)
    opacity: lime.enabledLook ? 1 : 0.65
    implicitWidth: limeText.implicitWidth + 36
    implicitHeight: limeText.implicitHeight + (lime.wide ? 20 : 14)

    Text {
      id: limeText
      anchors.centerIn: parent
      text: lime.label
      color: root.cPanel
      font.family: root.fontFamily
      font.pixelSize: 12
      font.bold: true
    }

    HoverHandler { id: limeHover; cursorShape: Qt.PointingHandCursor }
    MouseArea { id: limeMouse; anchors.fill: parent; onClicked: lime.tapped() }
  }

  component LinkBtn: Text {
    id: link
    property color base: root.cMuted
    property color hoverColor: root.cText
    signal tapped()
    color: linkHover.hovered ? link.hoverColor : link.base
    font.family: root.fontFamily
    font.pixelSize: 11

    HoverHandler { id: linkHover; cursorShape: Qt.PointingHandCursor }
    MouseArea { anchors.fill: parent; onClicked: link.tapped() }
  }

  component PillBtn: Rectangle {
    id: pill
    property string label: ""
    property bool active: false
    signal tapped()
    radius: 4
    color: pill.active ? root.cActiveBg : (pillHover.hovered ? root.cHoverBg : "transparent")
    border.width: 1
    border.color: pill.active ? root.cAccent : (pillHover.hovered ? root.cHoverLine : root.cLine)
    implicitHeight: pillText.implicitHeight + 22

    Text {
      id: pillText
      anchors.centerIn: parent
      text: pill.label
      color: pill.active ? root.cAccent : (pillHover.hovered ? root.cText : root.cMuted)
      font.family: root.fontFamily
      font.pixelSize: 12
      font.bold: true
    }

    HoverHandler { id: pillHover; cursorShape: Qt.PointingHandCursor }
    MouseArea { anchors.fill: parent; onClicked: pill.tapped() }
  }

  component RoundBtn: Rectangle {
    id: roundBtn
    property string label: "+"
    signal tapped()
    width: 26
    height: 26
    radius: 13
    color: roundHover.hovered ? root.cHoverBg : "transparent"
    border.width: 1
    border.color: roundHover.hovered ? root.cAccent : root.cLine

    Text {
      anchors.centerIn: parent
      anchors.verticalCenterOffset: -1
      text: roundBtn.label
      color: roundHover.hovered ? root.cAccent : root.cMuted
      font.family: root.fontFamily
      font.pixelSize: 15
    }

    HoverHandler { id: roundHover; cursorShape: Qt.PointingHandCursor }
    MouseArea { anchors.fill: parent; onClicked: roundBtn.tapped() }
  }

  component ActButton: Rectangle {
    id: act
    property var glyph: []
    property string label: ""
    property bool active: false
    signal tapped()
    readonly property color tone: act.active ? root.cAccent : (actHover.hovered ? root.cText : root.cMuted)
    radius: 4
    color: act.active ? root.cActiveBg : (actHover.hovered ? root.cHoverBg : "transparent")
    border.width: 1
    border.color: act.active ? root.cAccent : (actHover.hovered ? root.cHoverLine : root.cLine)
    implicitHeight: actCol.implicitHeight + 10

    Column {
      id: actCol
      anchors.centerIn: parent
      spacing: 4

      PixelIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        rows: act.glyph
        fg: act.tone
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: act.label
        color: act.tone
        font.family: root.fontFamily
        font.pixelSize: 10
      }
    }

    HoverHandler { id: actHover; cursorShape: Qt.PointingHandCursor }
    MouseArea { anchors.fill: parent; onClicked: act.tapped() }
  }

  // Chrome-less like the mock; dimmed via opacity only. Kept brighter than
  // the mock's 0.38 so dark transparent-background sprites stay visible
  // against the near-black stage.
  component Peek: Item {
    id: peek
    property var entry: null
    signal tapped()
    width: 53
    height: 53
    opacity: peekHover.hovered ? 1 : 0.55
    scale: peekHover.hovered ? 1.07 : 1

    Behavior on opacity { NumberAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 150 } }

    Image {
      anchors.fill: parent
      source: peek.entry && peek.entry.thumb ? "file://" + peek.entry.thumb : ""
      fillMode: Image.PreserveAspectFit
      smooth: false
      asynchronous: true
      cache: false
    }

    HoverHandler { id: peekHover; cursorShape: Qt.PointingHandCursor }
    MouseArea { anchors.fill: parent; onClicked: peek.tapped() }
  }

  component StatCell: Column {
    id: stat
    property string label: ""
    property real value: 0
    readonly property real clamped: Math.max(0, Math.min(100, stat.value))
    readonly property color tierColor: stat.clamped < 34 ? root.cLow
      : (stat.clamped < 67 ? root.cMid : root.cHigh)
    spacing: 4

    Item {
      width: parent.width
      height: statName.implicitHeight

      Text {
        id: statName
        anchors.left: parent.left
        text: stat.label
        color: root.cMuted
        font.family: root.fontFamily
        font.pixelSize: 12
      }

      Text {
        anchors.right: parent.right
        text: Math.round(stat.clamped) + "%"
        color: root.cMuted
        font.family: root.fontFamily
        font.pixelSize: 12
      }
    }

    Rectangle {
      width: parent.width
      height: 5
      radius: 4
      color: root.cBarBg

      Rectangle {
        width: stat.clamped / 100 * parent.width
        height: parent.height
        radius: parent.radius
        color: stat.tierColor
        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: 300 } }
      }
    }
  }
}
