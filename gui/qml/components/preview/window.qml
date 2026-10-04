import QtQuick
import QtQuick.Window

Loader {
    id: loader
    source: "../window/frame.qml"
    property var preview: Backend.preview
    property bool closingSession: false
    property var openingPosition: null
    signal finished()
    property bool pendingOpen: false
    property string sizedSource: ""

    function fitVisual() {
        const preview = loader.preview;
        if (!item || (preview.kind !== "image" && preview.kind !== "video") || preview.busy || preview.error.length
                || preview.frameSize.width <= 0 || preview.frameSize.height <= 0
                || sizedSource === preview.source.toString() || item.maximized) {
            return;
        }

        const screenWidth = item.Screen.desktopAvailableWidth;
        const screenHeight = item.Screen.desktopAvailableHeight;
        const maximumWidth = Math.min(900, screenWidth * 0.8);
        const maximumHeight = Math.min(720, screenHeight * 0.8);
        const minimumWidth = Math.min(preview.kind === "video" ? 360 : 480, maximumWidth);
        const minimumHeight = Math.min(180, maximumHeight);
        const horizontalInset = item.contentMargin * 2;
        const verticalInset = item.headerHeight + item.contentTopGap + item.contentMargin;
        const imageWidth = preview.frameSize.width;
        const imageHeight = preview.frameSize.height;
        const preferredScale = Math.max(1, (minimumWidth - horizontalInset) / imageWidth,
                (minimumHeight - verticalInset) / imageHeight);
        const scale = Math.min(preferredScale, (maximumWidth - horizontalInset) / imageWidth,
                (maximumHeight - verticalInset) / imageHeight);
        const centerX = item.x + item.width / 2;
        const centerY = item.y + item.height / 2;

        const fittedWidth = Math.round(imageWidth * scale + horizontalInset);
        const fittedHeight = Math.round(imageHeight * scale + verticalInset);
        // Video proportions take precedence over generic window minimums.
        item.minimumWidth = preview.kind === "video" ? Math.min(180, fittedWidth) : minimumWidth;
        item.minimumHeight = preview.kind === "video" ? Math.min(120, fittedHeight) : minimumHeight;
        item.width = preview.kind === "video" ? fittedWidth : Math.max(minimumWidth, fittedWidth);
        item.height = preview.kind === "video" ? fittedHeight : Math.max(minimumHeight, fittedHeight);
        item.x = Math.round(Math.max(item.Screen.virtualX, Math.min(centerX - item.width / 2,
                item.Screen.virtualX + screenWidth - item.width)));
        item.y = Math.round(Math.max(item.Screen.virtualY, Math.min(centerY - item.height / 2,
                item.Screen.virtualY + screenHeight - item.height)));
        placeWindow();
        sizedSource = preview.source.toString();
    }

    function activateViewer() {
        if (!item) return;
        if (item.visibility === Window.Minimized) item.showNormal();
        else if (!item.visible) item.show();
        item.raise();
        item.requestActivate();
    }

    function placeWindow() {
        if (!item || !openingPosition) return;
        item.x = Math.round(Math.max(item.Screen.virtualX, Math.min(openingPosition.x,
                item.Screen.virtualX + item.Screen.desktopAvailableWidth - item.width)));
        item.y = Math.round(Math.max(item.Screen.virtualY, Math.min(openingPosition.y,
                item.Screen.virtualY + item.Screen.desktopAvailableHeight - item.height)));
        openingPosition = null;
    }

    function open() {
        closingSession = false;
        sizedSource = "";
        if (item && item.contentItem) {
            item.contentItem.resetImage();
        }
        pendingOpen = true;
        showWindow();
    }

    function showWindow() {
        if (!item || !item.contentItem || !pendingOpen) {
            return;
        }
        if (!preview.active || preview.busy || !preview.kind.length) {
            return;
        }
        const visual = preview.kind === "image" || preview.kind === "video";
        if (visual && !preview.error.length && (preview.frameSize.width <= 0 || preview.frameSize.height <= 0)) {
            return;
        }
        // Set the final geometry before creating the visible native surface.
        fitVisual();
        pendingOpen = false;
        if (item.visibility === Window.Minimized || item.visibility === Window.Maximized
                || item.visibility === Window.FullScreen) {
            item.showNormal();
        } else {
            item.show();
        }
        item.raise();
        item.requestActivate();
    }

    onLoaded: {
        item.objectName = "previewWindow";
        item.contentSource = Qt.resolvedUrl("view.qml");
        item.title = Qt.binding(() => loader.preview.name);
        item.titleVisible = Qt.binding(() => loader.preview.kind !== "image" && loader.preview.kind !== "video");
        item.headerSource = Qt.binding(() => loader.preview.kind === "image" ? Qt.resolvedUrl("header.qml") : loader.preview.kind === "video" ? Qt.resolvedUrl("bar.qml") : "");
        item.headerHeight = Qt.binding(() => (loader.preview.kind === "image" || loader.preview.kind === "video") ? 34 : 44);
        item.headerOffset = Qt.binding(() => (loader.preview.kind === "image" || loader.preview.kind === "video") ? 86 : 240);
        item.contentMargin = Qt.binding(() => (loader.preview.kind === "image" || loader.preview.kind === "video") ? 8 : 12);
        item.contentTopGap = Qt.binding(() => (loader.preview.kind === "image" || loader.preview.kind === "video") ? 0 : 6);
        item.titleColor = Qt.binding(() => Backend.appearanceMode === "light" ? "#10164d" : "#eef3ff");
        item.width = Math.min((loader.preview.kind === "image" || loader.preview.kind === "video") ? 1100 : 900, Screen.desktopAvailableWidth * 0.9);
        item.height = Math.min((loader.preview.kind === "image" || loader.preview.kind === "video") ? 790 : 640, Screen.desktopAvailableHeight * 0.9);
        item.minimumWidth = 480;
        item.minimumHeight = 340;
        item.windowRadius = 22;
        item.contentItemChanged.connect(() => {
            if (item.contentItem) item.contentItem.preview = Qt.binding(() => loader.preview);
            showWindow();
        });
        if (item.contentItem) item.contentItem.preview = Qt.binding(() => loader.preview);
        item.closing.connect(() => {
            if (loader.closingSession) return;
            loader.closingSession = true;
            loader.preview.close();
            loader.finished();
        });
        showWindow();
    }

    Connections {
        target: loader.preview
        function onChanged() {
            if (loader.pendingOpen) {
                Qt.callLater(loader.showWindow);
            } else {
                loader.fitVisual();
            }
            if (loader.preview.active && loader.preview.kind.length && !loader.preview.busy && loader.preview.kind !== "video" && loader.preview.kind !== "image") loader.placeWindow();
            if (!loader.preview.active) {
                loader.sizedSource = "";
            }
            if (!loader.closingSession && !loader.preview.active && loader.item && loader.item.visible) {
                loader.item.close();
            }
        }
    }
}
