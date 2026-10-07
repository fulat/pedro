pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Dialogs as Dialogs
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Pedro.Files 1.0
import "palette.js" as Palette
import "../confirmation" as Confirmation

Rectangle {
    id: browser
    objectName: "filesBrowser"
    readonly property var backgroundContextMenu: backgroundMenu.item
    property var informationEntry: null
    property real informationWidth: 360
    property bool informationClosing: false
    onInformationEntryChanged: { if (informationEntry) { informationClose.stop(); informationClosing = false; } }
    Timer { id: informationClose; interval: 260; onTriggered: { browser.informationEntry = null; browser.informationClosing = false; browser.informationWidth = 360; } }
    readonly property var confirmationWindow: confirmation
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    readonly property var controller: controllerLoader.item
    readonly property real toolbarHeight: controller && String(controller.directory.location).startsWith("trash:") ? 0 : 55
    color: colors.surface

    Loader {
        anchors.fill: parent
        source: "../entry/destination.qml"
        onLoaded: {
            item.objectName = "filesDropDestination";
            item.acceptsFiles = Qt.binding(() => !(directory.globalSearch && directory.search.trim().length));
            item.location = Qt.binding(() => directory.location);
        }
    }

    Loader {
        source: "../entry/shortcuts.qml"
        onLoaded: {
            item.entries = Qt.binding(() => browser.controller ? browser.controller.selectedEntries : []);
            item.destination = Qt.binding(() => browser.controller && browser.controller.selectionModel ? browser.controller.selectionModel.location : directory.location);
            item.pasteEnabled = Qt.binding(() => !directory.search.trim().length);
            item.actionRequested.connect(action => browser.controller.entryAction(action, browser.controller.selectedEntry));
        }
    }

    Connections {
        target: browser.controller
        function onEmptyRequested() { confirmation.urls = []; confirmation.open(); }
        function onMoveRequested(entry) { destination.entry = entry; destination.open(); }
        function onInformationRequested(entry) {
            if (browser.controller.viewMode === "columns" && columnsPanel.item) {
                browser.informationEntry = null;
                columnsPanel.item.showInformation(entry);
            } else browser.informationEntry = entry;
        }
        function onSelectedEntryChanged() { if (browser.informationEntry && browser.controller.selectedEntry.url) browser.informationEntry = browser.controller.selectedEntry; }
        function onRemovalRequested(urls) { confirmation.urls = urls; confirmation.open(); }
    }

    Dialogs.FolderDialog {
        id: destination
        property var entry: ({})
        title: qsTranslate("Pedro", "trash.move")
        onAccepted: Backend.trash.relocate([entry.url], selectedFolder)
    }

    Confirmation.Window {
        id: confirmation
        objectName: "trashConfirmation"
        property var urls: []
        ownerWindow: browser.Window.window
        title: qsTranslate("Pedro", urls.length ? "trash.delete" : "trash.empty")
        message: qsTranslate("Pedro", "trash.confirm")
        confirmText: title
        actionEnabled: !Backend.trash.busy
        onAccepted: {
            if (urls.length) Backend.trash.remove(urls);
            else Backend.trash.empty();
        }
    }

    Directory { id: directory; objectName: "filesDirectory"; globalSearch: true }
    Loader {
        id: controllerLoader
        source: "../../controllers/files/navigation.qml"
        onLoaded: { item.directory = directory; item.window = Qt.binding(() => browser.Window.window); }
    }

    function openBackgroundMenu(target, point) {
        if (!backgroundMenu.item || (directory.globalSearch && directory.search.trim().length)) return;
        backgroundMenu.item.directory = target;
        backgroundMenu.item.popup(point.x, point.y);
    }

    Loader {
        id: backgroundMenu
        source: "menu.qml"
        onLoaded: {
            item.parent = Qt.binding(() => browser.Window.window ? browser.Window.window.contentItem : browser);
            item.controller = Qt.binding(() => browser.controller);
            item.backdrop = Qt.binding(() => browser.Window.window.entryBackdrop);
            item.informationRequested.connect(() => { const target = item.directory; browser.informationEntry = {url: target.location, name: target.name, isDirectory: true, visualType: "folder"}; });
            item.emptyRequested.connect(() => { confirmation.urls = []; confirmation.open(); });
        }
    }
    Item {
        anchors.fill: parent
        z: 3
        PointHandler {
            acceptedButtons: Qt.LeftButton
            onActiveChanged: {
                if (!active || !browser.controller || browser.controller.viewMode === "columns") {
                    return;
                }
                const position = point.position;
                if (position.x <= sidebarPanel.width + 1 || position.x >= browser.width - 8 || position.y < browser.toolbarHeight) {
                    return;
                }
                const local = browser.mapToItem(contentLayout, position.x, position.y);
                if (!browser.controller.containsEntry(contentLayout, local)) {
                    browser.controller.clearSelection();
                }
            }
        }
    }

    Item {
        z: 2
        visible: !browser.controller || browser.controller.viewMode !== "columns"
        x: sidebarPanel.width + 1
        y: browser.toolbarHeight
        width: parent.width - x
        height: parent.height - y
        PointHandler {
            acceptedButtons: Qt.RightButton
            onActiveChanged: {
                if (!active || !browser.controller) return;
                const position = point.position;
                const local = parent.mapToItem(contentLayout, position.x, position.y);
                if (!browser.controller.containsEntry(contentLayout, local)) {
                    browser.controller.clearSelection();
                    const target = parent.mapToItem(browser.Window.window.contentItem, position.x, position.y);
                    browser.openBackgroundMenu(directory, target);
                }
            }
        }
    }

    RowLayout {
        id: contentLayout
        anchors.fill: parent
        spacing: 0
        Loader {
            id: sidebarPanel
            property real sidebarWidth: browser.controller && browser.controller.sidebarCollapsed ? 62 : 205
            Layout.preferredWidth: sidebarWidth
            clip: true
            Behavior on sidebarWidth {
                NumberAnimation { duration: 240; easing.type: Easing.InOutCubic }
            }
            Layout.fillHeight: true
            source: "sidebar.qml"
            onLoaded: item.controller = Qt.binding(() => browser.controller)
        }
        Rectangle { Layout.fillHeight: true; width: 1; color: browser.colors.line }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 17
            Layout.rightMargin: browser.controller && browser.controller.viewMode === "columns" ? 0 : 16
            spacing: 8
            Loader {
                Layout.fillWidth: true
                visible: browser.controller && !String(browser.controller.directory.location).startsWith("trash:")
                Layout.preferredHeight: visible ? 55 : 0
                source: "toolbar.qml"
                onLoaded: {
                    item.controller = Qt.binding(() => browser.controller);
                }
            }
            BusyIndicator {
                objectName: "filesLoadingIndicator"
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                visible: directory.loading && !directory.search.length
                running: visible
                palette.dark: browser.colors.accent
            }
            Text {
                visible: directory.error.length > 0 || Backend.trash.error.length > 0
                Layout.fillWidth: true
                text: directory.error || Backend.trash.error
                color: browser.colors.muted
                wrapMode: Text.WordWrap
            }
            Text {
                visible: directory.loading && directory.globalSearch && directory.search.trim().length > 0
                Layout.fillWidth: true
                text: qsTranslate("Pedro", "files.browser.searching")
                color: browser.colors.muted
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                visible: !directory.loading && directory.search.length > 0 && browser.controller.files.length + browser.controller.folders.length === 0 && !directory.error.length
                Layout.fillWidth: true
                text: qsTranslate("Pedro", "files.browser.noResults")
                color: browser.colors.muted
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
            ScrollView {
                id: contentScroll
                Loader {
                    source: "../scroll/edge.qml"
                    onLoaded: item.flickable = Qt.binding(() => contentScroll.contentItem);
                }
                Binding { target: contentScroll.contentItem; property: "boundsBehavior"; value: Flickable.DragOverBounds }
                Binding { target: contentScroll.contentItem; property: "boundsMovement"; value: Flickable.StopAtBounds }
                objectName: "filesBodyScroll"
                visible: !browser.controller || browser.controller.viewMode === "grid" || browser.controller.viewMode === "mixed"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                Layout.preferredHeight: 0
                clip: true
                rightPadding: 12
                contentWidth: availableWidth
                contentHeight: body.implicitHeight + 20
                ScrollBar.vertical: ScrollBar {
                        orientation: Qt.Vertical
                        parent: contentScroll
                        objectName: "filesBodyScrollBar"
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
                ColumnLayout {
                    id: body
                    width: contentScroll.availableWidth
                    spacing: 12
                    Item {
                        id: folderGridContainer
                        visible: !browser.controller || browser.controller.viewMode !== "list"
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.ceil(folderGrid.count / folderGrid.columns) * folderGrid.cellHeight
                        GridView {
                            id: folderGrid
                            boundsBehavior: Flickable.StopAtBounds
                            boundsMovement: Flickable.StopAtBounds
                            objectName: "filesFolderGrid"
                            visible: !browser.controller || browser.controller.viewMode !== "list"
                            readonly property bool mixed: !browser.controller || browser.controller.viewMode === "mixed"
                            readonly property int columns: Math.max(1, Math.floor(width / 120))
                            width: parent.width
                            y: virtualOffset
                            height: Math.max(0, Math.min(folderGridContainer.height - virtualOffset,
                                contentScroll.availableHeight + Math.min(0, contentScroll.contentItem.contentY - folderGridContainer.y)))
                            readonly property real virtualOffset: Math.max(0, contentScroll.contentItem.contentY - folderGridContainer.y)
                            contentY: virtualOffset
                            cellWidth: width / columns
                            cellHeight: 110
                            interactive: false
                            model: mixed ? directory.folderModel : directory.entriesModel
                            delegate: Loader {
                                id: entryCard
                                required property var entry
                                width: folderGrid.cellWidth - 8
                                height: 104
                                source: "card.qml"
                                onLoaded: { item.entry = Qt.binding(() => entryCard.entry); item.controller = Qt.binding(() => browser.controller); }
                            }
                        }
                    }
                    Loader {
                        id: mixedTable
                        visible: browser.controller && browser.controller.viewMode === "mixed" && browser.controller.files.length > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: item ? item.implicitHeight : 0
                        source: "table.qml"
                        onLoaded: {
                            item.controller = Qt.binding(() => browser.controller);
                            item.viewportHeight = Qt.binding(() => contentScroll.availableHeight);
                            item.viewportOffset = Qt.binding(() => contentScroll.contentItem.contentY - mixedTable.y - 33);
                            item.all = Qt.binding(() => browser.controller && browser.controller.viewMode === "list");
                        }
                    }
                    Text {
                        visible: !directory.loading && !directory.search.length && directory.count === 0 && !directory.error.length
                        Layout.fillWidth: true
                        text: qsTranslate("Pedro", "files.browser.empty")
                        color: browser.colors.muted
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
            Loader {
                visible: browser.controller && browser.controller.viewMode === "list"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                source: "table.qml"
                onLoaded: { item.controller = Qt.binding(() => browser.controller); item.all = true; item.embedded = false; }
            }
            Loader {
                id: columnsPanel
                visible: browser.controller && browser.controller.viewMode === "columns"
                active: visible
                Layout.fillWidth: true
                Layout.fillHeight: true
                source: "columns.qml"
                onLoaded: {
                    item.controller = Qt.binding(() => browser.controller);
                    item.detailsEnabled = true;
                    item.backgroundRequested.connect((target, point) => browser.openBackgroundMenu(target, point));
                }
            }
        }
        Loader {
            visible: !!browser.informationEntry && browser.controller.viewMode !== "columns"
            Layout.preferredWidth: visible ? 9 : 0
            Layout.fillHeight: true
            source: "divider.qml"
            onLoaded: {
                item.currentWidth = Qt.binding(() => browser.informationWidth);
                item.minimumWidth = 0;
                item.collapsible = true;
                item.collapseRequested.connect(() => { browser.informationClosing = true; informationClose.start(); });
                item.maximumWidth = Qt.binding(() => Math.max(280, Math.min(600, browser.width * 0.6)));
                item.direction = -1;
                item.resized.connect(value => { browser.informationWidth = value; });
            }
        }
        Loader {
            Layout.preferredWidth: visible ? Math.min(browser.informationWidth, browser.width * 0.6) : 0
            Layout.minimumWidth: 0
            clip: true
            opacity: browser.informationClosing ? 0 : Math.max(0, Math.min(1, (width - 60) / 180))
            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.InOutCubic } }
            Layout.fillHeight: true
            visible: !!browser.informationEntry && browser.controller.viewMode !== "columns"
            active: visible
            source: "details.qml"
            onLoaded: {
                item.columnMode = true;
                item.entry = Qt.binding(() => browser.informationEntry);
                item.controller = Qt.binding(() => browser.controller);
                item.closeRequested.connect(() => { browser.informationEntry = null; });
            }
        }
    }
}
