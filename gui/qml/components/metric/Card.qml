pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../../scripts/theme.js" as Theme

Rectangle {
    id: root
    property string label
    property string value
    Layout.fillWidth: true
    implicitHeight: 58
    radius: 7
    color: Theme.overlayHover
    border.color: Theme.shortcutHover

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 9
        spacing: 2
        Label { text: root.label; color: Theme.textMuted; font.pixelSize: 10 }
        Label {
            Layout.fillWidth: true
            text: root.value
            color: Theme.white
            font.pixelSize: 14
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
    }
}
