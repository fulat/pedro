pragma ComponentBehavior: Bound
import QtQuick
import "palette.js" as Palette

Item {
    id: details
    objectName: "filesColumnDetails"
    property var controller
    property var entry
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    Rectangle { width: 1; height: parent.height; color: details.colors.line }
    Column {
        x: 20
        y: 28
        width: parent.width - 40
        spacing: 14
        Loader {
            width: 100
            height: 100
            anchors.horizontalCenter: parent.horizontalCenter
            source: "../entry/file.qml"
            onLoaded: {
                item.entry = Qt.binding(() => details.entry || ({}));
                item.controller = Qt.binding(() => details.controller);
                item.iconSize = 100;
                item.showName = false;
                item.nameSurface = Qt.binding(() => nameSlot);
                item.nameSize = 14;
                item.textColor = Qt.binding(() => details.colors.ink);
            }
        }
        Item { id: nameSlot; width: parent.width; height: 48 }
        Repeater {
            model: details.entry ? [
                {label: "files.sample.type", value: details.entry.type || ""},
                {label: "files.sample.size", value: details.entry.sizeText || ""},
                {label: "files.sample.modified", value: details.entry.modifiedText || ""}] : []
            delegate: Column {
                required property var modelData
                width: parent.width
                spacing: 4
                Text { text: qsTranslate("Pedro", modelData.label); color: details.colors.muted; font.pixelSize: 11 }
                Text { width: parent.width; text: modelData.value; color: details.colors.ink; font.pixelSize: 12; wrapMode: Text.Wrap }
            }
        }
    }
}
