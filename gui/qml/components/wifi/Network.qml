pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../icon" as Icon
import "../../scripts/theme.js" as Theme

Rectangle {
    id: root

    required property string name
    required property int strength
    required property bool secured
    required property bool connected

    implicitHeight: 58
    radius: 9
    color: connected ? Theme.wifiConnectedSurface : "transparent"
    border.width: connected ? 1 : 0
    border.color: Theme.wifiNetworkBorder

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: hover.hovered ? Theme.overlayHover : "transparent"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 12

        Icon.Tinted {
            source: "../../../assets/icons/wifi.svg"
            Layout.preferredWidth: 27
            Layout.preferredHeight: 27
            tint: Theme.white
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Controls.Label {
                Layout.fillWidth: true
                text: root.name
                color: Theme.white
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
                    color: Theme.statusConnected
                }

                Controls.Label {
                    text: root.connected ? qsTranslate("Pedro", "bluetooth.device.connected") : root.secured ? qsTranslate("Pedro", "network.wifi.network.secured") : qsTranslate("Pedro", "network.wifi.network.open")
                    color: root.connected ? Theme.statusWifiConnected : Theme.textMuted
                    font.pixelSize: 9
                }
            }
        }

        Controls.Label {
            text: root.strength + "%"
            color: root.strength >= 65 ? Theme.wifiSignalStrong : Theme.textMuted
            font.pixelSize: 10
            font.weight: Font.Medium
        }
    }

    HoverHandler { id: hover }
}
