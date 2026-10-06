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
    color: controller && controller.isSelected(entry) ? colors.selected : hover.hovered ? colors.hover : "transparent"
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    Behavior on color { ColorAnimation { duration: 150 } }
    Loader {
        anchors.fill: parent
        source: card.entry.isDirectory ? "../entry/folder.qml" : "../entry/file.qml"
        onLoaded: {
            item.controller = Qt.binding(() => card.controller);
            item.entry = Qt.binding(() => card.entry);
            item.textColor = Qt.binding(() => card.colors.ink);
        }
    }
}
