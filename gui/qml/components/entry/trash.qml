pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import "../icon" as Icon
import "../../scripts/theme.js" as Theme

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
    property bool canRead: false
    signal actionRequested(string action)
    width: 304
    height: Math.max(1, Math.min(contentItem.implicitHeight + topPadding + bottomPadding, maximumHeight))
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
    component Entry: Controls.MenuItem {
        id: entry
        property string symbol
        property string shortcutText: ""
        implicitHeight: 34
        leftPadding: 12
        rightPadding: 12
        hoverEnabled: true
        contentItem: Row {
            spacing: 12
            Icon.Tinted {
                width: 18; height: 18
                anchors.verticalCenter: parent.verticalCenter
                source: "../../../assets/icons/" + entry.symbol + ".svg"
                opacity: entry.enabled ? 1 : 0.4
            }
            Controls.Label {
                width: Math.max(0, entry.availableWidth - (entry.shortcutText.length ? 96 : 30))
                height: 18
                verticalAlignment: Text.AlignVCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 1
                text: entry.text
                color: Theme.white
                font.pixelSize: 13
                opacity: entry.enabled ? 1 : 0.4
                elide: Text.ElideRight
            }
            Controls.Label {
                visible: entry.shortcutText.length > 0
                width: 54; height: 18
                anchors.verticalCenter: parent.verticalCenter
                text: entry.shortcutText
                color: Theme.textMuted
                font.pixelSize: 12
                horizontalAlignment: Text.AlignRight
                opacity: entry.enabled ? 1 : 0.4
            }
        }
        background: Rectangle {
            radius: 6
            color: entry.enabled && (entry.hovered || entry.highlighted) ? "#26ffffff" : "transparent"
        }
    }
    component Divider: Controls.MenuSeparator {
        topPadding: 6
        bottomPadding: 6
        contentItem: Rectangle { implicitHeight: 1; color: Theme.dividerSoft }
    }
    Entry {
        text: qsTranslate("Pedro", "common.open")
        symbol: root.fileMode ? "file" : "folder"
        shortcutText: "Enter"
        enabled: !root.fileMode || root.canRead
        onTriggered: root.actionRequested("open")
    }
    Entry {
        text: qsTranslate("Pedro", "folder.menu.copy")
        symbol: "copy"
        shortcutText: "Ctrl+C"
        enabled: root.canRead && !Backend.clipboard.busy
        onTriggered: root.actionRequested("copy")
    }
    Entry {
        text: qsTranslate("Pedro", "trash.move")
        symbol: "folder"
        enabled: root.canRemove && !Backend.trash.busy
        onTriggered: root.actionRequested("relocate")
    }
    Divider {}
    Entry {
        text: qsTranslate("Pedro", "trash.restore")
        symbol: "back"
        enabled: root.canRestore && !Backend.trash.busy
        onTriggered: root.actionRequested("restore")
    }
    Entry {
        text: qsTranslate("Pedro", "trash.delete")
        symbol: "trash"
        enabled: root.canRemove && !Backend.trash.busy
        onTriggered: root.actionRequested("remove")
    }
    Divider {}
    Entry {
        text: qsTranslate("Pedro", "folder.menu.properties")
        symbol: "info"
        shortcutText: "Alt+Enter"
        onTriggered: root.actionRequested("properties")
    }
}
