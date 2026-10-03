pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls
import "../icon" as Icon
import ".." as Components
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

    signal actionRequested(string action)

    width: 304
    height: Math.max(1, Math.min(contentItem.implicitHeight + topPadding + bottomPadding, maximumHeight))
    padding: 6
    popupType: Controls.Popup.Window
    cascade: true

    background: Surface {
        sourceBackdrop: root.backdrop
        frosted: true
        blurAmount: 1.0
        cornerRadius: 12
    }

    component Surface: Loader {
        property Item sourceBackdrop
        property bool frosted: true
        property real blurAmount: 1.0
        property real cornerRadius: 12
        source: "surface.qml"
        onLoaded: {
            item.sourceBackdrop = Qt.binding(() => sourceBackdrop);
            item.frosted = Qt.binding(() => frosted);
            item.blurAmount = Qt.binding(() => blurAmount);
            item.cornerRadius = Qt.binding(() => cornerRadius);
        }
    }

    delegate: Entry {}

    component Entry: Controls.MenuItem {
        id: entry

        property string symbol: subMenu === openWithMenu ? "tab" : subMenu === compressionMenu ? "archive" : subMenu === sharingMenu ? "share" : ""
        property string shortcutText: ""

        hoverEnabled: true
        visible: subMenu !== openWithMenu || (root.fileMode && root.selectionCount <= 1)
        implicitHeight: visible ? 34 : 0
        leftPadding: 12
        rightPadding: 12

        contentItem: Row {
            spacing: 12

            Icon.Tinted {
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter
                source: entry.symbol.length ? "../../../assets/icons/" + entry.symbol + ".svg" : ""
                opacity: entry.enabled ? 1 : 0.4
            }

            Controls.Label {
                height: 18
                verticalAlignment: Text.AlignVCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 1
                width: Math.max(0, entry.availableWidth - 96)
                text: entry.text
                color: Theme.white
                font.pixelSize: 13
                opacity: entry.enabled ? 1 : 0.4
                elide: Text.ElideRight
            }

            Controls.Label {
                height: 18
                verticalAlignment: Text.AlignVCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 1
                width: 54
                text: entry.subMenu ? "›" : entry.shortcutText
                color: Theme.textMuted
                font.pixelSize: 12
                horizontalAlignment: Text.AlignRight
                opacity: entry.enabled ? 1 : 0.4
            }
        }

        arrow: Item {}

        background: Rectangle {
            radius: 6
            color: entry.enabled && (entry.hovered || entry.highlighted) ? "#26ffffff" : "transparent"
        }
    }

    component Divider: Controls.MenuSeparator {
        topPadding: 6
        bottomPadding: 6
        contentItem: Rectangle {
            implicitHeight: 1
            color: Theme.dividerSoft
        }
    }

    Entry {
        text: qsTranslate("Pedro", "common.open")
        symbol: root.fileMode ? "file" : "folder"
        shortcutText: "Enter"
        onTriggered: root.actionRequested("open")
    }

    Entry {
        visible: !root.fileMode && root.selectionCount <= 1
        text: qsTranslate("Pedro", "folder.menu.open.tab")
        symbol: "tab"
        onTriggered: root.actionRequested("tab")
    }

    Entry {
        visible: !root.fileMode && root.selectionCount <= 1
        text: qsTranslate("Pedro", "folder.menu.open.window")
        symbol: "window"
        onTriggered: root.actionRequested("window")
    }

    Controls.Menu {
        id: openWithMenu
        title: qsTranslate("Pedro", "file.menu.open.with")
        width: 210
        padding: 6
        height: Math.max(1, Math.min(contentItem.implicitHeight + topPadding + bottomPadding, root.maximumHeight))
        popupType: Controls.Popup.Window
        delegate: Entry {}
        background: Surface {
            sourceBackdrop: root.backdrop
            frosted: true
            blurAmount: 1.0
            cornerRadius: 12
        }
        Entry {
            text: qsTranslate("Pedro", "file.menu.application")
            symbol: "window"
            onTriggered: root.actionRequested("application")
        }
    }

    Entry {
        visible: root.fileMode && root.selectionCount <= 1
        text: qsTranslate("Pedro", "file.menu.preview")
        symbol: "eye"
        shortcutText: "Espacio"
        onTriggered: root.actionRequested("preview")
    }

    Divider {}
    Entry {
        text: qsTranslate("Pedro", "folder.menu.cut")
        symbol: "cut"
        shortcutText: "Ctrl+X"
        onTriggered: root.actionRequested("cut")
    }

    Entry {
        text: qsTranslate("Pedro", "folder.menu.copy")
        symbol: "copy"
        shortcutText: "Ctrl+C"
        onTriggered: root.actionRequested("copy")
    }

    Entry {
        text: qsTranslate("Pedro", "folder.menu.paste")
        symbol: "paste"
        shortcutText: "Ctrl+V"
        enabled: root.canPaste
        onTriggered: root.actionRequested("paste")
    }

    Divider {}
    Entry {
        visible: root.selectionCount <= 1
        text: qsTranslate("Pedro", "folder.menu.rename")
        symbol: "rename"
        shortcutText: "F2"
        onTriggered: root.actionRequested("rename")
    }

    Entry {
        visible: root.fileMode && root.selectionCount <= 1
        text: qsTranslate("Pedro", "file.menu.duplicate")
        symbol: "copy"
        shortcutText: "Ctrl+D"
        onTriggered: root.actionRequested("duplicate")
    }

    Entry {
        text: qsTranslate("Pedro", "folder.menu.trash")
        symbol: "trash"
        shortcutText: "Delete"
        onTriggered: root.actionRequested("trash")
    }

    Divider {}

    Controls.Menu {
        id: compressionMenu
        title: qsTranslate("Pedro", "folder.menu.compress")
        width: 210
        padding: 6
        height: Math.max(1, Math.min(contentItem.implicitHeight + topPadding + bottomPadding, root.maximumHeight))
        popupType: Controls.Popup.Window
        delegate: Entry {}
        background: Surface {
            sourceBackdrop: root.backdrop
            frosted: true
            blurAmount: 1.0
            cornerRadius: 12
        }
        Entry {
            text: qsTranslate("Pedro", "folder.menu.archive.zip")
            symbol: "file"
            onTriggered: root.actionRequested("zip")
        }

        Entry {
            text: qsTranslate("Pedro", "folder.menu.archive.gzip")
            symbol: "file"
            onTriggered: root.actionRequested("gzip")
        }

        Entry {
            text: qsTranslate("Pedro", "folder.menu.archive.xz")
            symbol: "file"
            onTriggered: root.actionRequested("xz")
        }

        Entry {
            text: qsTranslate("Pedro", "folder.menu.archive.other")
            symbol: "file"
            onTriggered: root.actionRequested("archive")
        }

    }

    Controls.Menu {
        id: sharingMenu
        title: qsTranslate("Pedro", "folder.menu.share")
        width: 210
        padding: 6
        height: Math.max(1, Math.min(contentItem.implicitHeight + topPadding + bottomPadding, root.maximumHeight))
        popupType: Controls.Popup.Window
        delegate: Entry {}
        background: Surface {
            sourceBackdrop: root.backdrop
            frosted: true
            blurAmount: 1.0
            cornerRadius: 12
        }
        Entry {
            text: qsTranslate("Pedro", "folder.menu.location.copy")
            symbol: "copy"
            onTriggered: root.actionRequested("location")
        }

    }

    Entry {
        visible: root.fileMode && root.imageFile && root.selectionCount <= 1
        text: qsTranslate("Pedro", "file.menu.wallpaper")
        symbol: "image"
        onTriggered: root.actionRequested("wallpaper")
    }

    Divider {
        visible: !root.fileMode && root.selectionCount <= 1
        height: visible ? implicitHeight : 0
    }
    Entry {
        visible: !root.fileMode && root.selectionCount <= 1
        text: qsTranslate("Pedro", "folder.menu.terminal")
        symbol: "terminal"
        onTriggered: root.actionRequested("terminal")
    }

    Divider {}
    Entry {
        text: qsTranslate("Pedro", "folder.menu.properties")
        symbol: "info"
        shortcutText: "Alt+Enter"
        onTriggered: root.actionRequested("properties")
    }

}
