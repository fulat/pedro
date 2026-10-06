pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../icon" as Icon
import "palette.js" as Palette

Rectangle {
    id: sidebar
    property var controller
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    color: "transparent"
    ScrollView {
        id: sidebarScroll
        Binding { target: sidebarScroll.contentItem; property: "boundsBehavior"; value: Flickable.StopAtBounds }
        Binding { target: sidebarScroll.contentItem; property: "boundsMovement"; value: Flickable.StopAtBounds }
        anchors.fill: parent
        anchors.margins: sidebar.controller && sidebar.controller.sidebarCollapsed ? 7 : 14
        clip: true
        contentWidth: availableWidth
        Column {
            width: parent.width
            spacing: 0
            Repeater {
                model: [
                    {name: "home", icon: "house"}, {name: "favorites", icon: "star"}, {name: "recent", icon: "clock"},
                    {divider: true},
                    {name: "desktop", icon: "display"}, {name: "documents", icon: "file"}, {name: "downloads", icon: "download"}, {name: "images", icon: "image"}, {name: "music", icon: "music"}, {name: "videos", icon: "video"},
                    {divider: true},
                    {name: "computer", icon: "display"}, {divider: true}
                ]
                delegate: Item {
                    id: row
                    required property var modelData
                    objectName: modelData.name ? "filesPlace-" + modelData.name : ""
                    width: parent.width
                    height: modelData.divider ? 23 : 36
                    Rectangle {
                        visible: row.modelData.divider === true
                        width: parent.width - 12
                        x: 6
                        y: 11
                        height: 1
                        color: sidebar.colors.line
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 18
                        visible: !row.modelData.divider
                        color: sidebar.controller && row.modelData.name === sidebar.controller.activePlace ? sidebar.colors.selected : rowHover.hovered ? sidebar.colors.hover : "transparent"
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !row.modelData.divider
                        onClicked: sidebar.controller.openPlace(row.modelData.name)
                        onDoubleClicked: sidebar.controller.resetPlace(row.modelData.name)
                    }
                    HoverHandler { id: rowHover; enabled: !row.modelData.divider; cursorShape: Qt.PointingHandCursor }
                    Icon.Tinted {
                        visible: !row.modelData.divider
                        x: 14; y: 8; width: 20; height: 20
                        source: row.modelData.icon ? row.modelData.icon + ".svg" : ""
                        tint: row.modelData.name === "home" ? sidebar.colors.accent : sidebar.colors.ink
                    }
                    Text {
                        visible: !row.modelData.divider && !(sidebar.controller && sidebar.controller.sidebarCollapsed)
                        x: 49
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.name ? qsTranslate("Pedro", "files.browser." + row.modelData.name) : ""
                        color: sidebar.colors.ink
                        font.pixelSize: 14
                        font.bold: sidebar.controller && row.modelData.name === sidebar.controller.activePlace
                    }
                }
            }
            Item {
                visible: !(sidebar.controller && sidebar.controller.sidebarCollapsed)
                width: parent.width; height: visible ? 38 : 0
                Text { x: 14; y: 9; text: qsTranslate("Pedro", "files.sample.tags"); color: sidebar.colors.muted; font.pixelSize: 13 }
                Rectangle { anchors.right: parent.right; width: 30; height: 30; radius: 15; color: sidebar.colors.selected; Text { anchors.centerIn: parent; text: "+"; color: sidebar.colors.ink; font.pixelSize: 23 } }
            }
            Repeater {
                model: [{name: "work", color: "#13c639"}, {name: "design", color: "#8e22ff"}, {name: "important", color: "#ffa100"}, {name: "personal", color: "#ff6eaa"}]
                delegate: Item {
                    required property var modelData
                    visible: !(sidebar.controller && sidebar.controller.sidebarCollapsed)
                    width: parent.width; height: visible ? 31 : 0
                    Rectangle { x: 15; y: 7; width: 17; height: 17; radius: 9; color: parent.modelData.color }
                    Text { x: 49; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Pedro", "files.sample." + parent.modelData.name); color: sidebar.colors.ink; font.pixelSize: 14 }
                }
            }
        }
    }
}
