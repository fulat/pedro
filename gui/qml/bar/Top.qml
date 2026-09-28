import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects

import "../icon" as Icon
import "../logic/clock.js" as Clock

Item {
    id: root

    property int windowWidth
    property date currentTime
    property string activeSource: ""

    signal panelRequested(string mode, real anchorX, string source)
    signal desktopRequested

    readonly property real barHeight: 64

    height: barHeight

    function requestPanel(mode, sourceName, item) {
        const point = item.mapToItem(root, item.width / 2, item.height);
        root.panelRequested(mode, point.x, sourceName);
    }

    Item {
        id: logoButton

        x: 22
        y: 5
        width: 54
        height: 54

        MattePill {
            anchors.fill: parent
            cornerRadius: logoButton.width / 2
            softShadow: true
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: logoMouse.containsMouse ? "#16ffffff" : "transparent"

            Behavior on color {
                ColorAnimation { duration: 140 }
            }
        }

        Image {
            anchors.centerIn: parent
            width: 34
            height: 34
            source: "../../assets/logo.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
            layer.enabled: true
            layer.effect: MultiEffect {
                colorization: 1
                colorizationColor: "#ffffff"
            }
        }

        MouseArea {
            id: logoMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.requestPanel("system", "system", logoButton)
        }

        ToolTip.visible: logoMouse.containsMouse
        ToolTip.delay: 500
        ToolTip.text: "Pedro OS"
    }

    Item {
        id: statusPill

        anchors.top: parent.top
        anchors.topMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 20
        width: statusRow.width + 24
        height: 48

        MattePill {
            anchors.fill: parent
            cornerRadius: 24
        }

        Row {
            id: statusRow

            anchors.centerIn: parent
            spacing: 8

            TopAction {
                id: searchButton
                icon: "../../assets/icons/search.svg"
                description: "Buscar"
                highlighted: root.activeSource === "search"
                onActivated: root.requestPanel("about", "search", searchButton)
            }

            Rectangle {
                width: 1
                height: 24
                y: (statusRow.height - height) / 2
                color: "#55ffffff"
            }

            Item {
                id: notificationsButton
                width: 32
                height: 38

                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: notificationMouse.containsMouse ? "#26ffffff" : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: 140 }
                    }
                }

                Canvas {
                    anchors.centerIn: parent
                    width: 21
                    height: 23
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = "#ffffff";
                        ctx.beginPath();
                        ctx.moveTo(4, 17);
                        ctx.quadraticCurveTo(6, 15, 6, 10);
                        ctx.quadraticCurveTo(6, 3, 10.5, 3);
                        ctx.quadraticCurveTo(15, 3, 15, 10);
                        ctx.quadraticCurveTo(15, 15, 17, 17);
                        ctx.closePath();
                        ctx.fill();
                        ctx.beginPath();
                        ctx.arc(10.5, 20, 2, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }

                Rectangle {
                    width: 5
                    height: 5
                    radius: 3
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: 2
                    anchors.topMargin: 4
                    color: "#9ec8ff"
                }

                MouseArea {
                    id: notificationMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestPanel("quick", "notifications", notificationsButton)
                }
            }

            Rectangle {
                id: controlButton
                width: 34
                height: 34
                y: (statusRow.height - height) / 2
                radius: 17
                color: controlMouse.containsMouse ? "#67413a5a" : "#5d28264a"
                border.width: 1
                border.color: "#609dbbff"

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    radius: 10
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#6aeaff" }
                        GradientStop { position: 0.48; color: "#7948ff" }
                        GradientStop { position: 1; color: "#1445c8" }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 11
                        height: 11
                        radius: 6
                        color: "#392ea0"
                        border.color: "#c9f4ff"
                    }
                }

                MouseArea {
                    id: controlMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestPanel("quick", "control", controlButton)
                }
            }

            TopAction {
                id: wifiButton
                icon: "../../assets/icons/wifi.svg"
                description: "Wi-Fi"
                highlighted: root.activeSource === "wifi"
                onActivated: root.requestPanel("wifi", "wifi", wifiButton)
            }

            Text {
                visible: root.windowWidth >= 760
                y: (statusRow.height - height) / 2
                text: "87%"
                color: "#ffffff"
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            Text {
                visible: root.windowWidth >= 970
                y: (statusRow.height - height) / 2
                text: Clock.format(root.currentTime).split("   ")[0]
                color: "#ffffff"
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            Text {
                y: (statusRow.height - height) / 2
                text: Qt.formatTime(root.currentTime, "HH:mm")
                color: "#ffffff"
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Rectangle {
                id: profileButton
                width: 36
                height: 36
                y: (statusRow.height - height) / 2
                radius: 18
                color: profileMouse.containsMouse ? "#80666666" : "#555555"
                border.width: 1
                border.color: "#74ffffff"

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }

                Image {
                    anchors.centerIn: parent
                    width: 25
                    height: 25
                    source: "../../assets/logo.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        colorization: 1
                        colorizationColor: "#ffffff"
                    }
                }

                MouseArea {
                    id: profileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestPanel("quick", "profile", profileButton)
                }
            }
        }
    }

    component MattePill: Item {
        id: surface

        property real cornerRadius: 24
        property bool softShadow: false

        Rectangle {
            visible: !surface.softShadow
            x: -6
            y: 5
            width: surface.width + 12
            height: surface.height + 4
            radius: surface.cornerRadius + 6
            color: "#18000000"
        }

        Rectangle {
            x: surface.softShadow ? -2 : -3
            y: surface.softShadow ? 2 : 3
            width: surface.width + (surface.softShadow ? 4 : 6)
            height: surface.height + 2
            radius: surface.cornerRadius + (surface.softShadow ? 2 : 3)
            color: surface.softShadow ? "#14000000" : "#2a000000"
        }

        Rectangle {
            anchors.fill: parent
            radius: surface.cornerRadius
            gradient: Gradient {
                GradientStop { position: 0; color: "#e8383838" }
                GradientStop { position: 0.55; color: "#e82c2c2c" }
                GradientStop { position: 1; color: "#e8202020" }
            }
            border.width: 1
            border.color: "#526f6f6f"
        }
    }

    component TopAction: Item {
        id: action

        property url icon
        property string description
        property bool highlighted: false
        signal activated()

        width: 32
        height: 38

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: action.highlighted || actionMouse.containsMouse ? "#26ffffff" : "transparent"

            Behavior on color {
                ColorAnimation { duration: 140 }
            }
        }

        Icon.Tinted {
            anchors.centerIn: parent
            width: 22
            height: 22
            source: action.icon
            tint: "#ffffff"
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: action.activated()
        }

        ToolTip.visible: actionMouse.containsMouse
        ToolTip.delay: 500
        ToolTip.text: action.description
    }
}
