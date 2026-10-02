pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../icon" as Icon
import "../../scripts/theme.js" as Theme

Item {
    id: root
    property string title
    property url icon
    property real level: 0.5
    property bool interactive: true
    property bool iconInteractive: false
    signal iconClicked()
    signal levelMoved(real value)
    Layout.fillWidth: true
    implicitHeight: 48

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 10

        Icon.Tinted {
            source: root.icon
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            MouseArea {
                anchors.fill: parent
                enabled: root.iconInteractive && root.interactive
                cursorShape: Qt.PointingHandCursor
                onClicked: root.iconClicked()
            }
        }
        Label {
            Layout.preferredWidth: 64
            text: root.title
            color: Theme.white
            font.pixelSize: 14
            font.weight: Font.Medium
        }
        Slider {
            id: slider
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            padding: 0
            from: 0
            to: 1
            enabled: root.interactive
            value: root.level
            onMoved: root.levelMoved(value)
            background: Rectangle {
                y: (slider.height - height) / 2
                width: slider.width
                height: 4
                radius: 2
                color: Theme.sliderTrack
                Rectangle {
                    width: Math.max(4, slider.visualPosition * parent.width)
                    height: parent.height
                    radius: 2
                    color: Theme.sliderFill
                }
            }
            handle: Rectangle {
                x: slider.visualPosition * (slider.width - width)
                y: (slider.height - height) / 2
                implicitWidth: 10
                implicitHeight: 10
                radius: 5
                color: Theme.white
            }
            opacity: enabled ? 1 : 0.45
            HoverHandler { cursorShape: slider.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
        }
    }
}
