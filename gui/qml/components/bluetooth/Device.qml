pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../icon" as Icon
import "../../logic/theme.js" as Theme

Rectangle {
    id: root

    required property string name
    required property string iconName
    required property bool connected
    required property bool paired
    readonly property string normalizedIcon: iconName.toLowerCase()
    readonly property url iconSource: normalizedIcon.includes("keyboard") || normalizedIcon.includes("input-keyboard")
                                       ? "../../../assets/icons/keyboard.svg"
                                       : normalizedIcon.includes("audio") || normalizedIcon.includes("headset")
                                         || normalizedIcon.includes("headphone") || normalizedIcon.includes("speaker")
                                         ? "../../../assets/icons/speaker.svg"
                                         : "../../../assets/icons/bluetooth.svg"

    signal activated(string name)

    implicitHeight: 68
    radius: 9
    color: mouse.pressed ? Theme.overlayPressed
                         : mouse.containsMouse ? Theme.overlayHover : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 8
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 46
            Layout.preferredHeight: 46
            radius: width / 2
            color: Theme.cardSurface
            border.width: 1
            border.color: root.connected ? Theme.cardBorderStrong : Theme.cardBorder

            Icon.Tinted {
                anchors.centerIn: parent
                width: 27
                height: 27
                source: root.iconSource
                tint: Theme.white
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Controls.Label {
                Layout.fillWidth: true
                text: root.name
                color: Theme.white
                font.pixelSize: 13
                font.weight: root.connected ? Font.DemiBold : Font.Medium
                elide: Text.ElideRight
            }

            Controls.Label {
                text: root.connected ? "Conectado" : root.paired ? "Emparejado" : "Disponible"
                color: root.connected ? Theme.statusActive : Theme.textMuted
                font.pixelSize: 10
            }
        }

        Icon.Tinted {
            source: "../../../assets/icons/chevron.svg"
            Layout.preferredWidth: 8
            Layout.preferredHeight: 13
            tint: Theme.white
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        height: 1
        color: Theme.overlayPressed
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated(root.name)
    }
}
