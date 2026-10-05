pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import "../confirmation" as Confirmation
import "../../scripts/theme.js" as Theme

Confirmation.Window {
    id: rename
    objectName: "fileRename"
    property var entry: ({})
    readonly property var editor: nameInput
    title: qsTranslate("Pedro", "folder.menu.rename")
    message: entry.name || ""
    confirmText: title
    acceptOnReturn: true
    actionEnabled: Backend.fileTransfer.validName(nameInput.text) && nameInput.text !== (entry.editName || entry.name) && !Backend.fileTransfer.busy
    extraContent: Controls.TextField {
        id: nameInput
        objectName: "fileRenameInput"
        anchors.left: parent.left
        anchors.right: parent.right
        height: 38
        text: rename.entry.editName || rename.entry.name || ""
        color: Backend.appearanceMode === "light" ? "#263b63" : "#dce6f6"
        selectionColor: Theme.accent
        selectedTextColor: Theme.white
        font.pixelSize: 13
        background: Rectangle { radius: 8; color: Theme.inputBackground; border.color: Theme.dividerSoft }
    }
    onVisibleChanged: {
        if (visible) Qt.callLater(() => {
            nameInput.forceActiveFocus();
            const dot = nameInput.text.lastIndexOf(".");
            nameInput.select(0, !entry.isDirectory && dot > 0 ? dot : nameInput.text.length);
        });
    }
    onAccepted: {
        Backend.fileTransfer.rename(entry.url, nameInput.text);
        Qt.callLater(() => rename.destroy());
    }
    onRejected: Qt.callLater(() => rename.destroy())
}
