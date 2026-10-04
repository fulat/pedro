pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls

Item {
    id: bar
    property var controller
    RowLayout {
        anchors.fill: parent
        anchors.rightMargin: 12
        spacing: 12
        Controls.Label {
            Layout.fillWidth: true
            text: bar.controller ? bar.controller.preview.name : ""
            color: bar.controller ? bar.controller.ink : "white"
            font.pixelSize: 12
            elide: Text.ElideMiddle
        }
    }
}
