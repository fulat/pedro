pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../icon" as Icon
import "../logic/theme.js" as Theme

Item {
    id: root
    property string title
    property url icon
    property real level: 0.5
    Layout.fillWidth: true
    implicitHeight: 44

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 10

        Icon.Tinted {
            source: root.icon
            Layout.preferredWidth: 21
            Layout.preferredHeight: 21
        }
        Label {
            Layout.preferredWidth: 48
            text: root.title
            color: Theme.textPrimary
            font.pixelSize: 11
            font.weight: Font.Medium
        }
        Slider {
            id: slider
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            padding: 0
            from: 0
            to: 1
            value: root.level
            background: Rectangle {
                y: (slider.height - height) / 2
                width: slider.width
                height: 4
                radius: 2
                color: "#40506a"
                Rectangle {
                    width: Math.max(4, slider.visualPosition * parent.width)
                    height: parent.height
                    radius: 2
                    color: "#5a9cff"
                }
            }
            handle: Rectangle {
                x: slider.visualPosition * (slider.width - width)
                y: (slider.height - height) / 2
                implicitWidth: 10
                implicitHeight: 10
                radius: 5
                color: "#ffffff"
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }
}
