pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../icon" as Icon
import "../../scripts/theme.js" as Theme

Rectangle {
    id: root
    property string title
    property url icon
    property bool separator: false
    signal activated()
    Layout.fillWidth: true
    implicitHeight: 76
    radius: 8
    color: mouse.pressed ? Theme.overlayPressed
                         : mouse.containsMouse ? Theme.overlayHover : "transparent"

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 4
        Icon.Tinted {
            Layout.alignment: Qt.AlignHCenter
            source: root.icon
            Layout.preferredWidth: 25
            Layout.preferredHeight: 25
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: root.title
            color: Theme.white
            font.pixelSize: 13
            font.weight: Font.Medium
        }
    }

    Rectangle {
        visible: root.separator
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: 38
        color: Theme.overlayPressed
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
