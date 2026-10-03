pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic
import Pedro.Files 1.0
import "palette.js" as Palette

ScrollView {
    id: columns
    objectName: "filesColumns"
    property var controller
    signal backgroundRequested(var directory, point position)
    property var locations: controller && controller.directory ? [controller.directory.location] : []
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    clip: true
    contentHeight: availableHeight
    ScrollBar.horizontal.policy: ScrollBar.AsNeeded
    Connections {
        target: columns.controller ? columns.controller.directory : null
        function onLocationChanged() { columns.locations = [columns.controller.directory.location]; }
    }
    Row {
        height: columns.availableHeight
        Repeater {
            model: columns.locations
            delegate: Item {
                id: column
                required property string modelData
                required property int index
                property string selected: ""
                function select(entry) {
                    selected = entry.id;
                    columns.controller.select(entry);
                }
                function openEntry(entry) {
                    select(entry);
                    const locations = columns.locations.slice(0, index + 1);
                    if (entry.isDirectory) locations.push(entry.url);
                    columns.locations = locations;
                }
                width: 240
                height: parent.height
                Directory {
                    id: directory
                    Component.onCompleted: { open(column.modelData); setSort(columns.controller.sortKey); }
                }
                DropArea {
                    anchors.fill: parent
                    enabled: true
                    keys: ["text/uri-list"]
                    onEntered: drag => { drag.accepted = Backend.fileTransfer.canMove(drag.urls, directory.location); }
                    onDropped: drop => {
                        if (Backend.fileTransfer.canMove(drop.urls, directory.location)) {
                            Backend.fileTransfer.move(drop.urls, directory.location);
                            drop.accept(Qt.MoveAction);
                        }
                    }
                }
                Connections {
                    target: columns.controller
                    function onSortKeyChanged() { directory.setSort(columns.controller.sortKey); }
                }
                MouseArea {
                    z: 2
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onPressed: mouse => {
                        if (columns.controller.containsEntry(columnList, mapToItem(columnList, mouse.x, mouse.y))) {
                            mouse.accepted = false;
                        }
                    }
                    onClicked: mouse => columns.backgroundRequested(directory,
                        mapToItem(columns.Window.window.contentItem, mouse.x, mouse.y))
                }
                ListView {
                    id: columnList
                    anchors.fill: parent
                    anchors.rightMargin: 9
                    clip: true
                    model: directory.entriesModel
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
                    delegate: Rectangle {
                        id: row
                        objectName: "filesColumn-" + column.index + "-" + entry.name
                        required property var entry
                        width: ListView.view.width
                        height: 38
                        radius: 7
                        color: columns.controller && columns.controller.selectedEntry.id === entry.id ? columns.colors.selected : hover.hovered ? columns.colors.hover : "transparent"
                        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                        Loader {
                            id: entryIcon
                            x: 8
                            y: 5
                            width: 28
                            height: 28
                            source: row.entry.isDirectory ? "../entry/folder.qml" : "../entry/file.qml"
                            onLoaded: {
                                item.entry = Qt.binding(() => row.entry);
                                item.showName = false;
                                item.inputEnabled = false;
                                item.iconSize = 28;
                                item.controller = column;
                            }
                        }
                        Text { x: 44; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 62; text: row.entry.name; color: columns.colors.ink; font.pixelSize: 12; elide: Text.ElideMiddle }
                        Text { visible: row.entry.isDirectory; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "›"; color: columns.colors.muted }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    const point = row.mapToItem(entryIcon, mouse.x, mouse.y);
                                    entryIcon.item.openMenu(point.x, point.y);
                                } else {
                                    entryIcon.item.activate();
                                }
                            }
                        }
                    }
                }
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: columns.colors.line }
            }
        }
    }
}
