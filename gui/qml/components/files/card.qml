pragma ComponentBehavior: Bound
import QtQuick
import "palette.js" as Palette

Rectangle {
    id: card
    objectName: "filesCard-" + entry.name
    property var entry: ({name: "", icon: "folder"})
    property var controller
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    implicitHeight: 108
    radius: 10
    color: controller && controller.selectedEntry.id === entry.id ? colors.selected : hover.hovered ? colors.hover : "transparent"
    TapHandler { onTapped: card.controller.select(card.entry); onDoubleTapped: card.controller.openEntry(card.entry) }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    Behavior on color { ColorAnimation { duration: 150 } }
    Loader {
        anchors.fill: parent
        source: card.entry.isDirectory ? "../entry/folder.qml" : "../entry/file.qml"
        onLoaded: {
            item.entry = Qt.binding(() => card.entry);
            item.textColor = Qt.binding(() => card.colors.ink);
            item.contextRequested.connect(() => card.controller.select(card.entry));
            item.actionRequested.connect(action => { if (action === "open") card.controller.openEntry(card.entry); });
        }
    }
}
