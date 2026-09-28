pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

Rectangle {
    id: root
    property string label
    property string value
    Layout.fillWidth: true
    implicitHeight: 58
    radius: 7
    color: "#22ffffff"
    border.color: "#24ffffff"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 9
        spacing: 2
        Label { text: root.label; color: "#d6dcdf"; font.pixelSize: 10 }
        Label {
            Layout.fillWidth: true
            text: root.value
            color: "#ffffff"
            font.pixelSize: 14
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
    }
}
