pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../icon" as Icon

Rectangle {
    id: root
    property url icon
    property bool emphasized: false
    signal activated()
    Layout.preferredWidth: root.emphasized ? 38 : 25
    Layout.preferredHeight: root.emphasized ? 38 : 25
    radius: width / 2
    color: mouse.pressed ? "#28384d" : mouse.containsMouse ? "#1d2a3c" : emphasized ? "#111a27" : "transparent"
    border.width: emphasized ? 1 : 0
    border.color: "#304056"

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
