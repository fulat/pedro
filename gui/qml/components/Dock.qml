import QtQuick
import QtQuick as QQ
import QtQuick.Controls.Basic

import "../controllers" as Controllers
import "../scripts/theme.js" as Theme

Item {
    id: dock
    z: 15

    // Connects procedural icon canvases to their drawing controller.
    Controllers.Dock {
        id: controller
    }

    property Item backdrop
    property var shell
    property bool vertical: false
    property real maximumLength: shell ? (vertical ? shell.height - 32 : shell.width - 32) : 0

    width: vertical ? 76 : Math.min(maximumLength, dockLayout.implicitWidth + 34)
    height: vertical ? Math.min(maximumLength, dockLayout.implicitHeight + 34) : 76

    Glass {
        anchors.fill: parent
        backdrop: dock.backdrop
        cornerRadius: 29
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    QQ.Grid {
        id: dockLayout

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenterOffset: dock.vertical ? 4 : 0
        anchors.verticalCenterOffset: dock.vertical ? 0 : 4

        columns: dock.vertical ? 1 : 0
        rows: dock.vertical ? 0 : 1
        spacing: dock.shell ? dock.shell.dockSpacing : 0
        scale: Math.min(1, dock.vertical ? (dock.height - 24) / implicitHeight : (dock.width - 24) / implicitWidth)

        Repeater {
            model: dock.shell ? dock.shell.pinnedApps : []

            delegate: DockEntry {
                required property var modelData

                app: modelData
                onActivated: dock.shell.controller.activateDockApp(modelData, dock.x + dock.width / 2)
            }
        }

        Rectangle {
            width: dock.vertical ? 33 : 1
            height: dock.vertical ? 1 : 33
            color: Theme.dockDivider
        }

        Repeater {
            model: dock.shell ? dock.shell.recentApps : []

            delegate: DockEntry {
                required property var modelData

                app: modelData
                onActivated: dock.shell.controller.activateDockApp(modelData, dock.x + dock.width / 2)
            }
        }
    }

    component DockEntry: Item {
        id: entry

        property var app
        signal activated

        width: dock.shell ? dock.shell.dockTileSize : 0
        height: (dock.shell ? dock.shell.dockTileSize : 0) + 12

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

        DockIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            y: ((dock.shell ? dock.shell.dockTileSize : 0) - height) / 2
            width: dock.shell ? dock.shell.dockTileSize - 4 : 0
            height: width
            kind: entry.app ? entry.app.icon : ""
        }

        Rectangle {
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
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: entry.activated()
        }

        ToolTip.visible: entryMouse.containsMouse
        ToolTip.delay: 500
        ToolTip.text: entry.app ? entry.app.name : ""
    }

    component DockIcon: Item {
        id: icon

        property string kind

        Rectangle {
            visible: icon.kind === "notes"
            anchors.centerIn: parent
            width: icon.width * 0.70
            height: icon.height * 0.84
            radius: 4
            color: Theme.notesBackground
            border.color: Theme.notesBorder

            Column {
                x: parent.width * 0.17
                y: parent.height * 0.27
                spacing: parent.height * 0.12

                Repeater {
                    model: 3
                    delegate: Rectangle {
                        width: icon.width * (index === 2 ? 0.28 : 0.39)
                        height: 1
                        color: Theme.notesLines
                    }
                }
            }
        }

        Rectangle {
            visible: icon.kind === "image"
            anchors.centerIn: parent
            width: icon.width * 0.82
            height: icon.height * 0.68
            radius: 4
            color: Theme.imageIconFrame
            border.width: 2
            border.color: Theme.imageIconFrame
            clip: true

            Image {
                anchors.fill: parent
                anchors.margins: 2
                source: dock.backdrop ? dock.backdrop.source : ""
                sourceSize: Qt.size(64, 48)
                fillMode: Image.PreserveAspectCrop
            }
        }

        Rectangle {
            visible: icon.kind === "chat"
            anchors.centerIn: parent
            width: icon.width * 0.78
            height: width
            radius: 9
            color: Theme.chatIconBackground

            Rectangle {
                x: parent.width * 0.19
                y: parent.height * 0.19
                width: parent.width * 0.35
                height: parent.height * 0.35
                radius: 4
                color: Theme.chatIconGreen
            }

            Rectangle {
                x: parent.width * 0.48
                y: parent.height * 0.19
                width: parent.width * 0.35
                height: parent.height * 0.35
                radius: 4
                color: Theme.chatIconPink
            }

            Rectangle {
                x: parent.width * 0.19
                y: parent.height * 0.48
                width: parent.width * 0.35
                height: parent.height * 0.35
                radius: 4
                color: Theme.chatIconBlue
            }

            Rectangle {
                x: parent.width * 0.48
                y: parent.height * 0.48
                width: parent.width * 0.35
                height: parent.height * 0.35
                radius: 4
                color: Theme.chatIconYellow
            }
        }

        Rectangle {
            visible: icon.kind === "folder"
            x: icon.width * 0.12
            y: icon.height * 0.22
            width: icon.width * 0.48
            height: icon.height * 0.19
            radius: 5
            color: Theme.folderTab
        }

        Rectangle {
            visible: icon.kind === "folder"
            anchors.horizontalCenter: parent.horizontalCenter
            y: icon.height * 0.32
            width: icon.width * 0.78
            height: icon.height * 0.52
            radius: 6
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.folderTop
                }
                GradientStop {
                    position: 1
                    color: Theme.folderBottom
                }
            }
        }

        Rectangle {
            visible: icon.kind === "browser"
            anchors.centerIn: parent
            width: icon.width * 0.82
            height: width
            radius: width / 2
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.browserTop
                }
                GradientStop {
                    position: 0.48
                    color: Theme.browserMiddle
                }
                GradientStop {
                    position: 1
                    color: Theme.browserBottom
                }
            }

            QQ.Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -2
                text: "e"
                color: Theme.browserLetter
                font.pixelSize: parent.width * 0.82
                font.weight: Font.Bold
            }
        }

        Rectangle {
            visible: icon.kind === "code"
            anchors.centerIn: parent
            width: icon.width * 0.78
            height: width
            radius: 10
            color: Theme.codeIconBackground
        }

        Canvas {
            id: codeCanvas
            visible: icon.kind === "code"
            anchors.centerIn: parent
            width: icon.width * 0.78
            height: width
            onPaint: controller.paintCode(codeCanvas)
        }

        Item {
            visible: icon.kind === "design"
            anchors.centerIn: parent
            width: icon.width * 0.56
            height: icon.height * 0.78

            Rectangle {
                x: 0
                y: 0
                width: parent.width / 2
                height: parent.height / 3
                radius: height / 2
                color: Theme.designOrange
            }
            Rectangle {
                x: parent.width / 2
                y: 0
                width: parent.width / 2
                height: parent.height / 3
                radius: height / 2
                color: Theme.designCoral
            }
            Rectangle {
                x: 0
                y: parent.height / 3
                width: parent.width / 2
                height: parent.height / 3
                radius: height / 2
                color: Theme.designPurple
            }
            Rectangle {
                x: parent.width / 2
                y: parent.height / 3
                width: parent.width / 2
                height: parent.height / 3
                radius: height / 2
                color: Theme.designBlue
            }
            Rectangle {
                x: 0
                y: parent.height * 2 / 3
                width: parent.width / 2
                height: parent.height / 3
                radius: height / 2
                color: Theme.designGreen
            }
        }

        Rectangle {
            visible: icon.kind === "terminal"
            anchors.centerIn: parent
            width: icon.width * 0.82
            height: width
            radius: 9
            color: Theme.terminalIconBackground

            QQ.Text {
                anchors.centerIn: parent
                text: ">_"
                color: Theme.terminalIconText
                font.family: "monospace"
                font.pixelSize: parent.width * 0.46
                font.weight: Font.Bold
            }
        }

        Rectangle {
            visible: icon.kind === "music"
            anchors.centerIn: parent
            width: icon.width * 0.82
            height: width
            radius: width / 2
            color: Theme.musicIconBackground

            Canvas {
                id: musicCanvas
                anchors.fill: parent
                onPaint: controller.paintMusic(musicCanvas)
            }
        }

        Rectangle {
            visible: icon.kind === "photos"
            anchors.centerIn: parent
            width: icon.width * 0.8
            height: width
            radius: 11
            color: Theme.photosBackground

            Repeater {
                model: Theme.photosPalette

                delegate: Rectangle {
                    required property int index
                    required property string modelData

                    x: parent.width / 2 + Math.sin(index * Math.PI / 3) * parent.width * 0.19 - width / 2
                    y: parent.height / 2 - Math.cos(index * Math.PI / 3) * parent.height * 0.19 - height / 2
                    width: parent.width * 0.26
                    height: parent.height * 0.39
                    radius: width / 2
                    rotation: index * 60
                    color: modelData
                    opacity: 0.86
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.18
                height: width
                radius: width / 2
                color: Theme.photosCenter
            }
        }

        Item {
            visible: icon.kind === "trash"
            anchors.centerIn: parent
            width: icon.width * 0.70
            height: icon.height * 0.92

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: parent.width * 0.79
                height: parent.height * 0.82
                radius: 5
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Theme.trashTop
                    }
                    GradientStop {
                        position: 1
                        color: Theme.trashBottom
                    }
                }
                border.color: Theme.trashBorder
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: parent.width
                height: parent.height * 0.12
                radius: 3
                color: Theme.trashLid
                border.color: Theme.trashBorder
            }
        }
    }
}
