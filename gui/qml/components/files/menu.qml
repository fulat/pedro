pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Window
import "../icon" as Icon

Controls.Menu {
    id: menu
    objectName: "filesBackgroundMenu"
    property var directory
    property Item backdrop
    readonly property bool canCreate: !!directory && String(directory.location).startsWith("file:")
    signal informationRequested()
    signal emptyRequested()
    width: 260
    height: Math.max(1, contentItem.implicitHeight + topPadding + bottomPadding)
    padding: 6
    popupType: Controls.Popup.Window
    background: Loader {
        source: "../entry/surface.qml"
        onLoaded: {
            item.sourceBackdrop = Qt.binding(() => menu.backdrop);
            item.frosted = true;
            item.cornerRadius = 12;
        }
    }
    component Action: Controls.MenuItem {
        id: action
        property string symbol
        implicitHeight: visible ? 36 : 0
        hoverEnabled: true
        contentItem: Row {
            spacing: 12
            Icon.Tinted {
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter
                source: "../../../assets/icons/" + action.symbol + ".svg"
                opacity: action.enabled ? 1 : 0.4
            }
            Text {
                text: action.text
                color: "white"
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 1
                opacity: action.enabled ? 1 : 0.4
            }
        }
        background: Rectangle {
            radius: 6
            color: action.enabled && action.hovered ? "#26ffffff" : "transparent"
        }
    }
    Action {
        visible: !menu.directory || !String(menu.directory.location).startsWith("trash:")
        objectName: "filesCreateFolder"
        text: qsTranslate("Pedro", "desktop.menu.folder")
        symbol: "folder"
        enabled: menu.canCreate
        onTriggered: menu.directory.createFolder(text)
    }
    Action {
        visible: !menu.directory || !String(menu.directory.location).startsWith("trash:")
        objectName: "filesCreateFile"
        text: qsTranslate("Pedro", "desktop.menu.file")
        symbol: "file"
        enabled: menu.canCreate
        onTriggered: menu.directory.createFile(text)
    }
    Action {
        visible: !!menu.directory && String(menu.directory.location).startsWith("trash:")
        text: qsTranslate("Pedro", "trash.empty")
        symbol: "trash"
        enabled: !!menu.directory && !Backend.trash.busy && menu.directory.folders.length + menu.directory.files.length > 0
        onTriggered: menu.emptyRequested()
    }
    Action {
        objectName: "filesPaste"
        text: qsTranslate("Pedro", "folder.menu.paste")
        symbol: "paste"
        visible: menu.canCreate
        enabled: menu.canCreate && Backend.clipboard.canPaste && Backend.clipboard.canPasteInto(menu.directory.location)
        onTriggered: Backend.clipboard.paste(menu.directory.location)
    }
    Controls.MenuSeparator {}
    Action {
        text: qsTranslate("Pedro", "folder.menu.properties")
        symbol: "info"
        onTriggered: menu.informationRequested()
    }
}
