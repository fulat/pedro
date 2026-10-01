import QtQuick
import QtQuick as QQ
import QtQuick.Controls.Basic

import "application" as Application
import "desktop" as Desktop
import "../controllers" as Controllers
import "../scripts/theme.js" as Theme

// Draws the dock from controller-provided application data.
Item {
    id: dock
    z: 15

    property Item backdrop
    property var shell
    property bool vertical: false
    property real hoverScale: Backend.dockHoverScale
    readonly property real pressScale: hoverScale + 0.08
    readonly property real horizontalPadding: 16
    property real maximumLength: shell ? (vertical ? shell.height - 32 : shell.width - 32) : 0

    width: vertical ? 48 : Math.min(maximumLength, dockLayout.implicitWidth + horizontalPadding * 2)
    height: vertical ? Math.min(maximumLength, dockLayout.implicitHeight + 20) : 48

    // Owns the favorite mutation requested by the presentation.
    Controllers.Dock {
        id: controller
    }

    // Uses the shared wallpaper-independent liquid surface.
    Liquid {
        anchors.fill: parent
        backdrop: dock.backdrop
        cornerRadius: 28
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
        scale: Math.max(0, Math.min(1, dock.vertical ? (dock.height - 20) / Math.max(1, implicitHeight) : (dock.width - dock.horizontalPadding * 2) / Math.max(1, implicitWidth)))

        Repeater {
            model: dock.shell ? [{id: "pedro-files", name: qsTranslate("Pedro", "app.files.name"), native: true, running: dock.shell.filesQuickWindowVisible}].concat(dock.shell.pinnedApps) : []

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

        Item {
            id: entryTile

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: dock.shell ? dock.shell.dockTileSize : 0
            height: width
        }

        Timer {
            id: pressFeedback
            interval: 160
        }

        Application.Icon {
            id: dockIcon

            anchors.centerIn: entryTile
            width: dock.shell ? dock.shell.dockIconSize : 0
            height: width
            name: entry.app ? entry.app.icon || "" : ""
            visible: !entry.app.native
            readonly property bool showingPress: pressFeedback.running || (entryMouse.pressed && (entryMouse.pressedButtons & Qt.LeftButton) !== 0)
            scale: showingPress ? dock.pressScale : entryMouse.containsMouse ? dock.hoverScale : 1

            Behavior on scale {
                NumberAnimation { duration: dockIcon.showingPress ? 90 : 180; easing.type: Easing.InOutQuad }
            }
        }

        Desktop.Icon {
            anchors.centerIn: entryTile
            width: dockIcon.width / 0.78
            height: width
            kind: "folder"
            cornerRadius: 3
            visible: entry.app.native === true
            scale: dockIcon.scale
        }

        Rectangle {
            visible: entry.app ? entry.app.running : false
            anchors.bottom: dock.vertical ? undefined : entryTile.bottom
            anchors.right: dock.vertical ? entryTile.right : undefined
            anchors.horizontalCenter: dock.vertical ? undefined : entryTile.horizontalCenter
            anchors.verticalCenter: dock.vertical ? entryTile.verticalCenter : undefined
            anchors.bottomMargin: dock.vertical ? 0 : -2
            anchors.rightMargin: dock.vertical ? 5 : 0
            width: 3
            height: 3
            radius: 2
            color: Theme.dockIndicator
        }

        MouseArea {
            id: entryMouse

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    if (!entry.app.native) {
                        favoriteMenu.popup(mouse.x, mouse.y);
                    }
                } else {
                    pressFeedback.restart();
                    if (entry.app.native) {
                        dock.shell.controller.openFilesQuickWindow();
                    } else {
                        controller.launchApplication(entry.app);
                    }
                }
            }
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

                text: entry.app && entry.app.pinned ? qsTranslate("Pedro", "dock.unpin") : qsTranslate("Pedro", "dock.pin")
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
