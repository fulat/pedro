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
    property var detailEntry: null
    property var detailController: null
    property var locations: controller && controller.directory ? [controller.directory.location] : []
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    clip: true
    contentHeight: availableHeight
    ScrollBar.horizontal.policy: ScrollBar.AsNeeded
    Connections {
        target: columns.controller ? columns.controller.directory : null
        function onLocationChanged() { columns.locations = [columns.controller.directory.location]; columns.detailEntry = null; }
        function onSearchChanged() { if (columns.controller.directory.search.length) columns.locations = [columns.controller.directory.location]; }
    }
    Connections {
        target: columns.controller
        function onSelectedEntryChanged() {
            if (columns.detailEntry && columns.detailEntry.id !== columns.controller.selectedEntry.id) columns.detailEntry = null;
            else if (columns.detailEntry) columns.detailEntry = columns.controller.selectedEntry;
        }
    }
    property Item contextSurface: Item {
        parent: columns
        anchors.fill: parent
        z: 2
        PointHandler {
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onActiveChanged: {
                if (!active || !columns.controller) return;
                const local = parent.mapToItem(columnRow, point.position.x, point.position.y);
                if (columns.controller.containsEntry(columnRow, local)) return;
                const index = Math.max(0, Math.min(columnRepeater.count - 1, Math.floor(local.x / 240)));
                const column = columnRepeater.itemAt(index);
                if (!column) return;
                columns.controller.clearSelection(column.directory);
                if (point.pressedButtons & Qt.RightButton) columns.backgroundRequested(column.directory,
                    parent.mapToItem(columns.Window.window.contentItem, point.position.x, point.position.y));
            }
        }
    }
    Row {
        id: columnRow
        height: columns.availableHeight
        Repeater {
            id: columnRepeater
            model: columns.locations
            delegate: Item {
                id: column
                required property string modelData
                required property int index
                property string selected: ""
                readonly property var directory: directoryModel
                function select(entry, contextMenu = false) {
                    selected = entry.id;
                    columns.controller.select(entry, contextMenu, directoryModel);
                    if (!entry.isDirectory && !contextMenu) {
                        columns.locations = columns.locations.slice(0, index + 1);
                        columns.detailController = column;
                        columns.detailEntry = entry;
                    }
                }
                function contextEntries(entry) { return columns.controller.contextEntries(entry); }
                function handleEntryAction(action, entry) {
                    if (action === "open") openEntry(entry);
                    else columns.controller.handleEntryAction(action, entry);
                }
                function openEntry(entry) {
                    select(entry);
                    const locations = columns.locations.slice(0, index + 1);
                    if (entry.isDirectory) {
                        columns.controller.directory.search = "";
                        columns.detailEntry = null;
                        locations.push(entry.url);
                    }
                    else columns.controller.previewEntry(entry);
                    columns.locations = locations;
                }
                width: 240
                height: parent.height
                Directory {
                    id: directoryModel
                    Component.onCompleted: {
                        open(column.modelData);
                        setSort(columns.controller.sortKey);
                        if (column.index === columns.locations.length - 1) columns.controller.selectionModel = directoryModel;
                    }
                }
                Loader {
                    anchors.fill: parent
                    source: "../entry/destination.qml"
                    onLoaded: {
                        item.acceptsFiles = Qt.binding(() => !columns.controller.directory.search.trim().length);
                        item.location = Qt.binding(() => directoryModel.location);
                    }
                }
                Connections {
                    target: directoryModel
                    function onContentsChanged() { columns.controller.refreshSelection(directoryModel); }
                }
                Connections {
                    target: columns.controller
                    function onSortKeyChanged() { directoryModel.setSort(columns.controller.sortKey); }
                }
                ListView {
                    id: columnList
                    anchors.fill: parent
                    anchors.rightMargin: 9
                    clip: true
                    model: columns.controller.directory.search.length ? columns.controller.directory.entriesModel : directoryModel.entriesModel
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
                        color: columns.controller && columns.controller.isSelected(entry) ? columns.colors.selected : hover.hovered ? columns.colors.hover : "transparent"
                        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                        Item { id: nameSlot; x: 44; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 62; height: 32; z: 5 }
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
                                item.nameSurface = Qt.binding(() => nameSlot);
                                item.nameAlignment = Text.AlignLeft;
                                item.textColor = Qt.binding(() => columns.colors.ink);
                                item.inputSurface = row;
                                item.activateOnClick = Qt.binding(() => row.entry.isDirectory);
                                item.iconSize = 28;
                                item.controller = column;
                            }
                        }
                        Text { visible: row.entry.isDirectory; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "›"; color: columns.colors.muted }
                    }
                }
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: columns.colors.line }
            }
        }
        Loader {
            active: !!columns.detailEntry
            visible: active
            width: active ? 260 : 0
            height: parent.height
            source: "details.qml"
            onLoaded: {
                item.entry = Qt.binding(() => columns.detailEntry);
                item.controller = Qt.binding(() => columns.detailController);
            }
        }
    }
}
