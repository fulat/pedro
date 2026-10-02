pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
RowLayout {
    id: root
    property string title
    property string placeholder
    property alias text: input.text
    property bool editable: true
    Layout.fillWidth: true
    spacing: 18
    Label { text: root.title; color: "#b5b8c0"; font.pixelSize: 12; Layout.preferredWidth: 130 }
    TextField {
        id: input
        Layout.fillWidth: true
        enabled: root.editable
        placeholderText: root.placeholder
        color: "#eef0f3"
        placeholderTextColor: "#737983"
        font.pixelSize: 13
        padding: 10
        background: Rectangle { radius: 7; color: "#182025"; border.color: input.activeFocus ? "#8894a5" : "#30363f" }
    }
}
