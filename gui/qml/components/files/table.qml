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
            color: table.controller && table.controller.selectedEntry.id === modelData.id ? table.colors.selected : "transparent"
            border.color: "transparent"
            TapHandler { onTapped: table.controller.select(row.modelData); onDoubleTapped: table.controller.openEntry(row.modelData) }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: mouse => {
                    table.controller.select(row.modelData);
                    const point = row.mapToItem(entryIcon, mouse.x, mouse.y);
                    entryIcon.item.openMenu(point.x, point.y);
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            Row {
                anchors.fill: parent
                Item {
                    width: table.width * 0.28; height: parent.height
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
                            item.inputEnabled = false;
                            item.iconSize = 34;
                            item.actionRequested.connect(action => { if (action === "open") table.controller.openEntry(row.modelData); });
                        }
                    }
                    Text { x: 60; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 68; elide: Text.ElideMiddle; text: row.modelData.name; color: table.colors.ink; font.pixelSize: 12; font.bold: true }
                }
                Text { width: table.width * 0.18; height: parent.height; verticalAlignment: Text.AlignVCenter; text: row.modelData.type; color: table.colors.muted; font.pixelSize: 12; elide: Text.ElideRight }
                Text { width: table.width * 0.115; height: parent.height; verticalAlignment: Text.AlignVCenter; text: row.modelData.sizeText; color: table.colors.muted; font.pixelSize: 12; elide: Text.ElideRight }
                Text { width: table.width * 0.195; height: parent.height; verticalAlignment: Text.AlignVCenter; text: row.modelData.modifiedText; color: table.colors.muted; font.pixelSize: 12; elide: Text.ElideRight }
                Item {
                    width: table.width * 0.18; height: parent.height
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "—"; color: table.colors.muted; font.pixelSize: 12 }
                }
                Text { text: "•••"; height: parent.height; verticalAlignment: Text.AlignVCenter; color: table.colors.ink }
            }
        }
    }
}
