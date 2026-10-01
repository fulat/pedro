pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../../controllers" as Controllers
import "../icon" as Icon
import "../toggle" as Toggle
import "../../scripts/theme.js" as Theme

Rectangle {
    id: root
    property string title
    property string subtitle
    property url icon
    property real symbolSize: 23
    property real symbolOffsetY: 0
    property bool active: false
    property bool toggleable: true
    property bool externallyManaged: false
    property color statusColor: root.active ? Theme.statusConnected : Theme.statusInactive
    readonly property bool hovered: hover.hovered
    signal activated
    signal toggleRequested(bool state)
    signal detailsRequested
    Layout.fillWidth: true
    implicitHeight: 58
    radius: 9
    color: mouse.pressed ? Theme.overlayPressed : root.hovered ? Theme.overlayHover : "transparent"

    // Connects the tile presentation to its behavior controller.
    Controllers.Quick {
        id: controller
        view: root
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: controller.activate()
    }

    HoverHandler {
        id: hover
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 2
        spacing: 10

        Rectangle {
            implicitWidth: 40
            implicitHeight: 40
            radius: 20
            color: Theme.cardSurface
            border.width: 1
            border.color: root.active ? Theme.cardBorderStrong : Theme.cardBorder
            Icon.Tinted {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: root.symbolOffsetY
                width: root.symbolSize
                height: root.symbolSize
                source: root.icon
                tint: Theme.white
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label {
                Layout.fillWidth: true
                text: root.title
                color: Theme.white
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            RowLayout {
                spacing: 6
                Rectangle {
                    implicitWidth: 6
                    implicitHeight: 6
                    radius: 3
                    color: root.statusColor
                }
                Label {
                    text: root.subtitle
                    color: Theme.textMuted
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }
        }

        Toggle.Switch {
            active: root.active
            onToggled: state => controller.setActive(state)
        }

        Icon.Tinted {
            source: "../../../assets/icons/chevron.svg"
            Layout.preferredWidth: 8
            Layout.preferredHeight: 12
            tint: Theme.white
        }
    }
}
