pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "palette.js" as Palette

Item {
    id: table
    property bool embedded: true
    property bool folders: false
    property bool all: true
    property var controller
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    width: parent.width
    implicitHeight: embedded ? 33 + fileList.count * 43 : 0
    Row {
        width: parent.width; height: 33
        Repeater {
            model: [{key: "name", ratio: 0.28}, {key: "type", ratio: 0.18}, {key: "size", ratio: 0.115}, {key: "modified", ratio: 0.195}, {key: "tags", ratio: 0.18}]
            delegate: Text { required property var modelData; width: table.width * modelData.ratio; height: 33; verticalAlignment: Text.AlignVCenter; leftPadding: 7; text: qsTranslate("Pedro", "files.sample." + modelData.key) + (modelData.key === "name" ? "  ↑" : ""); color: table.colors.muted; font.pixelSize: 12; elide: Text.ElideRight }
        }
    }
    ListView {
        id: fileList
        Loader {
            source: "../scroll/edge.qml"
            onLoaded: item.flickable = Qt.binding(() => fileList);
        }
        bottomMargin: table.embedded ? 0 : 20
        boundsBehavior: Flickable.StopAtBounds
        boundsMovement: Flickable.StopAtBounds
        y: 33
        objectName: table.embedded ? "filesMixedList" : "filesFileList"
        width: table.width
        height: table.embedded ? count * 43 : Math.max(0, table.height - 33)
        interactive: !table.embedded
        clip: true
        ScrollBar.vertical: ScrollBar {
                        orientation: Qt.Vertical
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 8
                        visible: size < 1
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 6
                            implicitHeight: 6
                            radius: 3
                            color: "#c2bdba"
                            opacity: parent.pressed ? 1 : parent.hovered ? 0.9 : 0.7
                        }
                        background: Item {}
                    }
        model: table.controller && table.controller.directory ? (table.all ? table.controller.directory.entriesModel : table.folders ? table.controller.directory.folderModel : table.controller.directory.fileModel) : null
        delegate: Rectangle {
            id: row
            required property var entry
            readonly property var modelData: entry
            width: table.width; height: 43; radius: 9
            color: table.controller && table.controller.isSelected(modelData) ? table.colors.selected : hover.hovered ? table.colors.hover : "transparent"
            border.color: "transparent"
            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
            Row {
                z: 1
                anchors.fill: parent
                Item {
                    width: table.width * 0.28; height: parent.height
                    Item { id: nameSlot; x: 60; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 68; height: 32; z: 5 }
                    Loader {
                        id: entryIcon
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        height: 34
                        source: row.modelData.isDirectory ? "../entry/folder.qml" : "../entry/file.qml"
                        onLoaded: {
                            item.entry = Qt.binding(() => row.modelData);
                            item.showName = false;
                            item.nameSurface = Qt.binding(() => nameSlot);
                            item.nameAlignment = Text.AlignLeft;
                            item.textColor = Qt.binding(() => table.colors.ink);
                            item.inputSurface = row;
                            item.iconSize = 34;
                            item.controller = Qt.binding(() => table.controller);
                        }
                    }
                }
                Text { width: table.width * 0.18; height: parent.height; verticalAlignment: Text.AlignVCenter; text: row.modelData.type; color: table.colors.muted; font.pixelSize: 12; elide: Text.ElideRight }
                Text { width: table.width * 0.115; height: parent.height; verticalAlignment: Text.AlignVCenter; text: row.modelData.sizeText; color: table.colors.muted; font.pixelSize: 12; elide: Text.ElideRight }
                Text { width: table.width * 0.195; height: parent.height; verticalAlignment: Text.AlignVCenter; text: row.modelData.modifiedText; color: table.colors.muted; font.pixelSize: 12; elide: Text.ElideRight }
                Item {
                    width: table.width * 0.18; height: parent.height
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "—"; color: table.colors.muted; font.pixelSize: 12 }
                }
            }
        }
    }
}
