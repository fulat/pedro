pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../scripts/theme.js" as Theme

Item {
    id: name
    property var behavior: ({renaming: false, label: "", textColor: "white", cutPending: false, nameSize: 12, nameBold: false, nameAlignment: Text.AlignHCenter})
    readonly property var editor: input
    Text {
        anchors.fill: parent
        visible: !name.behavior.renaming
        text: name.behavior.label
        color: name.behavior.textColor
        opacity: name.behavior.cutPending ? Theme.cutOpacity : 1
        font.pixelSize: name.behavior.nameSize
        font.bold: name.behavior.nameBold
        horizontalAlignment: name.behavior.nameAlignment
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideMiddle
        style: Text.Raised
        styleColor: "#70000000"
    }
    Controls.TextField {
        id: input
        objectName: "entryNameEditor"
        anchors.fill: parent
        visible: name.behavior.renaming
        color: name.behavior.textColor
        font.pixelSize: name.behavior.nameSize
        font.bold: name.behavior.nameBold
        horizontalAlignment: name.behavior.nameAlignment
        selectionColor: Theme.accent
        selectedTextColor: Theme.white
        padding: 3
        background: Rectangle {
            radius: 5
            color: Backend.appearanceMode === "light" ? "#eaf0f8" : "#d9232e3c"
            border.color: Backend.fileTransfer.validName(input.text) ? Theme.liquidEdge : "#ef7777"
        }
        onAccepted: name.behavior.finishRename()
        onActiveFocusChanged: {
            if (!activeFocus && name.behavior.renaming) name.behavior.finishRename(false);
        }
        Keys.onEscapePressed: name.behavior.cancelRename()
    }
}
