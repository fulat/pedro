pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../icon" as Icon
import "../logic/theme.js" as Theme

Rectangle {
    id: root

    required property string name
    required property int strength
    required property bool secured
    required property bool connected

    implicitHeight: 58
    radius: 9
    color: connected ? "#182d4666" : hover.hovered ? "#0dffffff" : "transparent"
    border.width: connected ? 1 : 0
    border.color: "#4f6fa0c7"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 12

        Icon.Tinted {
            source: "../../assets/icons/wifi.svg"
            Layout.preferredWidth: 27
            Layout.preferredHeight: 27
            tint: root.connected ? "#75adff" : root.strength >= 50 ? "#d7e5fa" : "#8b9ab0"
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Controls.Label {
                Layout.fillWidth: true
                text: root.name
                color: Theme.textPrimary
                font.pixelSize: 12
                font.weight: root.connected ? Font.DemiBold : Font.Medium
                elide: Text.ElideRight
            }

            RowLayout {
                spacing: 6

                Rectangle {
                    visible: root.connected
                    implicitWidth: 6
                    implicitHeight: 6
                    radius: 3
                    color: "#41df91"
                }

                Controls.Label {
                    text: root.connected ? "Conectado" : root.secured ? "Protegida" : "Abierta"
                    color: root.connected ? "#75e3ad" : Theme.textSecondary
                    font.pixelSize: 9
                }
            }
        }

        Controls.Label {
            text: root.strength + "%"
            color: root.strength >= 65 ? "#9ac0ff" : Theme.textSecondary
            font.pixelSize: 10
            font.weight: Font.Medium
        }
    }

    HoverHandler { id: hover }
}
