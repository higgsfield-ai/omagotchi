import QtQuick
import QtMultimedia

// Live webcam viewfinder + still capture. Loaded on demand by the panel —
// and only through a Loader, so a system without QtMultimedia degrades to
// the instant-capture fallback instead of killing the panel.
Item {
  id: root

  property string savePath: ""
  signal captured(string path)
  signal failed(string message)

  function snap() {
    if (!root.savePath) {
      root.failed("no save path")
      return
    }
    capturer.captureToFile(root.savePath)
  }

  CaptureSession {
    id: session
    camera: Camera {
      id: cam
      active: root.visible
      onErrorOccurred: function(error, message) { root.failed(String(message || "camera error")) }
    }
    imageCapture: ImageCapture {
      id: capturer
      onImageSaved: function(requestId, path) { root.captured(String(path)) }
      onErrorOccurred: function(requestId, error, message) { root.failed(String(message || "capture failed")) }
    }
    videoOutput: viewfinder
  }

  VideoOutput {
    id: viewfinder
    anchors.fill: parent
    fillMode: VideoOutput.PreserveAspectCrop
  }
}
