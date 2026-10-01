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
    implicitWidth: 60
    implicitHeight: 38
    hoverEnabled: true
    onClicked: menu.open()
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    contentItem: Item {
        Icon.Tinted { x: 7; anchors.verticalCenter: parent.verticalCenter; width: 19; height: 19; source: dropdown.symbol + ".svg"; tint: dropdown.colors.ink }
        Icon.Tinted { anchors.right: parent.right; anchors.rightMargin: 5; anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; rotation: 90; source: "chevron.svg"; tint: dropdown.colors.muted }
    }
    background: Rectangle { radius: 10; color: dropdown.hovered ? dropdown.colors.selected : dropdown.colors.card; border.color: dropdown.colors.line }
    ButtonGroup { id: choiceGroup }
    Menu {
        id: menu
        objectName: dropdown.objectName + "Menu"
        y: dropdown.height + 6
        x: dropdown.width - width
        width: 224
        padding: 6
        background: Rectangle { radius: 12; color: dropdown.colors.light ? "#f1f5fb" : "#202b3a"; border.color: dropdown.colors.line }
        Repeater {
            model: dropdown.options
            delegate: MenuItem {
                id: option
                required property var modelData
                objectName: "filesOption-" + modelData.key
                implicitHeight: 36
                leftPadding: 10
                rightPadding: 10
                hoverEnabled: true
                ButtonGroup.group: choiceGroup
                indicator: Item {}
                text: qsTranslate("Pedro", modelData.label)
                checkable: true
                checked: dropdown.selectedKey === modelData.key
                onTriggered: {
                    dropdown.chosen(modelData.key);
                    menu.close();
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                contentItem: Item {
                    Icon.Tinted {
                        width: 18
                        height: 18
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        source: option.modelData.icon + ".svg"
                        tint: dropdown.colors.ink
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 30
                        anchors.right: radio.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: option.text
                        color: dropdown.colors.ink
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        id: radio
                        objectName: "filesRadio-" + option.modelData.key
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        radius: 8
                        color: option.checked ? "#3478f6" : "transparent"
                        border.width: 1
                        border.color: option.checked ? "#80b5ff" : dropdown.colors.muted
                        Rectangle {
                            anchors.centerIn: parent
                            width: 7
                            height: 7
                            radius: 3.5
                            color: "white"
                            visible: option.checked
                        }
                    }
                }
                background: Rectangle { radius: 7; color: option.highlighted || option.hovered ? dropdown.colors.hover : "transparent" }
            }
        }
    }
}
