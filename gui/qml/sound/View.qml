pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../icon" as Icon
import "../logic/theme.js" as Theme

Item {
    id: root

    property real level: 0.62
    signal settingsRequested()

    RowLayout {
        anchors.fill: parent
        spacing: 12

        Icon.Tinted {
            source: "../../assets/icons/speaker.svg"
            Layout.preferredWidth: 21
            Layout.preferredHeight: 21
        }

        Controls.Slider {
            id: volumeSlider

            Layout.fillWidth: true
            Layout.preferredHeight: 28
            padding: 0
            from: 0
            to: 1
            value: root.level

            background: Rectangle {
                y: (volumeSlider.height - height) / 2
                width: volumeSlider.width
                height: 5
                radius: height / 2
                color: "#40506a"

                Rectangle {
                    width: Math.max(5, volumeSlider.visualPosition * parent.width)
                    height: parent.height
                    radius: parent.radius
                    color: "#5a9cff"
                }
            }

            handle: Rectangle {
                x: volumeSlider.visualPosition * (volumeSlider.width - width)
                y: (volumeSlider.height - height) / 2
                implicitWidth: 12
                implicitHeight: 12
                radius: width / 2
                color: "#ffffff"
            }

            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }

        Rectangle {
            id: settingsButton

            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            radius: 9
            color: settingsMouse.pressed ? "#1affffff"
                                         : settingsMouse.containsMouse ? "#0dffffff" : "transparent"

            Icon.Tinted {
                anchors.centerIn: parent
                source: "../../assets/icons/chevron.svg"
                width: 8
                height: 13
                tint: Theme.textPrimary
            }

            MouseArea {
                id: settingsMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingsRequested()
            }

            Controls.ToolTip {
                visible: settingsMouse.containsMouse
                delay: 500
                text: "Configuración de sonido"
            }
        }
    }
}
