pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../icon" as Icon

Rectangle {
    id: root
    property string title
    property url icon
    signal activated()
    Layout.fillWidth: true
    implicitHeight: 68
    radius: 9
    color: mouse.pressed ? "#34ffffff"
                         : mouse.containsMouse ? "#22ffffff" : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 14
        Icon.Tinted {
            source: root.icon
            Layout.preferredWidth: 25
            Layout.preferredHeight: 25
            tint: "#ffffff"
        }
        Label {
            Layout.fillWidth: true
            text: root.title
            color: "#ffffff"
            font.pixelSize: 12
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
        Icon.Tinted {
            source: "../../assets/icons/chevron.svg"
            Layout.preferredWidth: 8
            Layout.preferredHeight: 13
            tint: "#ffffff"
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
