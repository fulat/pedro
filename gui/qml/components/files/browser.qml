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
    readonly property var confirmationWindow: confirmation
    readonly property var colors: Palette.colors(Backend.appearanceMode)
    readonly property var controller: controllerLoader.item
    readonly property real toolbarHeight: controller && String(controller.directory.location).startsWith("trash:") ? 0 : 55
    color: colors.surface

    DropArea {
        anchors.fill: parent
        enabled: !(directory.globalSearch && directory.search.trim().length)
        keys: ["text/uri-list"]
        onEntered: drag => { drag.accepted = String(directory.location).startsWith("trash:") ? drag.urls.length > 0 && !Backend.trash.busy : Backend.fileTransfer.canMove(drag.urls, directory.location); }
        onDropped: drop => {
            if (String(directory.location).startsWith("trash:") && drop.urls.length && !Backend.trash.busy) {
                Backend.trash.move(drop.urls);
                drop.accept(Qt.MoveAction);
            } else if (Backend.fileTransfer.canMove(drop.urls, directory.location)) {
                Backend.fileTransfer.move(drop.urls, directory.location);
                drop.accept(Qt.MoveAction);
            }
        }
    }

    Shortcut {
        sequence: "Space"
        enabled: browser.Window.window.active && browser.controller && !!browser.controller.selectedEntry.url
            && !browser.controller.selectedEntry.isDirectory && !browser.controller.selectedEntry.inTrash
            && !(browser.Window.window.activeFocusItem && browser.Window.window.activeFocusItem.readOnly === false)
        onActivated: browser.controller.previewEntry(browser.controller.selectedEntry)
    }

    Shortcut {
        sequence: "Ctrl+C"
        enabled: browser.Window.window.active && browser.controller && !!browser.controller.selectedEntry.url
            && !(browser.Window.window.activeFocusItem && browser.Window.window.activeFocusItem.selectedText !== undefined)
        onActivated: browser.controller.entryAction("copy", browser.controller.selectedEntry)
    }

    Shortcut {
        sequence: "Delete"
        enabled: browser.Window.window.active && browser.controller && !!browser.controller.selectedEntry.url
            && !(browser.Window.window.activeFocusItem && browser.Window.window.activeFocusItem.readOnly === false)
        onActivated: browser.controller.entryAction(browser.controller.selectedEntry.inTrash ? "remove" : "trash", browser.controller.selectedEntry)
    }

    Connections {
        target: browser.controller
        function onEmptyRequested() { confirmation.urls = []; confirmation.open(); }
        function onMoveRequested(entry) { destination.entry = entry; destination.open(); }
        function onInformationRequested(entry) { information.entry = entry; information.open(); }
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
        onLoaded: item.directory = directory
    }

    function openBackgroundMenu(target, point) {
        if (directory.globalSearch && directory.search.trim().length) return;
        backgroundMenu.item.directory = target;
        backgroundMenu.item.popup(point.x, point.y);
    }

    Loader {
        id: backgroundMenu
        source: "menu.qml"
        onLoaded: {
            item.parent = browser.Window.window.contentItem;
            item.backdrop = Qt.binding(() => browser.Window.window.entryBackdrop);
            item.informationRequested.connect(() => { information.entry = null; information.open(); });
            item.emptyRequested.connect(() => { confirmation.urls = []; confirmation.open(); });
        }
    }
    Dialog {
        id: information
        property var entry: null
        objectName: "filesDirectoryInformation"
        parent: browser.Window.window.contentItem
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: Math.min(400, parent.width - 32)
        title: qsTranslate("Pedro", "folder.menu.properties")
        header: Label {
            text: information.title
            color: browser.colors.ink
            font.pixelSize: 14
            padding: 16
        }
        standardButtons: Dialog.Ok
        background: Rectangle {
            color: browser.colors.light ? "#f1f5fb" : "#202b3a"
            radius: 12
            border.color: browser.colors.line
        }
        contentItem: Label {
            color: browser.colors.ink
            text: information.entry ? information.entry.name + "\n\n" + (information.entry.originalPath || information.entry.path)
                + "\n\n" + (information.entry.type || "") + "  " + (information.entry.sizeText || "")
                + (information.entry.deletedText ? "\n\n" + qsTranslate("Pedro", "trash.deleted") + ": " + information.entry.deletedText : "")
                : backgroundMenu.item && backgroundMenu.item.directory
                ? backgroundMenu.item.directory.name + "\n\n" + (backgroundMenu.item.directory.path || backgroundMenu.item.directory.location)
                    + "\n\n" + (backgroundMenu.item.directory.folders.length + backgroundMenu.item.directory.files.length) + " " + qsTranslate("Pedro", "files.sample.itemsLabel") : ""
            wrapMode: Text.WrapAnywhere
        }
    }
    Item {
        anchors.fill: parent
        z: 3
        PointHandler {
            acceptedButtons: Qt.LeftButton
            onActiveChanged: {
                if (!active || !browser.controller) {
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

    MouseArea {
        z: 2
        visible: !browser.controller || browser.controller.viewMode !== "columns"
        x: sidebarPanel.width + 1
        y: browser.toolbarHeight
        width: parent.width - x
        height: parent.height - y
        acceptedButtons: Qt.RightButton
        onPressed: mouse => {
            const point = mapToItem(contentLayout, mouse.x, mouse.y);
            if (browser.controller.containsEntry(contentLayout, point)) {
                mouse.accepted = false;
            }
        }
        onClicked: mouse => {
            const point = mapToItem(browser.Window.window.contentItem, mouse.x, mouse.y);
            browser.openBackgroundMenu(directory, point);
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
            Layout.rightMargin: 16
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
                objectName: "filesBodyScroll"
                visible: !browser.controller || browser.controller.viewMode === "grid" || browser.controller.viewMode === "mixed"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                Layout.preferredHeight: 0
                clip: true
                contentWidth: availableWidth
                contentHeight: body.implicitHeight
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
                ColumnLayout {
                    id: body
                    width: contentScroll.availableWidth
                    spacing: 12
                    GridView {
                        id: folderGrid
                        objectName: "filesFolderGrid"
                        visible: !browser.controller || browser.controller.viewMode !== "list"
                        readonly property bool mixed: !browser.controller || browser.controller.viewMode === "mixed"
                        readonly property int columns: Math.max(1, Math.floor(width / 120))
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.ceil(count / columns) * cellHeight
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
                    Loader {
                        visible: browser.controller && browser.controller.viewMode === "mixed" && browser.controller.files.length > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: item ? item.implicitHeight : 0
                        source: "table.qml"
                        onLoaded: {
                            item.controller = Qt.binding(() => browser.controller);
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
                visible: browser.controller && browser.controller.viewMode === "columns"
                active: visible
                Layout.fillWidth: true
                Layout.fillHeight: true
                source: "columns.qml"
                onLoaded: {
                    item.controller = Qt.binding(() => browser.controller);
                    item.backgroundRequested.connect((target, point) => browser.openBackgroundMenu(target, point));
                }
            }
        }
    }
}
