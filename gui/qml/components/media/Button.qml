pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../icon" as Icon
import "../../logic/theme.js" as Theme

Rectangle {
    id: root
    property url icon
    property bool emphasized: false
    signal activated()
    Layout.preferredWidth: root.emphasized ? 38 : 25
    Layout.preferredHeight: root.emphasized ? 38 : 25
    radius: width / 2
    color: emphasized ? Theme.dividerSoft : "transparent"
    border.width: emphasized ? 1 : 0
    border.color: Theme.mediaButtonBorder

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: mouse.pressed ? Theme.overlayPressed
                             : mouse.containsMouse ? Theme.overlayHover : "transparent"
    }

    Icon.Tinted {
        anchors.centerIn: parent
        width: root.emphasized ? 20 : 17
        height: root.emphasized ? 20 : 17
        source: root.icon
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
