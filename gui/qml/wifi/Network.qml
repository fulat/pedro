pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../icon" as Icon

Rectangle {
    id: root

    required property string name
    required property int strength
    required property bool secured
    required property bool connected

    implicitHeight: 58
    radius: 9
    color: connected ? "#1dffffff" : "transparent"
    border.width: connected ? 1 : 0
    border.color: "#45ffffff"

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: hover.hovered ? "#22ffffff" : "transparent"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 12

        Icon.Tinted {
            source: "../../assets/icons/wifi.svg"
            Layout.preferredWidth: 27
            Layout.preferredHeight: 27
            tint: "#ffffff"
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Controls.Label {
                Layout.fillWidth: true
                text: root.name
                color: "#ffffff"
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
                    color: root.connected ? "#75e3ad" : "#d6dcdf"
                    font.pixelSize: 9
                }
            }
        }

        Controls.Label {
            text: root.strength + "%"
            color: root.strength >= 65 ? "#9ac0ff" : "#d6dcdf"
            font.pixelSize: 10
            font.weight: Font.Medium
        }
    }

    HoverHandler { id: hover }
}
