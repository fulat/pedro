import QtQuick
import QtQuick as Quick
import QtQuick.Controls.Basic
import QtQuick.Effects

import "../controllers" as Controllers
import "icon" as Icon
import "../scripts/clock.js" as Clock
import "../scripts/theme.js" as Theme

Item {
    id: root

    property Item backdrop
    property int windowWidth
    property date currentTime
    property string activeSource: ""

    signal panelRequested(string mode, real anchorX, string source)
    signal desktopRequested

    readonly property real barHeight: 64

    height: barHeight

    // Connects the visual bar to its interaction controller.
    Controllers.Logo {
        id: controller
        view: root
    }

    Item {
        id: logoButton

        x: 22
        y: 5
        width: 54
        height: 54

        Glass {
            anchors.fill: parent
            backdrop: root.backdrop
            softShadow: true
            cornerRadius: logoButton.width / 2
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: logoMouse.containsMouse ? Theme.overlaySubtle : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }
        }

        Image {
            anchors.centerIn: parent
            width: 32
            height: 32
            source: "../../assets/logo.svg"
            sourceSize: Qt.size(128, 128)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            antialiasing: true
        }

        MouseArea {
            id: logoMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: controller.requestPanel("system", "system", logoButton)
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

        Glass {
            anchors.fill: parent
            backdrop: root.backdrop
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
                onActivated: controller.requestPanel("about", "search", searchButton)
            }

            Rectangle {
                width: 1
                height: 24
                y: (statusRow.height - height) / 2
                color: Theme.dividerBright
            }

            Item {
                id: notificationsButton
                width: 32
                height: 38

                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: notificationMouse.containsMouse ? Theme.actionHover : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }
                    }
                }

                Canvas {
                    id: notificationCanvas
                    anchors.centerIn: parent
                    width: 21
                    height: 23
                    onPaint: controller.paintNotification(notificationCanvas)
                }

                Rectangle {
                    width: 5
                    height: 5
                    radius: 3
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: 2
                    anchors.topMargin: 4
                    color: Theme.notificationAccent
                }

                MouseArea {
                    id: notificationMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: controller.requestPanel("quick", "notifications", notificationsButton)
                }
            }

            Rectangle {
                id: controlButton
                width: 34
                height: 34
                y: (statusRow.height - height) / 2
                radius: 17
                color: controlMouse.containsMouse ? Theme.controlOrbHover : Theme.controlOrbBackground
                border.width: 1
                border.color: Theme.controlOrbBorder

                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    radius: 10
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Theme.controlOrbTop
                        }
                        GradientStop {
                            position: 0.48
                            color: Theme.controlOrbMiddle
                        }
                        GradientStop {
                            position: 1
                            color: Theme.controlOrbBottom
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 11
                        height: 11
                        radius: 6
                        color: Theme.controlOrbCenter
                        border.color: Theme.controlOrbHighlight
                    }
                }

                MouseArea {
                    id: controlMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: controller.requestPanel("quick", "control", controlButton)
                }
            }

            TopAction {
                id: wifiButton
                icon: "../../assets/icons/wifi.svg"
                description: "Wi-Fi"
                highlighted: root.activeSource === "wifi"
                onActivated: controller.requestPanel("wifi", "wifi", wifiButton)
            }

            Quick.Text {
                visible: root.windowWidth >= 760
                y: (statusRow.height - height) / 2
                text: "87%"
                color: Theme.white
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            Quick.Text {
                visible: root.windowWidth >= 970
                y: (statusRow.height - height) / 2
                text: Clock.format(root.currentTime).split("   ")[0]
                color: Theme.white
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            Quick.Text {
                y: (statusRow.height - height) / 2
                text: Qt.formatTime(root.currentTime, "HH:mm")
                color: Theme.white
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Rectangle {
                id: profileButton
                width: 36
                height: 36
                y: (statusRow.height - height) / 2
                radius: 18
                color: profileMouse.containsMouse ? Theme.profileHover : Theme.profileBackground
                border.width: 1
                border.color: Theme.profileBorder

                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }
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
                        colorizationColor: Theme.white
                    }
                }

                MouseArea {
                    id: profileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: controller.requestPanel("quick", "profile", profileButton)
                }
            }
        }
    }

    component TopAction: Item {
        id: action

        property url icon
        property string description
        property bool highlighted: false
        signal activated

        width: 32
        height: 38

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: action.highlighted || actionMouse.containsMouse ? Theme.actionHover : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }
        }

        Icon.Tinted {
            anchors.centerIn: parent
            width: 22
            height: 22
            source: action.icon
            tint: Theme.white
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
