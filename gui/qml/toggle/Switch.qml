pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: root
    property bool active: false
    property bool interactive: true
    signal toggled(bool state)
    implicitWidth: 46
    implicitHeight: 24
    radius: height / 2
    color: root.active ? "#2582ff" : "#465366"
    border.width: 1
    border.color: root.active ? "#4a9aff" : "#607086"
    opacity: root.interactive ? 1 : 0.72

    Behavior on color { ColorAnimation { duration: 140 } }

    Rectangle {
        width: 18
        height: 18
        radius: 9
        y: 3
        x: root.active ? root.width - width - 3 : 3
        color: "#ffffff"
        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.toggled(!root.active)
    }
}
