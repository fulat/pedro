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
    property alias folderContextMenu: applicationController.folderContextMenu
    property alias sideBar: applicationController.sideBar
    property alias topBar: applicationController.topBar
    property alias desktopObstacles: applicationController.desktopObstacles

    readonly property bool filesQuickWindowVisible: filesWindowLoader.item ? filesWindowLoader.item.visible : false
    readonly property real designAspectRatio: Constants.DESIGN_ASPECT_RATIO
    readonly property real developmentWidth: Screen.desktopAvailableWidth > 0 ? Math.min(1600, Screen.desktopAvailableWidth * 0.82) : 1280
    readonly property real developmentHeight: Screen.desktopAvailableHeight > 0 ? Math.min(developmentWidth / designAspectRatio, Screen.desktopAvailableHeight * 0.82) : developmentWidth / designAspectRatio
    readonly property real dockIconSize: applicationController.dockIconSize
    readonly property real dockTileSize: applicationController.dockTileSize
    readonly property real dockSpacing: applicationController.dockSpacing

    title: qsTranslate("Pedro", "shell.productName")
    visibility: Backend.developmentMode ? Window.Windowed : Window.FullScreen
    color: Theme.desktopBackground
    visible: true
    width: Backend.developmentMode ? developmentWidth : Constants.DEVELOPMENT_WIDTH
    height: Backend.developmentMode ? developmentHeight : Constants.DEVELOPMENT_HEIGHT
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

        onLoaded: {
            item.objectName = "filesQuickWindow";
            item.title = Qt.binding(() => qsTranslate("Pedro", "app.files.name"));
            item.contentSource = Qt.resolvedUrl("files/browser.qml");
            item.surfaceColor = Qt.binding(() => Backend.appearanceMode === "light" ? "#f1f4f8" : "#202630");
            item.titleColor = Qt.binding(() => Backend.appearanceMode === "light" ? "#202b3c" : "#edf2f8");
            item.transientParent = null;
            item.width = Math.min(1120, window.width * 0.90);
            item.height = Math.min(720, window.height * 0.90);
            item.minimumWidth = Math.min(420, item.width);
            item.minimumHeight = Math.min(320, item.height);
            item.x = window.x + Math.round((window.width - item.width) / 2);
            item.y = window.y + Math.round((window.height - item.height) / 2);
        }
    }
}
