pragma ComponentBehavior: Bound
import QtQuick
import "../desktop" as Desktop
import "palette.js" as Palette

Rectangle {
    id: card
    objectName: "filesCard-" + entry.name
    property var entry: ({name: "", icon: "folder"})
    property var controller
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    implicitHeight: 108
    radius: 10
    color: hover.hovered || controller && controller.selectedEntry.id === entry.id ? colors.selected : "transparent"
    TapHandler { onTapped: card.controller.select(card.entry); onDoubleTapped: card.controller.openEntry(card.entry) }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    Behavior on color { ColorAnimation { duration: 150 } }
    Desktop.Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8
        width: 64
        height: 64
        kind: card.entry.icon || "file"
    }
    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 6
        y: 77
        text: card.entry.name
        color: card.colors.ink
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideMiddle
    }
}
