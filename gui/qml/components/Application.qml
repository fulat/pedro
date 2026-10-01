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

    readonly property bool filesQuickWindowVisible: filesQuickWindow.visible
    readonly property real designAspectRatio: Constants.DESIGN_ASPECT_RATIO
    readonly property real developmentWidth: Screen.desktopAvailableWidth > 0 ? Math.min(1600, Screen.desktopAvailableWidth * 0.82) : 1280
    readonly property real developmentHeight: Screen.desktopAvailableHeight > 0 ? Math.min(developmentWidth / designAspectRatio, Screen.desktopAvailableHeight * 0.82) : developmentWidth / designAspectRatio
    readonly property real dockIconSize: applicationController.dockIconSize
    readonly property real dockTileSize: applicationController.dockTileSize
    readonly property real dockSpacing: applicationController.dockSpacing

    title: qsTr(Constants.WINDOW_TITLE)
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
        filesQuickWindow: filesQuickWindow
    }

    // Provides the secondary files surface managed by the controller.
    Window {
        id: filesQuickWindow

        title: "Archivos · Ventana rápida"
        color: "transparent"
        width: window.width
        height: window.height
        x: window.x + Math.round((window.width - width) / 2)
        y: window.y + Math.round((window.height - height) / 2)
        visible: false
        transientParent: window
        flags: Qt.Window | Qt.FramelessWindowHint

        // Sample the backend wallpaper locally: textures cannot cross windows.
        Image {
            id: filesBackdrop

            anchors.fill: parent
            source: Backend.wallpaper
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            visible: false
        }

        Root {
            anchors.centerIn: parent
            width: Math.min(760, filesQuickWindow.width - 32)
            height: Math.min(520, filesQuickWindow.height - 32)
            availableWidth: filesQuickWindow.width
            availableHeight: filesQuickWindow.height
            backdrop: filesBackdrop
            mode: "files"

            onCloseRequested: filesQuickWindow.close()
        }
    }
}
