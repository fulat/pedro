pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls

Controls.Menu {
    id: root
    property Item backdrop
    property real maximumHeight: 600
    property string folderName
    property bool canPaste: false
    property int selectionCount: 1
    property bool fileMode: false
    property bool imageFile: false
    property bool canRestore: false
    property bool canRemove: false
    signal actionRequested(string action)
    width: 260
    padding: 6
    popupType: Controls.Popup.Window
    background: Loader {
        source: "surface.qml"
        onLoaded: {
            item.sourceBackdrop = Qt.binding(() => root.backdrop);
            item.frosted = true;
            item.cornerRadius = 12;
        }
    }
    delegate: Controls.MenuItem {
        implicitHeight: 36
        contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 13 }
        background: Rectangle { radius: 6; color: parent.highlighted ? "#26ffffff" : "transparent" }
    }
    Controls.Action {
        text: qsTranslate("Pedro", "trash.restore")
        enabled: root.canRestore && !Backend.trash.busy
        onTriggered: root.actionRequested("restore")
    }
    Controls.Action {
        text: qsTranslate("Pedro", "trash.delete")
        enabled: root.canRemove && !Backend.trash.busy
        onTriggered: root.actionRequested("remove")
    }
}
