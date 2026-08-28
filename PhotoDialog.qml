import QtQuick
import QtQuick.Dialogs
import QtCore

FileDialog {
  id: root
  title: "Choose a character photo"
  fileMode: FileDialog.OpenFile
  nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.gif *.bmp)", "All files (*)"]
  currentFolder: {
    var pics = StandardPaths.writableLocation(StandardPaths.PicturesLocation)
    return pics ? ("file://" + pics) : ""
  }
  signal picked(string path)
  onAccepted: {
    var url = String(root.selectedFile || "")
    if (url.indexOf("file://") === 0) url = decodeURIComponent(url.slice(7))
    if (url) root.picked(url)
  }
}
