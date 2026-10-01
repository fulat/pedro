pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../desktop" as Desktop
import "../icon" as Icon
import "palette.js" as Palette

Item {
    id: inspector
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    ScrollView {
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        Column {
            width: parent.width
            spacing: 10
            Item {
                width: parent.width; height: 94
                Desktop.Icon { anchors.centerIn: parent; width: 126; height: 126; kind: "folder" }
                Icon.Tinted { anchors.centerIn: parent; anchors.verticalCenterOffset: 13; width: 39; height: 39; source: "people.svg"; tint: "#99d7ff" }
            }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: qsTranslate("Pedro", "files.browser.project") + "  ★"; color: inspector.colors.ink; font.pixelSize: 18; font.bold: true }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: qsTranslate("Pedro", "files.sample.detail"); color: inspector.colors.muted; font.pixelSize: 12 }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: qsTranslate("Pedro", "files.sample.updated"); color: inspector.colors.muted; font.pixelSize: 12 }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                Repeater {
                    model: [{key: "open", icon: "folder"}, {key: "share", icon: "share"}, {key: "more", icon: ""}]
                    delegate: Rectangle {
                        required property var modelData
                        width: 64; height: 55; radius: 10
                        color: inspector.colors.card; border.color: inspector.colors.line
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        Icon.Tinted { x: 23; y: 8; width: 18; height: 18; source: parent.modelData.icon ? parent.modelData.icon + ".svg" : ""; tint: inspector.colors.accent }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; y: 32; text: qsTranslate("Pedro", "files.browser." + parent.modelData.key); color: inspector.colors.ink; font.pixelSize: 11 }
                        Text { visible: parent.modelData.key === "more"; anchors.horizontalCenter: parent.horizontalCenter; y: 6; text: "•••"; color: inspector.colors.ink }
                    }
                }
            }
            Text { text: qsTranslate("Pedro", "files.sample.preview"); color: inspector.colors.ink; font.pixelSize: 13; font.bold: true }
            Column {
                width: parent.width
                spacing: 6
                Row {
                    spacing: 6
                    Repeater {
                        model: ["wallpaper-light.jpeg", "wallpaper.jpeg"]
                        delegate: Rectangle {
                            required property string modelData
                            width: (inspector.width - 6) / 2; height: 62; radius: 7; clip: true
                            color: inspector.colors.selected
                            Image { anchors.fill: parent; source: "../../../assets/wallpapers/" + parent.modelData; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                        }
                    }
                }
                Row {
                    spacing: 6
                    Repeater {
                        model: ["wallpaper-car.jpeg", "wallpaper-light.jpeg", ""]
                        delegate: Rectangle {
                            required property string modelData
                            width: (inspector.width - 12) / 3; height: 60; radius: 7; clip: true
                            color: inspector.colors.selected
                            Image { visible: parent.modelData.length > 0; anchors.fill: parent; source: parent.modelData ? "../../../assets/wallpapers/" + parent.modelData : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                            Text { visible: !parent.modelData; anchors.centerIn: parent; text: "+7"; color: inspector.colors.muted; font.pixelSize: 12 }
                        }
                    }
                }
            }
            Text { text: qsTranslate("Pedro", "files.browser.information"); color: inspector.colors.ink; font.pixelSize: 13; font.bold: true; topPadding: 5 }
            Repeater {
                model: [{key: "type", value: "folderType", icon: "folder"}, {key: "location", value: "documents", icon: "tab"}, {key: "size", value: "detailSize", icon: "file"}, {key: "itemsLabel", value: "detailItems", icon: "grid"}, {key: "created", value: "createdDate", icon: "clock"}, {key: "modified", value: "modifiedDate", icon: "calendar"}]
                delegate: Row {
                    required property var modelData
                    width: parent.width; spacing: 8
                    Icon.Tinted { source: parent.modelData.icon + ".svg"; width: 14; height: 14; tint: inspector.colors.ink }
                    Text { width: 56; text: qsTranslate("Pedro", "files.sample." + parent.modelData.key); color: inspector.colors.muted; font.pixelSize: 10 }
                    Text { text: qsTranslate("Pedro", "files.sample." + parent.modelData.value); color: inspector.colors.muted; font.pixelSize: 10; width: inspector.width - 94; elide: Text.ElideRight }
                }
            }
            Text { text: qsTranslate("Pedro", "files.sample.tags"); color: inspector.colors.ink; font.pixelSize: 13; font.bold: true; topPadding: 10 }
            Row {
                spacing: 4
                Repeater {
                    model: ["work", "design", "important"]
                    delegate: Loader { id: tag; required property string modelData; source: "badge.qml"; onLoaded: { item.text = Qt.binding(() => qsTranslate("Pedro", "files.sample." + tag.modelData)); item.tone = modelData; } }
                }
            }
        }
    }
}
