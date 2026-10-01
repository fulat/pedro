pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../desktop" as Desktop
import "palette.js" as Palette

Rectangle {
    id: card
    objectName: "filesCard-" + entry.name
    property var entry: ({name: "", sizeText: "", url: ""})
    property var controller
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    implicitHeight: 112
    radius: 11
    color: hover.hovered || card.controller && card.controller.selectedEntry.id === card.entry.id ? colors.selected : colors.card
    border.color: colors.line
    TapHandler { onTapped: card.controller.select(card.entry); onDoubleTapped: card.controller.openEntry(card.entry) }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    Behavior on color { ColorAnimation { duration: 150 } }
    Desktop.Icon { x: 9; y: 9; width: 54; height: 54; kind: "folder" }
    Text { anchors.right: parent.right; anchors.rightMargin: 12; y: 11; text: "•••"; color: card.colors.ink; font.pixelSize: 12 }
    Column {
        x: 69
        y: 13
        width: parent.width - 90
        spacing: 4
        Text { text: card.entry.name; width: parent.width; elide: Text.ElideRight; color: card.colors.ink; font.pixelSize: 12; font.bold: true }
        Text { text: qsTranslate("Pedro", "files.browser.folder"); color: card.colors.muted; font.pixelSize: 12 }
        Text { text: card.entry.sizeText || ""; color: card.colors.muted; font.pixelSize: 12 }

    }
}
