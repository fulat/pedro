import QtQuick
import "transfer" as Transfer
import QtQuick.Controls.Basic
import QtQuick.Window

import "../controllers" as Controllers
import "../scripts/constants.js" as Constants
import "../scripts/theme.js" as Theme
import "../scripts/window/placement.js" as Placement

// Declares the shell window and exposes controller-owned state to child views.
ApplicationWindow {
    id: window

    property alias controller: applicationController
    property alias panelMode: applicationController.panelMode
    property alias panelSource: applicationController.panelSource
    property alias panelAnchorX: applicationController.panelAnchorX
    property alias currentTime: applicationController.currentTime
    property alias selectedDesktopIds: applicationController.selectedDesktopIds
    property alias desktopDragging: applicationController.desktopDragging
    property alias installedApps: applicationController.installedApps
    property alias pinnedApps: applicationController.pinnedApps
    property alias desktopShortcuts: applicationController.desktopShortcuts
    property alias desktopShortcutRepeater: applicationController.desktopShortcutRepeater
    property alias desktopContextMenu: applicationController.desktopContextMenu
    property alias sideBar: applicationController.sideBar
    property alias topBar: applicationController.topBar
    property alias desktopObstacles: applicationController.desktopObstacles

    readonly property bool trashQuickWindowActive: filesWindowLoader.item !== null
        && filesWindowLoader.item.visible && filesWindowLoader.item.active
        && filesWindowLoader.item.controller !== null
        && filesWindowLoader.item.controller.directory !== null
        && filesWindowLoader.item.controller.directory.place === "trash"
    readonly property bool filesQuickWindowVisible: filesWindowLoader.item ? filesWindowLoader.item.visible : false
    readonly property real designAspectRatio: Constants.DESIGN_ASPECT_RATIO
    readonly property real developmentWidth: Screen.desktopAvailableWidth > 0 ? Math.min(1600, Screen.desktopAvailableWidth * 0.82) : 1280
    readonly property real developmentHeight: Screen.desktopAvailableHeight > 0 ? Math.min(developmentWidth / designAspectRatio, Screen.desktopAvailableHeight * 0.82) : developmentWidth / designAspectRatio
    readonly property real dockIconSize: applicationController.dockIconSize
    readonly property real dockTileSize: applicationController.dockTileSize
    readonly property real dockSpacing: applicationController.dockSpacing

    flags: Qt.Window
    title: qsTranslate("Pedro", "shell.productName")
    // Start as a regular resizable window with native window controls.
    visibility: Window.Windowed
    color: Theme.desktopBackground
    visible: true
    width: developmentWidth
    height: developmentHeight
    minimumWidth: Constants.MINIMUM_WIDTH
    minimumHeight: Constants.MINIMUM_HEIGHT

    // Connects the presentation object graph to the application controller.
    Controllers.Application {
        id: applicationController

        objectName: "applicationController"
        window: window
        filesQuickWindow: filesWindowLoader.item
    }

    // All Pedro-owned windows can reuse the same QML window decoration.
    Loader {
        id: filesWindowLoader
        source: "window/frame.qml"

        onLoaded: window.configureFilesWindow(item)
    }

    property var informationWindows: []
    Component {
        id: informationComponent
        Loader {
            id: informationLoader
            property var entry
            source: "window/frame.qml"
            onLoaded: {
                item.title = entry.name || "";
                item.width = 400;
                item.height = Math.min(900, item.Screen.desktopAvailableHeight * 0.9);
                item.minimumWidth = 340;
                item.minimumHeight = 420;
                item.headerHeight = 34;
                item.contentSource = "../files/details.qml";
                item.contentItemChanged.connect(() => {
                    if (item.contentItem) {
                        item.contentItem.entry = Qt.binding(() => informationLoader.entry);
                        item.contentItem.closeRequested.connect(() => item.close());
                    }
                });
                if (item.contentItem) {
                    item.contentItem.entry = Qt.binding(() => informationLoader.entry);
                    item.contentItem.closeRequested.connect(() => item.close());
                }
                item.closing.connect(() => {
                    window.informationWindows = window.informationWindows.filter(value => value !== informationLoader);
                    Qt.callLater(() => informationLoader.destroy());
                });
                window.placeQuickWindow(item);
                item.show();
                window.placeMappedWindow(item);
                Backend.activateWindow(item);
            }
        }
    }
    function openInformationWindow(entry) {
        const existing = informationWindows.find(loader => String(loader.entry.url) === String(entry.url));
        if (existing && existing.item) { Backend.activateWindow(existing.item, true); return; }
        const loader = informationComponent.createObject(window, {entry: entry});
        informationWindows = informationWindows.concat([loader]);
    }

    property var previewWindows: []

    Component {
        id: previewWindowComponent
        Loader {
            id: sessionLoader
            property var session
            source: "preview/window.qml"
            onLoaded: {
                item.preview = session;
                item.positionWindow = window.placeQuickWindow;
                item.mappedWindow = window.placeMappedWindow;
                item.finished.connect(() => {
                    window.previewWindows = window.previewWindows.filter(candidate => candidate !== sessionLoader);
                    Qt.callLater(() => {
                        sessionLoader.active = false;
                        Backend.releasePreview(session);
                        sessionLoader.destroy();
                    });
                });
                item.open();
            }
        }
    }

    Connections {
        target: Backend
        function onPreviewRequested(session) {
            ++window.desktopFocusGeneration;
            const existing = window.previewWindows.find(candidate => candidate.session === session);
            if (existing) {
                if (existing.item) existing.item.activateViewer();
                return;
            }
            const loader = previewWindowComponent.createObject(window, {session: session});
            window.previewWindows = window.previewWindows.concat([loader]);
        }
    }

    Transfer.Window { operation: Backend.fileTransfer; ownerWindow: window }

    Loader {
        source: "entry/shortcuts.qml"
        onLoaded: {
            item.entries = Qt.binding(() => window.selectedDesktopIds.length ? window.controller.contextEntries({id: window.selectedDesktopIds[0]}) : []);
            item.destination = Qt.binding(() => Backend.desktopModel.directory);
            item.actionRequested.connect(action => window.controller.entryAction(action, {id: window.selectedDesktopIds[0]}));
        }
    }

    function captureWindows() {
        return [filesWindowLoader, networkWindowLoader].concat(folderWindows, previewWindows.map(loader => loader.item))
            .map(loader => loader ? loader.item : null)
            .filter(item => item && item.visible && item.visibility !== Window.Minimized);
    }

    property var placementReservations: []

    function placeQuickWindow(item) {
        placementReservations = placementReservations.filter(record => record.item && record.item !== item);
        const visible = captureWindows().filter(other => other !== item)
            .map(other => ({x: other.x, y: other.y, width: other.width, height: other.height}));
        const occupied = visible.concat(placementReservations.map(record => record.rect));
        const point = Placement.place({width: item.width, height: item.height},
            {x: item.Screen.virtualX, y: item.Screen.virtualY,
                width: item.Screen.desktopAvailableWidth, height: item.Screen.desktopAvailableHeight},
            occupied, {x: window.x + (window.width - item.width) / 2,
                y: window.y + (window.height - item.height) / 2});
        item.x = point.x;
        item.y = point.y;
        placementReservations = placementReservations.concat([{item: item,
            rect: {x: point.x, y: point.y, width: item.width, height: item.height}}]);
        item.visibleChanged.connect(() => {
            if (!item.visible) window.placementReservations = window.placementReservations.filter(record => record.item !== item);
        });
    }

    function placeMappedWindow(item) {
        if (typeof Backend.placeWindow === "function") Backend.placeWindow(item, window.title);
    }

    function configureFilesWindow(item) {
        item.objectName = "filesQuickWindow";
        item.title = Qt.binding(() => qsTranslate("Pedro", "app.files.name"));
        item.contentSource = Qt.resolvedUrl("files/browser.qml");
        item.surfaceColor = Qt.binding(() => Backend.appearanceMode === "light" ? "#70e8edf5" : "#50101825");
        item.titleColor = Qt.binding(() => Backend.appearanceMode === "light" ? "#10164d" : "#eef3ff");
        item.headerSource = Qt.resolvedUrl("files/header.qml");
        item.headerHeight = 58;
        item.headerOffset = Qt.binding(() => item.controller && item.controller.sidebarCollapsed
            ? item.titleOffset + item.titleContentWidth + 16 : 222);
        item.titleOffset = 88;
        item.titleSize = 16;
        item.titleInteractive = true;
        item.titleClicked.connect(() => {
            if (item.controller) item.controller.sidebarCollapsed = !item.controller.sidebarCollapsed;
        });
        item.contentMargin = 0;
        item.contentTopGap = 0;
        item.windowRadius = 22;
        item.minimumWidth = Screen.desktopAvailableWidth > 0 ? Math.min(900, Screen.desktopAvailableWidth * 0.86) : 900;
        item.minimumHeight = Screen.desktopAvailableHeight > 0
            ? Math.min(720, Screen.desktopAvailableHeight * 0.82) : 720;
        item.transientParent = window;
        item.width = item.minimumWidth;
        item.height = item.minimumHeight;
        item.x = window.x + Math.round((window.width - item.width) / 2);
        item.y = window.y + Math.round((window.height - item.height) / 2);
    }

    Component {
        id: folderWindowComponent
        Loader {
            id: folderWindowLoader
            property url location
            source: "window/frame.qml"
            onLoaded: {
                window.configureFilesWindow(item);
                item.objectName = "desktopFolderWindow";
                item.activeChanged.connect(() => {
                    if (item.active) window.activeFilesWindow = item;
                });
                if (item.controller) {
                    item.controller.directory.open(location);
                }
                item.closing.connect(() => {
                    if (window.activeFilesWindow === item) window.activeFilesWindow = null;
                    window.folderWindows = window.folderWindows.filter(loader => loader !== folderWindowLoader);
                    Qt.callLater(() => folderWindowLoader.destroy());
                });
                window.placeQuickWindow(item);
                item.show();
                window.placeMappedWindow(item);
                item.raise();
                item.requestActivate();
            }
        }
    }

    property var activeFilesWindow: null
    property int desktopFocusGeneration: 0
    Connections {
        target: filesWindowLoader.item
        function onActiveChanged() {
            if (filesWindowLoader.item.active) window.activeFilesWindow = filesWindowLoader.item;
        }
    }

    function keepFileWindowActive() {
        if (activeFilesWindow && activeFilesWindow.visible && activeFilesWindow.visibility !== Window.Minimized) {
            activeFilesWindow.raise();
            activeFilesWindow.requestActivate();
        }
    }

    function retainFileWindow() {
        const generation = ++desktopFocusGeneration;
        const retainedWindow = activeFilesWindow;
        Qt.callLater(() => {
            if (generation === desktopFocusGeneration && retainedWindow === activeFilesWindow
                    && !applicationController.renamingDesktopId.length && !applicationController.isRenamingFile()) {
                keepFileWindowActive();
            }
        });
    }

    property var folderWindows: []

    function openFolderWindow(location, skipExisting = false) {
        if (skipExisting) {
            const existing = [filesWindowLoader].concat(folderWindows).find(loader => loader.item
                && loader.item.visible && loader.item.controller && loader.item.controller.directory
                && String(loader.item.controller.directory.location) === String(location));
            if (existing) return existing;
        }
        ++desktopFocusGeneration;
        const loader = folderWindowComponent.createObject(window, {location: location});
        folderWindows = folderWindows.concat([loader]);
        return loader;
    }

    function fileDropWindowAt(point) {
        const candidates = [filesWindowLoader].concat(folderWindows);
        for (const loader of candidates) {
            const item = loader && loader.item;
            if (item && item.visible && point.x >= item.x && point.x <= item.x + item.width
                    && point.y >= item.y && point.y <= item.y + item.height) {
                return item;
            }
        }
        return null;
    }

    function openNetworkSettings(page) {
        if (page && networkWindowLoader.item.contentItem) {
            networkWindowLoader.item.contentItem.open(page);
        }

        applicationController.closePanel();
        networkWindowLoader.item.showNormal();
        networkWindowLoader.item.raise();
        networkWindowLoader.item.requestActivate();
    }

    Loader {
        id: networkWindowLoader
        source: "window/frame.qml"
        onLoaded: {
            item.objectName = "networkSettingsWindow";
            item.title = Qt.binding(() => qsTranslate("Pedro", "settings.network.title"));
            item.contentSource = Qt.resolvedUrl("network/view.qml");
            item.surfaceColor = "#dd15191f";
            item.windowRadius = 22;
            item.contentMargin = 0;
            item.width = Math.min(840, Screen.desktopAvailableWidth * 0.9);
            item.height = Math.min(660, Screen.desktopAvailableHeight * 0.85);
            item.minimumWidth = Math.min(650, item.width);
            item.minimumHeight = Math.min(440, item.height);
            item.x = window.x + (window.width - item.width) / 2;
            item.y = window.y + (window.height - item.height) / 2;
        }
    }
}
