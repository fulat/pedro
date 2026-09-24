pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import "../icon" as Icon

Item {
    id: root
    property string kind
    property string description
    property bool highlighted: false
    readonly property url icon: kind === "search" ? "../../assets/icons/search.svg" :
                                kind === "display" ? "../../assets/icons/display.svg" :
                                kind === "wifi" ? "../../assets/icons/wifi.svg" :
                                kind === "bluetooth" ? "../../assets/icons/bluetooth.svg" :
                                kind === "sound" ? "../../assets/icons/speaker.svg" :
                                "../../assets/icons/battery.svg"
    signal activated()
    implicitWidth: 31
    implicitHeight: 36

    Rectangle {
        anchors.fill: parent
        radius: 5
        color: mouse.pressed ? "#1affffff" : (root.highlighted || mouse.containsMouse) ? "#0dffffff" : "transparent"
    }

    Icon.Tinted {
        anchors.centerIn: parent
        width: 18
        height: 18
        source: root.icon
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    ToolTip {
        visible: mouse.containsMouse
        delay: 500
        text: root.description
    }
}
