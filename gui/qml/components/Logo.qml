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
            width: 20
            height: 20
            source: "../../assets/logo.png"
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
        ToolTip.delay: 400
        ToolTip.text: qsTranslate("Pedro", "shell.panel.about")
    }

    Item {
        id: statusPill

        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 20
        width: statusRow.width + 16
        height: 30

        Liquid {
            anchors.fill: parent
            backdrop: root.backdrop
            cornerRadius: 15
        }

        Row {
            id: statusRow

            anchors.centerIn: parent
            spacing: 4

            TopAction {
                id: searchButton
                icon: "../../assets/icons/search.svg"
                description: qsTranslate("Pedro", "common.search")
                highlighted: root.activeSource === "search"
                onActivated: controller.requestPanel("about", "search", searchButton)
            }

            Rectangle {
                width: 1
                height: 20
                y: (statusRow.height - height) / 2
                color: Theme.dividerBright
            }

            TopAction {
                id: controlButton
                icon: "../../assets/icons/menu.svg"
                description: qsTranslate("Pedro", "shell.panel.system")
                highlighted: root.activeSource === "control"
                onActivated: controller.requestPanel("quick", "control", controlButton)
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
                icon: "../../assets/icons/wifi.svg"
                description: qsTranslate("Pedro", "network.wifi.title")
                highlighted: root.activeSource === "wifi"
                onActivated: controller.requestPanel("wifi", "wifi", wifiButton)
            }

            Row {
                y: (statusRow.height - height) / 2
                spacing: 4
                Icon.Tinted {
                    width: 18
                    height: 18
                    source: "../../assets/icons/battery.svg"
                }
                Quick.Text {
                    text: Backend.battery.available ? Backend.battery.value + "%" : "—%"
                    color: Theme.white
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
            }

            Item {
                id: dateButton
                width: dateLabel.implicitWidth + 12
                height: 24
                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: dateMouse.containsMouse || root.activeSource === "notifications" ? Theme.actionHover : "transparent"
                    Behavior on color { ColorAnimation { duration: 140 } }
                }
                Quick.Text {
                    id: dateLabel
                    anchors.centerIn: parent
                    text: (root.windowWidth >= 970 ? Clock.format(root.currentTime, Backend.language).split("   ")[0] + "  " : "") + Qt.formatTime(root.currentTime, "HH:mm")
                    color: Theme.white
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
                MouseArea {
                    id: dateMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: controller.requestPanel("quick", "notifications", dateButton)
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

        width: 24
        height: 24

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: action.highlighted || actionMouse.containsMouse ? Theme.actionHover : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }
        }

        Icon.Tinted {
            anchors.centerIn: parent
            width: 16
            height: 16
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
