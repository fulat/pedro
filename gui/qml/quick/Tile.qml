pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../icon" as Icon
import "../toggle" as Toggle

Rectangle {
    id: root
    property string title
    property string subtitle
    property url icon
    property real symbolSize: 25
    property real symbolOffsetY: 0
    property bool active: false
    property bool toggleable: true
    property bool externallyManaged: false
    property color statusColor: root.active ? "#41df91" : "#8290a4"
    readonly property bool hovered: hover.hovered
    signal activated()
    signal toggleRequested(bool state)
    signal detailsRequested()
    Layout.fillWidth: true
    implicitHeight: 68
    radius: 9
    color: mouse.pressed ? "#34ffffff"
                         : root.hovered ? "#22ffffff" : "transparent"

    function setActive(state) {
        if (!root.toggleable)
            return

        if (!root.externallyManaged)
            root.active = state

        root.toggleRequested(state)
        root.activated()
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.detailsRequested()
    }

    HoverHandler { id: hover }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 2
        spacing: 10

        Rectangle {
            implicitWidth: 48
            implicitHeight: 48
            radius: 24
            color: "#20ffffff"
            border.width: 1
            border.color: root.active ? "#58ffffff" : "#36ffffff"
            Icon.Tinted {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: root.symbolOffsetY
                width: root.symbolSize
                height: root.symbolSize
                source: root.icon
                tint: "#ffffff"
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label {
                Layout.fillWidth: true
                text: root.title
                color: "#ffffff"
                font.pixelSize: 16
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
                    color: "#d6dcdf"
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }
        }

        Toggle.Switch {
            active: root.active
            onToggled: state => root.setActive(state)
        }

        Icon.Tinted {
            source: "../../assets/icons/chevron.svg"
            Layout.preferredWidth: 8
            Layout.preferredHeight: 12
            tint: "#ffffff"
        }
    }
}
