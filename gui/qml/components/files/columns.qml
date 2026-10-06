pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic
import Pedro.Files 1.0
import "palette.js" as Palette

ScrollView {
    id: columns
    Binding { target: columns.contentItem; property: "boundsBehavior"; value: Flickable.StopAtBounds }
    Binding { target: columns.contentItem; property: "boundsMovement"; value: Flickable.StopAtBounds }
    objectName: "filesColumns"
    property var controller
    signal backgroundRequested(var directory, point position)
    property bool detailsEnabled: true
    property var detailEntry: null
    property var detailController: null
    property var locations: controller && controller.directory ? [controller.directory.location] : []
    property var pendingLocations: null
    function updateLocations(locations) {
        pendingLocations = locations;
        // Keep delegates alive until the current pointer/signal delivery finishes.
        Qt.callLater(applyLocations);
    }
    function applyLocations() {
        const locations = pendingLocations;
        pendingLocations = null;
        if (!locations || (locations.length === columns.locations.length && locations.every((location, index) => String(location) === String(columns.locations[index])))) return;
        for (let index = 0; index < columnRepeater.count; ++index) {
            const column = columnRepeater.itemAt(index);
            if (column && (index >= locations.length || String(locations[index]) !== String(columns.locations[index]))) {
                if (columns.controller.selectionModel === column.directory) columns.controller.clearSelection(columns.controller.directory);
                if (columns.detailController === column) {
                    columns.detailController = null;
                    columns.detailEntry = null;
                }
            }
        }
        columns.locations = locations;
    }
    function showInformation(entry) {
        for (let index = 0; index < columnRepeater.count; ++index) {
            const column = columnRepeater.itemAt(index);
            if (column.directory.folders.concat(column.directory.files).some(candidate => candidate.url === entry.url)) {
                column.select(entry);
                columns.updateLocations(columns.locations.slice(0, index + 1));
                columns.detailController = column;
                columns.detailEntry = entry;
                return;
            }
        }
    }
    function revealLastColumn() {
        Qt.callLater(() => {
            if (columns.contentItem && columns.contentItem.contentX !== undefined)
                columns.contentItem.contentX = Math.max(0, columnRow.width - columns.availableWidth);
        });
    }
    onDetailEntryChanged: revealLastColumn()
    onLocationsChanged: revealLastColumn()
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    clip: true
    contentWidth: columnRow.width
    contentHeight: availableHeight
    ScrollBar.horizontal.interactive: true
    ScrollBar.vertical.policy: ScrollBar.AlwaysOff
    ScrollBar.horizontal.policy: ScrollBar.AsNeeded
    Connections {
        target: columns.controller ? columns.controller.directory : null
        function onLocationChanged() { columns.updateLocations([columns.controller.directory.location]); columns.detailEntry = null; }
        function onSearchChanged() { if (columns.controller.directory.search.length) columns.updateLocations([columns.controller.directory.location]); }
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
                let column = null;
                for (let index = 0; index < columnRepeater.count; ++index) {
                    const candidate = columnRepeater.itemAt(index);
                    if (local.x >= candidate.x && local.x < candidate.x + candidate.width) {
                        if (local.x >= candidate.x + candidate.width - 20) return;
                        column = candidate;
                        break;
                    }
                }
                if (!column && local.x >= columnRow.width) column = columnRepeater.itemAt(columnRepeater.count - 1);
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
        Row {
            id: directoryRow
            height: columnRow.height
            Repeater {
                id: columnRepeater
                model: columns.locations.length
                delegate: Item {
                    id: column
                    objectName: "filesDirectoryColumn-" + index
                    readonly property string location: columns.locations[index] || ""
                    required property int index
                    property string selected: ""
                    readonly property var directory: directoryModel
                    function select(entry, contextMenu = false) {
                        selected = entry.id;
                        columns.controller.select(entry, contextMenu, directoryModel);
                        if (!entry.isDirectory && !contextMenu) {
                            columns.updateLocations(columns.locations.slice(0, index + 1));
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
                            columns.controller.rememberPlaceLocation(entry.url);
                        }
                        else columns.controller.previewEntry(entry);
                        columns.updateLocations(locations);
                    }
                    property real preferredWidth: 240
                    width: preferredWidth
                    height: parent.height
                    Directory {
                        id: directoryModel
                        Component.onCompleted: {
                            open(column.location);
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
                        target: column
                        function onLocationChanged() { Qt.callLater(() => { if (column.location.length) directoryModel.open(column.location); }); }
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
                        objectName: "filesColumnList"
                        Loader {
                            source: "../scroll/edge.qml"
                            onLoaded: item.flickable = Qt.binding(() => columnList);
                        }
                        bottomMargin: 20
                        boundsBehavior: Flickable.StopAtBounds
                        boundsMovement: Flickable.StopAtBounds
                        anchors.fill: parent
                        anchors.rightMargin: 20
                        clip: true
                        model: columns.controller.directory.search.length ? columns.controller.directory.entriesModel : directoryModel.entriesModel
                        ScrollBar.vertical: ScrollBar {
                            objectName: "filesColumnScrollBar"
                            parent: column
                            anchors.rightMargin: 9
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
                            color: column.selected === entry.id || (columns.controller && columns.controller.isSelected(entry)) ? columns.colors.selected : hover.hovered ? columns.colors.hover : "transparent"
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
                            Text { visible: row.entry.isDirectory; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: "›"; color: columns.colors.muted }
                        }
                    }
                    Loader {
                        anchors.right: parent.right
                        height: parent.height
                        width: 9
                        z: 10
                        source: "divider.qml"
                        onLoaded: {
                            item.currentWidth = Qt.binding(() => column.preferredWidth);
                            item.minimumWidth = 180;
                            item.maximumWidth = 280;
                            item.resized.connect(value => { column.preferredWidth = value; });
                        }
                    }
                }
            }
        }
        Loader {
            id: informationColumn
            active: columns.detailsEnabled && !!columns.detailEntry
            visible: active
            width: active ? Math.max(260, columns.availableWidth - directoryRow.width) : 0
            height: parent.height
            source: "details.qml"
            onLoaded: {
                item.columnMode = true;
                item.entry = Qt.binding(() => columns.detailEntry);
                item.controller = Qt.binding(() => columns.detailController);
                item.closeRequested.connect(() => { columns.detailEntry = null; });
            }
        }

    }
}
