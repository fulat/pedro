pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import "../icon" as Icon
import "palette.js" as Palette

Button {
    id: dropdown
    property string symbol: "grid"
    property var options: []
    property string selectedKey: ""
    signal chosen(string key)
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    implicitWidth: 56
    implicitHeight: 38
    hoverEnabled: true
    onClicked: menu.open()
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    contentItem: Item {
        Icon.Tinted { x: 8; anchors.verticalCenter: parent.verticalCenter; width: 17; height: 17; source: dropdown.symbol + ".svg"; tint: dropdown.colors.ink }
        Text { anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: "⌄"; color: dropdown.colors.muted }
    }
    background: Rectangle { radius: 10; color: dropdown.hovered ? dropdown.colors.selected : dropdown.colors.card; border.color: dropdown.colors.line }
    Menu {
        id: menu
        y: dropdown.height + 6
        x: dropdown.width - width
        width: 195
        padding: 6
        background: Rectangle { radius: 12; color: dropdown.colors.light ? "#f1f5fb" : "#202b3a"; border.color: dropdown.colors.line }
        Repeater {
            model: dropdown.options
            delegate: MenuItem {
                id: option
                required property var modelData
                text: qsTranslate("Pedro", modelData.label)
                checkable: true
                checked: dropdown.selectedKey === modelData.key
                onTriggered: dropdown.chosen(modelData.key)
                contentItem: Text { text: option.text; color: dropdown.colors.ink; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter; leftPadding: 24 }
                background: Rectangle { radius: 7; color: option.highlighted ? dropdown.colors.selected : "transparent" }
            }
        }
    }
}
