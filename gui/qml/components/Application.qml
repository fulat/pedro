import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Window

import "../controllers" as Controllers
import "../scripts/constants.js" as Constants
import "../scripts/theme.js" as Theme

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

    flags: Qt.Window | Qt.WindowStaysOnBottomHint | (Backend.developmentMode ? 0 : Qt.FramelessWindowHint)
    title: qsTranslate("Pedro", "shell.productName")
    // Cover the screen without fullscreen focus/occlusion semantics.
    visibility: Window.Windowed
    color: Theme.desktopBackground
    visible: true
    width: Backend.developmentMode ? developmentWidth : Screen.width
    height: Backend.developmentMode ? developmentHeight : Screen.height
    minimumWidth: Backend.developmentMode ? Constants.MINIMUM_WIDTH : 0
    minimumHeight: Backend.developmentMode ? Constants.MINIMUM_HEIGHT : 0

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

    property var previewWindows: []

    Component {
        id: previewWindowComponent
        Loader {
            id: sessionLoader
            property var session
            property var openingPosition: null
            source: "preview/window.qml"
            onLoaded: {
                item.preview = session;
                item.openingPosition = openingPosition;
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
            const previous = window.previewWindows.length ? window.previewWindows[window.previewWindows.length - 1] : null;
            const previousWindow = previous && previous.item ? previous.item.item : null;
            const openingPosition = previousWindow ? Qt.point(previousWindow.x - 24, previousWindow.y + 24) : null;
            const loader = previewWindowComponent.createObject(window, {session: session, openingPosition: openingPosition});
            window.previewWindows = window.previewWindows.concat([loader]);
        }
    }

    Shortcut {
        sequence: "Space"
        enabled: window.active && window.selectedDesktopIds.length === 1
            && !(window.activeFocusItem && window.activeFocusItem.readOnly === false)
        onActivated: {
            const entry = window.controller.contextEntries({id: window.selectedDesktopIds[0]})[0];
            if (entry && !entry.isDirectory) window.controller.previewEntry(entry);
        }
    }

    function captureWindows() {
        return [filesWindowLoader, networkWindowLoader].concat(folderWindows, previewWindows.map(loader => loader.item))
            .map(loader => loader ? loader.item : null)
            .filter(item => item && item.visible && item.visibility !== Window.Minimized);
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
                item.show();
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
                    && !applicationController.renamingDesktopId.length) {
                keepFileWindowActive();
            }
        });
    }

    property var folderWindows: []

    function openFolderWindow(location) {
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
