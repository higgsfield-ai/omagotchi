import QtQuick
import Qt.labs.platform as Labs

Labs.FileDialog {
  id: root
  title: "Choose a character photo"
  nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.gif *.bmp)", "All files (*)"]
  folder: Labs.StandardPaths.writableLocation(Labs.StandardPaths.PicturesLocation)
  signal picked(string path)
  onAccepted: {
    var url = String(root.file || root.currentFile || "")
    if (url.indexOf("file://") === 0) url = decodeURIComponent(url.slice(7))
    if (url) root.picked(url)
  }
}
