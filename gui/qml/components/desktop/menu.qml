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
    property bool fileMode: false
    property bool imageFile: false

    signal actionRequested(string action)

    width: 304
    height: Math.min(contentItem.implicitHeight + topPadding + bottomPadding, maximumHeight)
    padding: 6
    popupType: Controls.Popup.Item
    cascade: true

    background: Components.Liquid {
        backdrop: root.backdrop
        frosted: true
        blurAmount: 1.0
        cornerRadius: 12
    }

    delegate: Entry {}

    component Entry: Controls.MenuItem {
        id: entry

        property string symbol: subMenu === openWithMenu ? "tab" : subMenu === compressionMenu ? "archive" : subMenu === sharingMenu ? "share" : ""
        property string shortcutText: ""

        hoverEnabled: true
        visible: subMenu !== openWithMenu || root.fileMode
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
        text: "Abrir"
        symbol: root.fileMode ? "file" : "folder"
        shortcutText: "Enter"
        onTriggered: root.actionRequested("open")
    }

    Entry {
        visible: !root.fileMode
        text: "Abrir en una pestaña nueva"
        symbol: "tab"
        onTriggered: root.actionRequested("tab")
    }

    Entry {
        visible: !root.fileMode
        text: "Abrir en una ventana nueva"
        symbol: "window"
        onTriggered: root.actionRequested("window")
    }

    Controls.Menu {
        id: openWithMenu
        title: "Abrir con…"
        width: 210
        popupType: Controls.Popup.Item
        delegate: Entry {}
        background: Components.Liquid {
            backdrop: root.backdrop
            frosted: true
            blurAmount: 1.0
            cornerRadius: 12
        }
        Entry {
            text: "Elegir otra aplicación…"
            symbol: "window"
            onTriggered: root.actionRequested("application")
        }
    }

    Entry {
        visible: root.fileMode
        text: "Vista rápida"
        symbol: "eye"
        shortcutText: "Espacio"
        onTriggered: root.actionRequested("preview")
    }

    Divider {}
    Entry {
        text: "Cortar"
        symbol: "cut"
        shortcutText: "Ctrl+X"
        onTriggered: root.actionRequested("cut")
    }

    Entry {
        text: "Copiar"
        symbol: "copy"
        shortcutText: "Ctrl+C"
        onTriggered: root.actionRequested("copy")
    }

    Entry {
        text: "Pegar"
        symbol: "paste"
        shortcutText: "Ctrl+V"
        enabled: root.canPaste
        onTriggered: root.actionRequested("paste")
    }

    Divider {}
    Entry {
        text: "Renombrar"
        symbol: "rename"
        shortcutText: "F2"
        onTriggered: root.actionRequested("rename")
    }

    Entry {
        visible: root.fileMode
        text: "Duplicar"
        symbol: "copy"
        shortcutText: "Ctrl+D"
        onTriggered: root.actionRequested("duplicate")
    }

    Entry {
        text: "Mover a la papelera"
        symbol: "trash"
        shortcutText: "Delete"
        onTriggered: root.actionRequested("trash")
    }

    Divider {}

    Controls.Menu {
        id: compressionMenu
        title: "Comprimir"
        width: 210
        popupType: Controls.Popup.Item
        delegate: Entry {}
        background: Components.Liquid {
            backdrop: root.backdrop
            frosted: true
            blurAmount: 1.0
            cornerRadius: 12
        }
        Entry {
            text: "Archivo .zip"
            symbol: "file"
            onTriggered: root.actionRequested("zip")
        }

        Entry {
            text: "Archivo .tar.gz"
            symbol: "file"
            onTriggered: root.actionRequested("gzip")
        }

        Entry {
            text: "Archivo .tar.xz"
            symbol: "file"
            onTriggered: root.actionRequested("xz")
        }

        Entry {
            text: "Otro formato…"
            symbol: "file"
            onTriggered: root.actionRequested("archive")
        }

    }

    Controls.Menu {
        id: sharingMenu
        title: "Compartir"
        width: 210
        popupType: Controls.Popup.Item
        delegate: Entry {}
        background: Components.Liquid {
            backdrop: root.backdrop
            frosted: true
            blurAmount: 1.0
            cornerRadius: 12
        }
        Entry {
            text: "Copiar ubicación"
            symbol: "copy"
            onTriggered: root.actionRequested("location")
        }

    }

    Entry {
        visible: root.fileMode && root.imageFile
        text: "Establecer como fondo"
        symbol: "image"
        onTriggered: root.actionRequested("wallpaper")
    }

    Divider {
        visible: !root.fileMode
        height: visible ? implicitHeight : 0
    }
    Entry {
        visible: !root.fileMode
        text: "Abrir en Terminal"
        symbol: "terminal"
        onTriggered: root.actionRequested("terminal")
    }

    Divider {}
    Entry {
        text: "Propiedades"
        symbol: "info"
        shortcutText: "Alt+Enter"
        onTriggered: root.actionRequested("properties")
    }

}
