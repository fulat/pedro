import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

import "../menu" as Menu
import "../status" as Status
import "../logic/clock.js" as Clock
import "../logic/pixel.js" as Pixel
import "../logic/theme.js" as Theme

Item {
    id: root

    property int windowWidth
    property date currentTime
    property string activeSource: ""
    property real preferredExpandedWidth: 1030

    signal panelRequested(string mode, real anchorX, string source)
    signal desktopRequested

    readonly property real barHeight: 48
    readonly property real notchCollapsedWidth: Math.max(350, Math.min(350, width * 0.25))
    readonly property real notchExpandedHeight: 130
    readonly property real notchMaximumExpandedWidth: notchExpandedHeight * 828 / 110
    readonly property real notchExpandedWidth: Math.max(notchCollapsedWidth, Math.min(preferredExpandedWidth, notchMaximumExpandedWidth))
    readonly property bool notchExpanded: notchHover.hovered
    readonly property real notchWidth: notchExpanded ? notchExpandedWidth : notchCollapsedWidth
    readonly property real notchHeight: notchExpanded ? notchExpandedHeight : barHeight
    readonly property real notchHorizontalPadding: 40
    readonly property real notchExpandedHorizontalPadding: 100
    readonly property real notchTopPadding: 3
    readonly property real notchBottomPadding: 3
    readonly property int notchAnimationDuration: 500
    readonly property int notchAnimationEasing: Easing.InOutCubic

    height: notchHeight

    Behavior on height {
        NumberAnimation {
            duration: root.notchAnimationDuration
            easing.type: root.notchAnimationEasing
        }
    }

    function requestPanel(mode, sourceName, item) {
        const point = item.mapToItem(root, item.width / 2, item.height);

        root.panelRequested(mode, point.x, sourceName);
    }

    Item {
        id: notch

        readonly property real contentPadding: root.notchExpanded ? root.notchExpandedHorizontalPadding : root.notchHorizontalPadding
        readonly property real contentWidth: width - contentPadding * 2
        readonly property real sectionSpacing: 12
        readonly property real sectionWidth: (contentWidth - sectionSpacing * 2) / 3

        z: 1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.notchWidth
        height: root.notchHeight

        Behavior on width {
            NumberAnimation {
                duration: root.notchAnimationDuration
                easing.type: root.notchAnimationEasing
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: root.notchAnimationDuration
                easing.type: root.notchAnimationEasing
            }
        }

        Image {
            anchors.fill: parent
            source: "../../assets/notch.svg"
            sourceSize: Qt.size(Pixel.physical(width, Screen.devicePixelRatio), Pixel.physical(height, Screen.devicePixelRatio))
            fillMode: Image.Stretch
            opacity: 0.86
            smooth: true
            mipmap: false
            cache: true
        }

        Label {
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            text: Clock.format(root.currentTime)
            color: Theme.textPrimary
            font.pixelSize: Theme.fontMedium
            font.weight: Font.Bold
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
        }

        // Player {
        //     id: player
        //
        //     z: 1
        //     anchors.left: parent.left
        //     anchors.leftMargin: notch.contentPadding
        //     anchors.top: parent.top
        //     anchors.topMargin: root.notchExpanded ? 38 : root.notchTopPadding
        //     width: root.notchExpanded ? notch.sectionWidth : notch.contentWidth
        //     height: root.notchExpanded ? 96 : root.barHeight - root.notchTopPadding - root.notchBottomPadding
        //     expanded: root.notchExpanded
        //
        //     Behavior on width {
        //         NumberAnimation {
        //             duration: root.notchAnimationDuration
        //             easing.type: root.notchAnimationEasing
        //         }
        //     }
        //
        //     Behavior on height {
        //         NumberAnimation {
        //             duration: root.notchAnimationDuration
        //             easing.type: root.notchAnimationEasing
        //         }
        //     }
        //
        //     Behavior on y {
        //         NumberAnimation {
        //             duration: root.notchAnimationDuration
        //             easing.type: root.notchAnimationEasing
        //         }
        //     }
        //
        //     Behavior on x {
        //         NumberAnimation {
        //             duration: root.notchAnimationDuration
        //             easing.type: root.notchAnimationEasing
        //         }
        //     }
        // }
        //
        // Item {
        //     id: centerSection
        //
        //     x: notch.contentPadding + notch.sectionWidth + notch.sectionSpacing
        //     y: 38
        //     width: notch.sectionWidth
        //     height: 96
        //     visible: root.notchExpanded
        //     clip: true
        // }
        //
        // Item {
        //     id: rightSection
        //
        //     x: notch.contentPadding + (notch.sectionWidth + notch.sectionSpacing) * 2
        //     y: 38
        //     width: notch.sectionWidth
        //     height: 96
        //     visible: root.notchExpanded
        //     clip: true
        // }

        HoverHandler {
            id: notchHover
        }
    }

    Item {
        id: leftZone

        anchors.left: parent.left
        anchors.right: notch.left
        anchors.top: parent.top
        anchors.rightMargin: 8
        height: root.barHeight
        clip: true

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            spacing: 2

            Menu.Button {
                id: systemButton

                highlighted: root.activeSource === "system"
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                Layout.rightMargin: 7
                leftPadding: 5
                rightPadding: 7
                topPadding: 4
                bottomPadding: 4
                onClicked: root.requestPanel("system", "system", systemButton)

                contentItem: RowLayout {
                    Image {
                        Layout.preferredWidth: 27
                        Layout.preferredHeight: 27
                        source: "../../assets/logo.png"
                        sourceSize: Qt.size(Pixel.physical(width, Screen.devicePixelRatio), Pixel.physical(height, Screen.devicePixelRatio))
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: false
                        cache: true
                    }
                }
            }

            Menu.Button {
                text: "Escritorio"
                onClicked: root.desktopRequested()
            }

            Menu.Button {
                id: filesButton
                highlighted: root.activeSource === "files"
                text: "Archivos"
                onClicked: root.requestPanel("files", "files", filesButton)
            }

            Menu.Button {
                id: editButton
                highlighted: root.activeSource === "edit"
                text: "Editar"
                visible: root.windowWidth >= 1180
                onClicked: root.requestPanel("about", "edit", editButton)
            }

            Menu.Button {
                id: viewButton
                highlighted: root.activeSource === "view"
                text: "Vista"
                visible: root.windowWidth >= 1320
                onClicked: root.requestPanel("about", "view", viewButton)
            }

            Menu.Button {
                id: windowButton
                highlighted: root.activeSource === "window"
                text: "Ventana"
                visible: root.windowWidth >= 1460
                onClicked: root.requestPanel("about", "window", windowButton)
            }

            Menu.Button {
                id: helpButton
                highlighted: root.activeSource === "help"
                text: "Ayuda"
                visible: root.windowWidth >= 1600
                onClicked: root.requestPanel("about", "help", helpButton)
            }

            Item {
                Layout.fillWidth: true
            }
        }
    }

    Item {
        id: rightZone

        anchors.left: notch.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 8
        height: root.barHeight
        clip: true

        RowLayout {
            anchors.fill: parent
            anchors.rightMargin: 15
            spacing: 5

            Item {
                Layout.fillWidth: true
            }

            Status.Button {
                id: searchButton
                highlighted: root.activeSource === "search"
                kind: "search"
                description: "Buscar"
                onActivated: root.requestPanel("about", "search", searchButton)
            }

            Status.Button {
                id: displayButton
                highlighted: root.activeSource === "display"
                kind: "display"
                description: "Centro de control"
                onActivated: root.requestPanel("quick", "display", displayButton)
            }

            Status.Button {
                id: wifiButton
                highlighted: root.activeSource === "wifi"
                kind: "wifi"
                description: "Wi-Fi"
                onActivated: root.requestPanel("wifi", "wifi", wifiButton)
            }

            Status.Button {
                id: bluetoothButton
                highlighted: root.activeSource === "bluetooth"
                kind: "bluetooth"
                description: "Bluetooth"
                onActivated: root.requestPanel("bluetooth", "bluetooth", bluetoothButton)
            }

            Status.Button {
                id: soundButton
                highlighted: root.activeSource === "sound"
                kind: "sound"
                description: "Sonido"
                onActivated: root.requestPanel("sound", "sound", soundButton)
            }

            Status.Button {
                id: batteryButton
                highlighted: root.activeSource === "battery"
                kind: "battery"
                description: "Centro de control"
                visible: root.windowWidth >= 1180
                onActivated: root.requestPanel("quick", "battery", batteryButton)
            }

            // Label {
            //     Layout.leftMargin: 8
            //     Layout.rightMargin: 8
            //     text: Clock.format(root.currentTime)
            //     color: Theme.textPrimary
            //     font.pixelSize: Theme.fontSmall
            //     font.weight: Font.Medium
            // }

            Rectangle {
                id: profileButton

                Layout.preferredWidth: 29
                Layout.preferredHeight: 29
                radius: width / 2
                color: "#263244"
                border.color: "#88ffffff"

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: root.activeSource === "profile" ? "#0dffffff" : "transparent"
                }

                Label {
                    anchors.centerIn: parent
                    text: "P"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSmall
                    font.weight: Font.Bold
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestPanel("quick", "profile", profileButton)
                }
            }
        }
    }
}
