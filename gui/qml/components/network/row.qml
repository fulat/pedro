pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../icon" as Icon
Rectangle {
    id: root
    property string title
    property string detail
    property url icon
    property bool navigable: true
    signal activated()
    Layout.fillWidth: true
    implicitHeight: 68
    radius: 10
    color: mouse.containsMouse && navigable ? "#0cffffff" : "transparent"
    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 16
        Icon.Tinted { visible: root.icon.toString() !== ""; source: root.icon; Layout.preferredWidth: 22; Layout.preferredHeight: 22 }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Label { text: root.title; color: "#f0f1f3"; font.pixelSize: 14; font.weight: Font.Medium }
            Label { visible: text !== ""; text: root.detail; color: "#a9adb5"; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
        }
        Label { visible: root.navigable; text: "›"; color: "#a9adb5"; font.pixelSize: 22 }
    }
    MouseArea { id: mouse; anchors.fill: parent; enabled: root.navigable; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.activated() }
}
