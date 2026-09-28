pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../icon" as Icon

Rectangle {
    id: root
    property string title
    property string subtitle
    property url icon
    property color activeColor: "#ffffff"
    property color inactiveColor: "#ffffff"
    property color symbolColor: root.active ? root.activeColor : root.inactiveColor
    property bool active: false
    property bool toggleable: true
    signal activated()
    Layout.fillWidth: true
    implicitHeight: 62
    radius: 8
    color: mouse.pressed ? "#34ffffff"
                         : mouse.containsMouse ? "#22ffffff" : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 3
        anchors.rightMargin: 3
        spacing: 8
        Item {
            implicitWidth: 35
            implicitHeight: 35
            Icon.Tinted {
                anchors.centerIn: parent
                source: root.icon
                tint: root.symbolColor
                width: 24
                height: 24
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
                Layout.fillWidth: true
                text: root.title
                color: "#ffffff"
                font.pixelSize: root.title.length > 16 ? 12 : 14
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                text: root.subtitle
                color: "#d6dcdf"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
        Icon.Tinted {
            source: "../../assets/icons/chevron.svg"
            Layout.preferredWidth: 7
            Layout.preferredHeight: 11
            tint: "#ffffff"
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.toggleable)
                root.active = !root.active
            root.activated()
        }
    }
}
