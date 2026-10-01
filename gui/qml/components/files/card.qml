pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../desktop" as Desktop
import "palette.js" as Palette

Rectangle {
    id: card
    property var entry: ({name: "designs", count: 0, size: "", tag: ""})
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    implicitHeight: 112
    radius: 11
    color: hover.hovered ? colors.selected : colors.card
    border.color: colors.line
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    Behavior on color { ColorAnimation { duration: 150 } }
    Desktop.Icon { x: 9; y: 9; width: 54; height: 54; kind: "folder" }
    Text { anchors.right: parent.right; anchors.rightMargin: 12; y: 11; text: "•••"; color: card.colors.ink; font.pixelSize: 12 }
    Column {
        x: 69
        y: 13
        width: parent.width - 90
        spacing: 4
        Text { text: qsTranslate("Pedro", "files.sample." + card.entry.name); width: parent.width; elide: Text.ElideRight; color: card.colors.ink; font.pixelSize: 12; font.bold: true }
        Text { text: qsTranslate("Pedro", "files.sample.items").arg(card.entry.count); color: card.colors.muted; font.pixelSize: 12 }
        Text { text: card.entry.size; color: card.colors.muted; font.pixelSize: 12 }
        Loader {
            visible: card.entry.tag !== ""
            source: "badge.qml"
            onLoaded: {
                item.text = Qt.binding(() => qsTranslate("Pedro", "files.sample." + card.entry.tag));
                item.tone = Qt.binding(() => card.entry.tag);
            }
        }
    }
}
