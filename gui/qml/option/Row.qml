pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../icon" as Icon
import "../logic/theme.js" as Theme

Rectangle {
    id: root
    property string title
    property url icon
    signal activated()
    Layout.fillWidth: true
    implicitHeight: 68
    radius: 9
    color: mouse.containsMouse ? "#12ffffff" : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 14
        Icon.Tinted {
            source: root.icon
            Layout.preferredWidth: 25
            Layout.preferredHeight: 25
            tint: "#dbe7ff"
        }
        Label {
            Layout.fillWidth: true
            text: root.title
            color: Theme.textPrimary
            font.pixelSize: 12
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
        Icon.Tinted {
            source: "../../assets/icons/chevron.svg"
            Layout.preferredWidth: 8
            Layout.preferredHeight: 13
            tint: "#c8d6ee"
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
