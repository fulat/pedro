pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../icon" as Icon
import "../logic/theme.js" as Theme

Rectangle {
    id: root
    property string title
    property string subtitle
    property url icon
    property color activeColor: "#ffffff"
    property color inactiveColor: "#aeb8c7"
    property color symbolColor: root.active ? root.activeColor : root.inactiveColor
    property bool active: false
    property bool toggleable: true
    signal activated()
    Layout.fillWidth: true
    implicitHeight: 48
    radius: 8
    color: mouse.containsMouse ? "#12ffffff" : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 3
        anchors.rightMargin: 3
        spacing: 8
        Item {
            implicitWidth: 31
            implicitHeight: 31
            Icon.Tinted {
                anchors.centerIn: parent
                source: root.icon
                tint: root.symbolColor
                width: 20
                height: 20
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
                Layout.fillWidth: true
                text: root.title
                color: Theme.textPrimary
                font.pixelSize: root.title.length > 16 ? 9 : 10
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                text: root.subtitle
                color: Theme.textSecondary
                font.pixelSize: 8
                elide: Text.ElideRight
            }
        }
        Icon.Tinted {
            source: "../../assets/icons/chevron.svg"
            Layout.preferredWidth: 7
            Layout.preferredHeight: 11
            tint: "#c8d6ee"
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
