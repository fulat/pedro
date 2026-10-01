import QtQuick
import QtQuick as QQ
import QtQuick.Controls.Basic

import "application" as Application
import "../controllers" as Controllers
import "../scripts/theme.js" as Theme

// Draws the dock from controller-provided application data.
Item {
    id: dock
    z: 15

    property Item backdrop
    property var shell
    property bool vertical: false
    property real maximumLength: shell ? (vertical ? shell.height - 32 : shell.width - 32) : 0

    width: vertical ? 48 : Math.min(maximumLength, dockLayout.implicitWidth + 20)
    height: vertical ? Math.min(maximumLength, dockLayout.implicitHeight + 20) : 48

    // Owns the favorite mutation requested by the presentation.
    Controllers.Dock {
        id: controller
    }

    // Uses the shared wallpaper-independent liquid surface.
    Liquid {
        anchors.fill: parent
        backdrop: dock.backdrop
        cornerRadius: 18
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    QQ.Grid {
        id: dockLayout

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenterOffset: dock.vertical ? 2 : 0
        anchors.verticalCenterOffset: dock.vertical ? 0 : 2

        columns: dock.vertical ? 1 : 0
        rows: dock.vertical ? 0 : 1
        spacing: dock.shell ? dock.shell.dockSpacing : 0
        scale: Math.max(0, Math.min(1, dock.vertical ? (dock.height - 20) / Math.max(1, implicitHeight) : (dock.width - 20) / Math.max(1, implicitWidth)))

        Repeater {
            model: dock.shell ? dock.shell.pinnedApps : []

            delegate: DockEntry {
                required property var modelData

                app: modelData
            }
        }
    }

    component DockEntry: Item {
        id: entry

        property var app

        width: dock.shell ? dock.shell.dockTileSize : 0
        height: (dock.shell ? dock.shell.dockTileSize : 0) + 8

        Rectangle {
            id: entryTile

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: dock.shell ? dock.shell.dockTileSize : 0
            height: width
            radius: 13
            color: entryMouse.containsMouse ? Theme.actionHover : "transparent"
            border.width: entryMouse.containsMouse ? 1 : 0
            border.color: Theme.cardBorderStrong

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }
        }

        Application.Icon {
            anchors.centerIn: entryTile
            width: dock.shell ? dock.shell.dockIconSize : 0
            height: width
            name: entry.app ? entry.app.icon : ""
        }

        Rectangle {
            visible: entry.app ? entry.app.running : false
            anchors.bottom: dock.vertical ? undefined : entryTile.bottom
            anchors.right: dock.vertical ? entryTile.right : undefined
            anchors.horizontalCenter: dock.vertical ? undefined : entryTile.horizontalCenter
            anchors.verticalCenter: dock.vertical ? entryTile.verticalCenter : undefined
            anchors.bottomMargin: dock.vertical ? 0 : -5
            anchors.rightMargin: dock.vertical ? 5 : 0
            width: 3
            height: 3
            radius: 2
            color: Theme.dockIndicator
        }

        MouseArea {
            id: entryMouse

            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => favoriteMenu.popup(mouse.x, mouse.y)
        }

        Menu {
            id: favoriteMenu

            width: 190
            padding: 6

            background: Liquid {
                backdrop: dock.backdrop
                frosted: true
                cornerRadius: 12
            }

            MenuItem {
                id: favoriteAction

                text: entry.app && entry.app.pinned ? qsTr("Quitar del dock") : qsTr("Mantener en el dock")
                leftPadding: 12
                rightPadding: 12
                topPadding: 9
                bottomPadding: 9

                contentItem: Label {
                    text: favoriteAction.text
                    color: Theme.white
                    font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    radius: 7
                    color: favoriteAction.down ? Theme.overlayPressed : favoriteAction.hovered ? Theme.overlayHover : "transparent"
                }

                onTriggered: controller.setPinned(entry.app, !entry.app.pinned)
            }
        }

        ToolTip.visible: entryMouse.containsMouse
        ToolTip.delay: 500
        ToolTip.text: entry.app ? entry.app.name : ""
    }
}
