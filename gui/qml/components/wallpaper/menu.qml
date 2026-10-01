pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls
import "../icon" as Icon
import ".." as Components
import "../../scripts/theme.js" as Theme

Controls.Menu {
    id: root

    property Item backdrop
    property string organization: "grid"
    property bool keepAligned: true
    property string shortcutName
    signal actionRequested(string action)

    width: 270
    padding: 6
    popupType: Controls.Popup.Item
    cascade: true

    component Glass: Components.Liquid {
        backdrop: root.backdrop
        frosted: true
        blurAmount: 1.0
        cornerRadius: 12
    }

    background: Glass {}
    delegate: Entry {}

    component Entry: Controls.MenuItem {
        id: entry

        property string symbol: subMenu === organizationMenu ? "organization" : subMenu === widgetsMenu ? "widgets" : ""
        property string shortcutText: ""

        hoverEnabled: true
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
                width: Math.max(0, entry.availableWidth - 66)
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
                width: 24
                text: entry.subMenu ? "›" : entry.checked ? "✓" : entry.shortcutText
                color: Theme.textMuted
                font.pixelSize: 12
                horizontalAlignment: Text.AlignRight
                opacity: entry.enabled ? 1 : 0.4
            }
        }

        indicator: Item {}
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
        text: "Nueva carpeta"
        symbol: "folder"
        onTriggered: root.actionRequested("folder")
    }

    Entry {
        text: "Nuevo archivo"
        symbol: "file"
        onTriggered: root.actionRequested("file")
    }

    Controls.Menu {
        id: organizationMenu
        title: "Organización"
        width: 250
        padding: 6
        popupType: Controls.Popup.Item
        delegate: Entry {}
        background: Glass {}

        Entry {
            text: "Cuadrícula"
            symbol: "grid"
            checked: root.organization === "grid"
            onTriggered: root.actionRequested("grid")
        }
        Entry {
            text: "Pila"
            symbol: "stack"
            checked: root.organization === "stack"
            onTriggered: root.actionRequested("stack")
        }
        Entry {
            text: "Libre"
            symbol: "free"
            checked: root.organization === "free"
            onTriggered: root.actionRequested("free")
        }
        Divider {}
        Entry {
            text: "Agrupar por nombre"
            symbol: "sort"
            onTriggered: root.actionRequested("name")
        }
        Entry {
            text: "Agrupar por tipo"
            symbol: "tag"
            onTriggered: root.actionRequested("type")
        }
        Entry {
            text: "Agrupar por fecha"
            symbol: "calendar"
            onTriggered: root.actionRequested("date")
        }
        Divider {}
        Entry {
            text: "Mantener alineado"
            symbol: "align"
            checked: root.keepAligned
            onTriggered: root.actionRequested("align")
        }
    }

    Divider {}
    Entry {
        text: "Ajustes de pantalla"
        symbol: "display"
        onTriggered: root.actionRequested("display")
    }

    Controls.Menu {
        id: widgetsMenu
        title: "Widgets"
        width: 200
        padding: 6
        popupType: Controls.Popup.Item
        delegate: Entry {}
        background: Glass {}
        Entry {
            text: "Clima"
            symbol: "weather"
            onTriggered: root.actionRequested("weather")
        }
    }
}
