pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../desktop" as Desktop
import "../icon" as Icon
import "palette.js" as Palette

Item {
    id: inspector
    property var controller
    readonly property var entry: controller ? controller.selectedEntry : ({})
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    ScrollView {
        id: inspectorScroll
        Binding { target: inspectorScroll.contentItem; property: "boundsBehavior"; value: Flickable.StopAtBounds }
        Binding { target: inspectorScroll.contentItem; property: "boundsMovement"; value: Flickable.StopAtBounds }
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        Column {
            width: parent.width
            spacing: 12
            Item {
                width: parent.width; height: 94
                Desktop.Icon { visible: !inspector.entry.id || inspector.entry.isDirectory; anchors.centerIn: parent; width: 126; height: 126; kind: "folder" }
                Icon.Tinted { visible: !!inspector.entry.id && !inspector.entry.isDirectory; anchors.centerIn: parent; width: 74; height: 74; source: inspector.entry.icon ? inspector.entry.icon + ".svg" : ""; tint: inspector.colors.accent }
            }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: inspector.entry.name || (inspector.controller ? inspector.controller.title : ""); color: inspector.colors.ink; font.pixelSize: 18; font.bold: true; wrapMode: Text.WrapAnywhere }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: inspector.entry.id ? inspector.entry.isDirectory ? qsTranslate("Pedro", "files.browser.folder") : inspector.entry.type : inspector.controller ? qsTranslate("Pedro", "files.sample.items").arg(inspector.controller.folders.length + inspector.controller.files.length) : ""; color: inspector.colors.muted; font.pixelSize: 12; wrapMode: Text.Wrap }
            Text { text: qsTranslate("Pedro", "files.sample.preview"); color: inspector.colors.ink; font.pixelSize: 13; font.bold: true; visible: inspector.entry.icon === "image" }
            Image { width: parent.width; height: 150; source: inspector.entry.icon === "image" && inspector.entry.url.indexOf("file:") === 0 ? inspector.entry.url : ""; fillMode: Image.PreserveAspectFit; asynchronous: true; visible: source.toString().length > 0 }
            Text { text: qsTranslate("Pedro", "files.browser.information"); color: inspector.colors.ink; font.pixelSize: 13; font.bold: true; topPadding: 5 }
            Repeater {
                model: [
                    {label: "location", text: inspector.entry.path || (inspector.controller ? inspector.controller.directory.path || inspector.controller.title : ""), icon: "folder"},
                    {label: "size", text: inspector.entry.sizeText || "—", icon: "file"},
                    {label: "modified", text: inspector.entry.modifiedText || "—", icon: "calendar"}
                ]
                delegate: Column {
                    required property var modelData
                    width: parent.width
                    spacing: 4
                    Row {
                        spacing: 8
                        Icon.Tinted { source: parent.parent.modelData.icon + ".svg"; width: 14; height: 14; tint: inspector.colors.ink }
                        Text { text: qsTranslate("Pedro", "files.sample." + parent.parent.modelData.label); color: inspector.colors.muted; font.pixelSize: 11 }
                    }
                    Text { width: parent.width; text: parent.modelData.text; color: inspector.colors.ink; font.pixelSize: 11; wrapMode: Text.WrapAnywhere }
                }
            }
        }
    }
}
