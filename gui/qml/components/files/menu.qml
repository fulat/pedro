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
    width: 260
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
        implicitHeight: 36
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
        objectName: "filesCreateFolder"
        text: qsTranslate("Pedro", "desktop.menu.folder")
        symbol: "folder"
        enabled: menu.canCreate
        onTriggered: menu.directory.createFolder(text)
    }
    Action {
        objectName: "filesCreateFile"
        text: qsTranslate("Pedro", "desktop.menu.file")
        symbol: "file"
        enabled: menu.canCreate
        onTriggered: menu.directory.createFile(text)
    }
    Controls.MenuSeparator {}
    Action {
        text: qsTranslate("Pedro", "folder.menu.properties")
        symbol: "info"
        onTriggered: menu.informationRequested()
    }
}
