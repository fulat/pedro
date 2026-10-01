import QtQuick

import "../scripts/theme.js" as Theme

// Resolves shell-wide configuration that is independent from visual markup.
QtObject {
    required property var view

    property real selectionOriginX
    property real selectionOriginY
    property var baseSelection: []

    readonly property string dockPosition: requestedDockPosition()
    readonly property bool dockOnLeft: dockPosition.indexOf("left-") === 0 || dockPosition === "top-left" || dockPosition === "bottom-left"
    readonly property bool dockOnRight: dockPosition.indexOf("right-") === 0 || dockPosition === "top-right" || dockPosition === "bottom-right"
    readonly property bool dockOnTop: dockPosition.indexOf("top-") === 0 || dockPosition === "left-top" || dockPosition === "right-top"
    readonly property bool dockOnBottom: dockPosition.indexOf("bottom-") === 0 || dockPosition === "left-bottom" || dockPosition === "right-bottom"
    readonly property bool dockHorizontalCenter: dockPosition === "top-center" || dockPosition === "bottom-center"
    readonly property bool dockVerticalCenter: dockPosition === "left-center" || dockPosition === "right-center"
    readonly property bool dockVertical: dockPosition.indexOf("left-") === 0 || dockPosition.indexOf("right-") === 0

    // Reads and validates the requested dock location from process arguments.
    function requestedDockPosition() {
        const prefix = "--dock-position=";
        const supportedPositions = ["top-left", "top-center", "top-right", "bottom-left", "bottom-center", "bottom-right", "left-top", "left-center", "left-bottom", "right-top", "right-center", "right-bottom"];

        for (const argument of Qt.application.arguments) {
            if (argument.indexOf(prefix) !== 0) {
                continue;
            }

            const requestedPosition = argument.substring(prefix.length);

            if (supportedPositions.indexOf(requestedPosition) !== -1) {
                return requestedPosition;
            }
        }

        return "bottom-center";
    }

    // Starts desktop selection or opens the background context menu.
    function desktopPressed(mouse, desktopArea, selectionRectangle, desktopMenu) {
        if (mouse.button === Qt.RightButton) {
            view.selectedDesktopIds = [];
            view.controller.closePanel();
            view.controller.openDesktopShortcutMenu(desktopArea, mouse.x, mouse.y, qsTranslate("Pedro", "desktop.title"));
            return;
        }

        selectionOriginX = mouse.x;
        selectionOriginY = mouse.y;
        baseSelection = (mouse.modifiers & Qt.ControlModifier) ? view.selectedDesktopIds.slice() : [];
        selectionRectangle.x = selectionOriginX;
        selectionRectangle.y = selectionOriginY;
        selectionRectangle.width = 0;
        selectionRectangle.height = 0;
        selectionRectangle.visible = true;
        view.selectedDesktopIds = baseSelection.slice();
        view.controller.closePanel();
        desktopMenu.close();
    }

    // Updates the visible selection rectangle and selected shortcuts.
    function desktopPositionChanged(mouse, pressedButtons, selectionRectangle) {
        if (!(pressedButtons & Qt.LeftButton)) {
            return;
        }

        selectionRectangle.x = Math.min(selectionOriginX, mouse.x);
        selectionRectangle.y = Math.min(selectionOriginY, mouse.y);
        selectionRectangle.width = Math.abs(mouse.x - selectionOriginX);
        selectionRectangle.height = Math.abs(mouse.y - selectionOriginY);
        view.controller.selectDesktopShortcutsInRectangle(selectionRectangle, baseSelection);
    }

    // Hides the selection rectangle when selection input ends.
    function desktopReleased(mouse, selectionRectangle) {
        if (mouse.button === Qt.LeftButton) {
            selectionRectangle.visible = false;
        }
    }

    // Opens a shortcut-specific context menu.
    function shortcutMenuRequested(shortcut, localX, localY) {
        view.controller.closePanel();
        if (view.desktopContextMenu) view.desktopContextMenu.close();
        shortcut.openMenu(localX, localY);
    }

    // Routes navigation entries to their controller-owned destinations.
    function navigationActivated(entry, sideBar) {
        if (entry.modelData.id === "home") {
            view.controller.closePanel();
            return;
        }

        if (entry.modelData.id === "files") {
            view.controller.openFilesQuickWindow();
            return;
        }

        view.controller.togglePanel(entry.modelData.mode, sideBar.x + sideBar.width / 2, "nav-" + entry.modelData.id);
    }

    // Connects a dynamically loaded panel to shell state and actions.
    function panelLoaded(item, wallpaper, topBar) {
        item.backdrop = wallpaper;
        item.mode = Qt.binding(() => view.panelMode);
        item.availableWidth = Qt.binding(() => view.width);
        item.availableHeight = Qt.binding(() => view.height - topBar.barHeight);
        item.closeRequested.connect(view.controller.closePanel);
        item.modeRequested.connect(mode => view.panelMode = mode);
    }

    // Starts selection or grouped dragging for one desktop shortcut.
    function shortcutPressed(mouse, mouseArea, shortcut) {
        mouseArea.moved = false;
        mouseArea.pressedX = mouse.x;
        mouseArea.pressedY = mouse.y;

        if (mouse.button === Qt.RightButton) {
            if (!shortcut.selected) {
                view.controller.selectOnlyDesktopShortcut(shortcut.app.id);
            }
            return;
        }

        if (mouse.modifiers & Qt.ControlModifier) {
            view.controller.toggleDesktopShortcut(shortcut.app.id);
            return;
        }

        if (!shortcut.selected) {
            view.controller.selectOnlyDesktopShortcut(shortcut.app.id);
        }

        view.controller.beginDesktopDrag(shortcut, mouse.x, mouse.y);
    }

    // Updates a shortcut drag after the pointer crosses the movement threshold.
    function shortcutPositionChanged(mouse, pressedButtons, mouseArea, shortcut) {
        if (!(pressedButtons & Qt.LeftButton) || (mouse.modifiers & Qt.ControlModifier)) {
            return;
        }

        if (Math.abs(mouse.x - mouseArea.pressedX) > 3 || Math.abs(mouse.y - mouseArea.pressedY) > 3) {
            mouseArea.moved = true;
        }

        if (mouseArea.moved) {
            view.controller.updateDesktopDrag(shortcut, mouse.x, mouse.y);
        }
    }

    // Finishes a shortcut drag on primary-button release.
    function shortcutReleased(mouse) {
        if (mouse.button === Qt.LeftButton) {
            view.controller.endDesktopDrag();
        }
    }

    // Handles shortcut selection and context-menu clicks.
    function shortcutClicked(mouse, moved, shortcut) {
        if (mouse.button === Qt.RightButton) {
            shortcut.menuRequested(mouse.x, mouse.y);
        } else if (!moved && Backend.desktopModel.organization === "stack" && shortcut.stack.leader && shortcut.stack.count > 1) {
            view.controller.toggleStack(shortcut.app);
        } else if (!moved && !(mouse.modifiers & Qt.ControlModifier)) {
            view.controller.selectOnlyDesktopShortcut(shortcut.app.id);
        }
    }

    // Treats a primary-button double-click as the shortcut's default request.
    function shortcutDoubleClicked(mouse, moved, shortcut) {
        if (mouse.button === Qt.LeftButton && !moved) {
            shortcut.menuRequested(mouse.x, mouse.y);
        }
    }

    // Paints the small navigation glyph selected by the view.
    function paintNavigationGlyph(glyph) {
        const context = glyph.getContext("2d");

        context.clearRect(0, 0, glyph.width, glyph.height);
        context.save();
        context.scale(glyph.width / 24, glyph.height / 24);
        context.strokeStyle = Theme.white;
        context.fillStyle = Theme.white;
        context.lineWidth = 1.8;
        context.lineCap = "round";
        context.lineJoin = "round";
        context.beginPath();

        if (glyph.kind === "home") {
            context.moveTo(3, 11);
            context.lineTo(12, 4);
            context.lineTo(21, 11);
            context.moveTo(6, 10);
            context.lineTo(6, 20);
            context.lineTo(10, 20);
            context.lineTo(10, 15);
            context.lineTo(14, 15);
            context.lineTo(14, 20);
            context.lineTo(18, 20);
            context.lineTo(18, 10);
        } else if (glyph.kind === "folder") {
            context.moveTo(3, 7);
            context.lineTo(9, 7);
            context.lineTo(11, 9);
            context.lineTo(21, 9);
            context.lineTo(21, 19);
            context.lineTo(3, 19);
            context.closePath();
        } else if (glyph.kind === "apps") {
            for (let x = 6; x <= 18; x += 12) {
                for (let y = 6; y <= 18; y += 12) {
                    context.moveTo(x + 2, y);
                    context.arc(x, y, 2, 0, Math.PI * 2);
                }
            }
        } else if (glyph.kind === "chat") {
            context.moveTo(5, 5);
            context.lineTo(19, 5);
            context.quadraticCurveTo(21, 5, 21, 7);
            context.lineTo(21, 16);
            context.quadraticCurveTo(21, 18, 19, 18);
            context.lineTo(10, 18);
            context.lineTo(5, 21);
            context.lineTo(5, 18);
            context.quadraticCurveTo(3, 18, 3, 16);
            context.lineTo(3, 7);
            context.quadraticCurveTo(3, 5, 5, 5);
        } else if (glyph.kind === "notes") {
            context.moveTo(5, 3);
            context.lineTo(15, 3);
            context.lineTo(20, 8);
            context.lineTo(20, 21);
            context.lineTo(5, 21);
            context.closePath();
            context.moveTo(15, 3);
            context.lineTo(15, 8);
            context.lineTo(20, 8);
            context.moveTo(8, 12);
            context.lineTo(17, 12);
            context.moveTo(8, 16);
            context.lineTo(17, 16);
        }

        context.stroke();
        context.restore();
    }
}
