import QtQuick
import QtQuick as Quick
import QtQuick.Controls.Basic

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
    property alias logoControl: logoButton
    property alias statusControl: statusPill
    property alias notificationControl: notificationButton

    signal panelRequested(string mode, real anchorX, string source)
    signal desktopRequested

    readonly property real barHeight: 48

    height: barHeight

    // Connects the visual bar to its interaction controller.
    Controllers.Logo {
        id: controller
        view: root
    }

    Item {
        id: logoButton

        x: 18
        y: 6
        width: 36
        height: 36

        // Applies the shared liquid surface while preserving an exact circle.
        Liquid {
            anchors.fill: parent
            backdrop: root.backdrop
            cornerRadius: width / 2
            resolutionScale: 2
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

        Icon.Tinted {
            anchors.centerIn: parent
            width: 18
            height: 18
            source: "../../assets/logo.svg"
            tint: Theme.white
            resolutionScale: 3
        }

        MouseArea {
            id: logoMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: controller.requestPanel("system", "system", logoButton)
        }

        ToolTip.visible: logoMouse.containsMouse
        ToolTip.delay: 400
        ToolTip.text: qsTranslate("Pedro", "shell.panel.about")
    }

    Item {
        id: statusPill

        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.right: notificationButton.left
        anchors.rightMargin: 8
        width: statusRow.width + height - statusRow.height
        height: 30

        Liquid {
            anchors.fill: parent
            backdrop: root.backdrop
            cornerRadius: 15
        }

        Row {
            id: statusRow

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: (statusPill.height - height) / 2
            spacing: 4

            TopAction {
                id: searchButton
                icon: "../../assets/icons/search.svg"
                description: qsTranslate("Pedro", "common.search")
                highlighted: root.activeSource === "search"
                onActivated: controller.requestPanel("about", "search", searchButton)
            }

            TopAction {
                id: bluetoothButton
                icon: "../../assets/icons/bluetooth.svg"
                description: qsTranslate("Pedro", "bluetooth.title")
                highlighted: root.activeSource === "bluetooth"
                onActivated: controller.requestPanel("bluetooth", "bluetooth", bluetoothButton)
            }

            TopAction {
                id: wifiButton
                icon: Backend.networkConnection.type === "ethernet" ? "../../assets/icons/ethernet.svg" : "../../assets/icons/wifi.svg"
                description: Backend.networkConnection.type === "wifi" || (Backend.networkConnection.type === "none" && Backend.wifiAvailable) ? qsTranslate("Pedro", "network.wifi.title") : qsTranslate("Pedro", "network.connection.title")
                highlighted: root.activeSource === "wifi"
                onActivated: controller.requestPanel(Backend.networkConnection.type === "wifi" || (Backend.networkConnection.type === "none" && Backend.wifiAvailable) ? "wifi" : "network", "wifi", wifiButton)
            }

            Item {
                id: batteryButton
                width: batteryRow.width + 12
                height: 24

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: batteryMouse.pressed ? Theme.overlayPressed : batteryMouse.containsMouse || root.activeSource === "battery" ? Theme.actionHover : "transparent"
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Row {
                    id: batteryRow
                    anchors.centerIn: parent
                    height: 24
                    spacing: 4
                    Quick.Text {
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: Backend.battery.available ? Backend.battery.value + "%" : "—%"
                        color: Theme.white
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    Item {
                        width: 27
                        height: 18
                        y: (parent.height - height) / 2
                        Icon.Tinted {
                            anchors.fill: parent
                            source: "../../assets/icons/battery.svg"
                            resolutionScale: 2
                        }
                        Rectangle {
                            objectName: "batteryChargeFill"
                            x: 3
                            y: 5
                            width: 18 * Math.max(0, Math.min(100, Backend.battery.value)) / 100
                            height: 8
                            radius: 1.75
                            visible: Backend.battery.available
                            color: Backend.battery.low ? Theme.batteryLow : Backend.battery.charging ? Theme.batteryHealthy : Theme.white
                            Behavior on color { ColorAnimation { duration: 180 } }
                            Behavior on width { NumberAnimation { duration: 180 } }
                        }
                        Image {
                            x: 8
                            y: 3
                            width: 8
                            height: 12
                            visible: Backend.battery.available && Backend.battery.charging
                            source: "image://icons/original/charging.svg"
                            sourceSize.width: Math.ceil(width * Math.max(1, Screen.devicePixelRatio) * 2)
                            sourceSize.height: Math.ceil(height * Math.max(1, Screen.devicePixelRatio) * 2)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                    }

                }

                MouseArea {
                    id: batteryMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: controller.requestPanel("battery", "battery", batteryButton)
                }

                Accessible.role: Accessible.Button
                Accessible.name: qsTranslate("Pedro", "shell.battery.title")
                Accessible.onPressAction: controller.requestPanel("battery", "battery", batteryButton)
            }

            TopAction {
                id: controlButton
                icon: "../../assets/icons/menu.svg"
                description: qsTranslate("Pedro", "shell.panel.system")
                highlighted: root.activeSource === "control"
                onActivated: controller.requestPanel("quick", "control", controlButton)
            }

            Item {
                id: dateButton
                width: dateLabel.implicitWidth + 24
                height: 24
                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: dateMouse.containsMouse || root.activeSource === "calendar" ? Theme.actionHover : "transparent"
                    Behavior on color { ColorAnimation { duration: 140 } }
                }
                Quick.Text {
                    id: dateLabel
                    anchors.centerIn: parent
                    text: (root.windowWidth >= 970 ? Clock.format(root.currentTime, Backend.language).split("   ")[0] + "  " : "") + Clock.time(root.currentTime, Backend.language)
                    color: Theme.white
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
                MouseArea {
                    id: dateMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: controller.requestPanel("calendar", "calendar", dateButton)
                }
            }

        }
    }

    Item {
        id: notificationButton

        anchors.top: statusPill.top
        anchors.right: parent.right
        anchors.rightMargin: 20
        width: statusPill.height
        height: statusPill.height

        Liquid {
            anchors.fill: parent
            backdrop: root.backdrop
            cornerRadius: width / 2
        }

        TopAction {
            anchors.centerIn: parent
            icon: Backend.focusMode.active ? "../../assets/icons/silent.svg" : "../../assets/icons/bell.svg"
            iconSize: 14
            description: qsTranslate("Pedro", "shell.notifications.title")
            highlighted: root.activeSource === "notifications"
            width: parent.width
            height: parent.height
            onActivated: controller.requestPanel("notifications", "notifications", notificationButton)
        }
    }

    component TopAction: Item {
        id: action

        property url icon
        property string description
        property bool highlighted: false
        property real iconSize: 16
        signal activated

        width: 24
        height: 24

        Rectangle {
            anchors.fill: parent
            radius: Math.min(width, height) / 2
            color: action.highlighted || actionMouse.containsMouse ? Theme.actionHover : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }
        }

        Icon.Tinted {
            anchors.centerIn: parent
            width: action.iconSize
            height: action.iconSize
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
        ToolTip.delay: 400
        ToolTip.text: action.description
    }
}
