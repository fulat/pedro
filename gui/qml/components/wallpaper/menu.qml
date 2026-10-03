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
    property string sortKey: "name"
    property bool canPaste: false
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

        property string symbol: subMenu === organizationMenu ? "organization" : ""
        property string shortcutText: ""
        property bool selectionOption: false

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
                text: entry.subMenu ? "›" : entry.selectionOption ? "" : entry.checked ? "✓" : entry.shortcutText
                color: Theme.textMuted
                font.pixelSize: 12
                horizontalAlignment: Text.AlignRight
                opacity: entry.enabled ? 1 : 0.4

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: entry.selectionOption
                    width: 16
                    height: 16
                    radius: 8
                    color: entry.checked ? Theme.overlayHover : "transparent"
                    border.width: 1
                    border.color: entry.checked ? Theme.textMuted : Theme.cardBorderStrong
                    antialiasing: true

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    Behavior on border.color {
                        ColorAnimation { duration: 120 }
                    }

                    Controls.Label {
                        anchors.fill: parent
                        text: "✓"
                        color: Theme.white
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        opacity: entry.checked ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: 120 }
                        }
                    }
                }
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
        text: qsTranslate("Pedro", "desktop.menu.folder")
        symbol: "folder"
        onTriggered: root.actionRequested("folder")
    }

    Entry {
        text: qsTranslate("Pedro", "desktop.menu.file")
        symbol: "file"
        onTriggered: root.actionRequested("file")
    }

    Entry {
        text: qsTranslate("Pedro", "folder.menu.paste")
        symbol: "paste"
        visible: root.canPaste
        enabled: root.canPaste
        onTriggered: root.actionRequested("paste")
    }

    Divider {}
    Entry {
        text: qsTranslate("Pedro", "desktop.menu.select")
        symbol: "free"
        onTriggered: root.actionRequested("select")
    }

    Controls.Menu {
        id: organizationMenu
        title: qsTranslate("Pedro", "desktop.menu.organization")
        width: 250
        padding: 6
        popupType: Controls.Popup.Item
        delegate: Entry {}
        background: Glass {}

        Entry {
            text: qsTranslate("Pedro", "desktop.menu.grid")
            symbol: "grid"
            selectionOption: true
            checked: root.organization === "grid"
            onTriggered: root.actionRequested("grid")
        }
        Entry {
            text: qsTranslate("Pedro", "desktop.menu.stack")
            symbol: "stack"
            selectionOption: true
            checked: root.organization === "stack"
            onTriggered: root.actionRequested("stack")
        }
        Entry {
            text: qsTranslate("Pedro", "desktop.menu.free")
            symbol: "free"
            selectionOption: true
            checked: root.organization === "free"
            onTriggered: root.actionRequested("free")
        }
        Divider {}
        Entry {
            text: qsTranslate("Pedro", "desktop.menu.name")
            symbol: "sort"
            selectionOption: true
            checked: root.sortKey === "name"
            onTriggered: root.actionRequested("name")
        }
        Entry {
            text: qsTranslate("Pedro", "desktop.menu.type")
            symbol: "tag"
            selectionOption: true
            checked: root.sortKey === "type"
            onTriggered: root.actionRequested("type")
        }
        Entry {
            text: qsTranslate("Pedro", "desktop.menu.date")
            symbol: "calendar"
            selectionOption: true
            checked: root.sortKey === "date"
            onTriggered: root.actionRequested("date")
        }
        Entry {
            text: qsTranslate("Pedro", "desktop.menu.size")
            symbol: "size"
            selectionOption: true
            checked: root.sortKey === "size"
            onTriggered: root.actionRequested("size")
        }
    }

    Divider {}
    Entry {
        text: qsTranslate("Pedro", "desktop.menu.display")
        symbol: "display"
        onTriggered: root.actionRequested("display")
    }

    Entry {
        text: qsTranslate("Pedro", "desktop.menu.widgets")
        symbol: "widgets"
        onTriggered: root.actionRequested("widgets")
    }
}
