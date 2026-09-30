pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../../controllers" as Controllers
import "../icon" as Icon
import "../../scripts/theme.js" as Theme

Rectangle {
    id: root
    property string title
    property string subtitle
    property url icon
    property color activeColor: Theme.white
    property color inactiveColor: Theme.white
    property color symbolColor: root.active ? root.activeColor : root.inactiveColor
    property bool active: false
    property bool toggleable: true
    signal activated

    // Connects the tile presentation to its behavior controller.
    Controllers.Toggle {
        id: controller
        view: root
    }

    Layout.fillWidth: true
    implicitHeight: 62
    radius: 8
    color: mouse.pressed ? Theme.overlayPressed : mouse.containsMouse ? Theme.overlayHover : "transparent"

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
                color: Theme.white
                font.pixelSize: root.title.length > 16 ? 12 : 14
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                text: root.subtitle
                color: Theme.textMuted
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
        Icon.Tinted {
            source: "../../../assets/icons/chevron.svg"
            Layout.preferredWidth: 7
            Layout.preferredHeight: 11
            tint: Theme.white
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: controller.activate()
    }
}
