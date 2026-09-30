import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Controls.Basic

import "../logic/theme.js" as Theme
import "../logic/constants.js" as Constants
import "../utils/mocks.js" as Mocks

ApplicationWindow {
    // Window
    id: window
    title: qsTr(Constants.WINDOW_TITLE)
    visibility: Backend.developmentMode ? Window.Windowed : Window.FullScreen
    color: Theme.desktopBackground
    visible: true

    // sizing
    readonly property real designAspectRatio: Constants.DESIGN_ASPECT_RATIO
    readonly property real developmentWidth: Screen.desktopAvailableWidth > 0 ? Math.min(1600, Screen.desktopAvailableWidth * 0.82) : 1280
    readonly property real developmentHeight: Screen.desktopAvailableHeight > 0 ? Math.min(developmentWidth / designAspectRatio, Screen.desktopAvailableHeight * 0.82) : developmentWidth / designAspectRatio

    width: Backend.developmentMode ? developmentWidth : Constants.DEVELOPMENT_WIDTH
    height: Backend.developmentMode ? developmentHeight : Constants.DEVELOPMENT_HEIGHT
    minimumWidth: Backend.developmentMode ? Constants.MINIMUM_WIDTH : 0
    minimumHeight: Backend.developmentMode ? Constants.MINIMUM_HEIGHT : 0

    property string panelMode: Constants.PANEL_MODE
    property string panelSource: Constants.PANEL_SOURCE
    property real panelAnchorX: width - 190
    property date currentTime: new Date()
    property var selectedDesktopIds: []
    property var desktopDragItems: []
    property var desktopDragAnchor: null
    property point desktopDragOrigin: Qt.point(0, 0)
    property bool desktopDragging: false
    readonly property bool filesQuickWindowVisible: filesQuickWindow.visible
    property var desktopShortcuts
    property var desktopShortcutRepeater
    property var desktopContextMenu
    property var sideBar
    property var topBar

    property var pinnedApps: Mocks.pinnedApps
    property var recentApps: Mocks.recentApps

    readonly property real dockIconSize: Math.max(27, Math.min(38, width / 42))
    readonly property real dockTileSize: dockIconSize + 14
    readonly property real dockSpacing: Math.max(5, Math.min(10, width / 160))

    signal applicationRequested(string applicationId)

    function closePanel() {
        panelMode = "";
        panelSource = "";
    }

    function togglePanel(name, anchorX, source) {
        if (panelMode === name && panelSource === source) {
            closePanel();
            return;
        }

        panelAnchorX = anchorX;
        panelSource = source;
        panelMode = name;
    }

    function activateDockApp(app, anchorX) {
        if (app.id === "files") {
            togglePanel("files", anchorX, "dock-files");
            return;
        }

        if (!pinnedApps.some(pinned => pinned.id === app.id)) {
            recentApps = [app].concat(recentApps.filter(recent => recent.id !== app.id)).slice(0, 3);
        }

        applicationRequested(app.id);
    }

    function openFilesQuickWindow() {
        closePanel();
        filesQuickWindow.show();
        filesQuickWindow.raise();
        filesQuickWindow.requestActivate();
    }

    function openDesktopShortcutMenu(shortcut, localX, localY, shortcutName) {
        const position = shortcut.mapToItem(window.contentItem, localX, localY);

        desktopContextMenu.shortcutName = shortcutName || "Escritorio";
        desktopContextMenu.x = Math.max(12, Math.min(window.width - desktopContextMenu.width - 12, position.x));
        desktopContextMenu.y = Math.max(topBar.barHeight + 8, Math.min(window.height - desktopContextMenu.height - 12, position.y));
        desktopContextMenu.open();
    }

    function isDesktopShortcutSelected(shortcutId) {
        return selectedDesktopIds.indexOf(shortcutId) !== -1;
    }

    function selectOnlyDesktopShortcut(shortcutId) {
        selectedDesktopIds = [shortcutId];
    }

    function toggleDesktopShortcut(shortcutId) {
        const selected = selectedDesktopIds.slice();
        const selectedIndex = selected.indexOf(shortcutId);

        if (selectedIndex === -1) {
            selected.push(shortcutId);
        } else {
            selected.splice(selectedIndex, 1);
        }

        selectedDesktopIds = selected;
    }

    function selectDesktopShortcutsInRectangle(rectangle, baseSelection) {
        const selected = baseSelection.slice();

        for (let index = 0; index < desktopShortcutRepeater.count; ++index) {
            const shortcut = desktopShortcutRepeater.itemAt(index);

            if (!shortcut) {
                continue;
            }

            const intersects = shortcut.x < rectangle.x + rectangle.width && shortcut.x + shortcut.width > rectangle.x && shortcut.y < rectangle.y + rectangle.height && shortcut.y + shortcut.height > rectangle.y;
            const selectedIndex = selected.indexOf(shortcut.app.id);

            if (intersects && selectedIndex === -1) {
                selected.push(shortcut.app.id);
            } else if (!intersects && selectedIndex !== -1 && baseSelection.indexOf(shortcut.app.id) === -1) {
                selected.splice(selectedIndex, 1);
            }
        }

        selectedDesktopIds = selected;
    }

    function beginDesktopDrag(shortcut, localX, localY) {
        const position = shortcut.mapToItem(desktopShortcuts, localX, localY);
        const items = [];

        for (let index = 0; index < desktopShortcutRepeater.count; ++index) {
            const candidate = desktopShortcutRepeater.itemAt(index);

            if (candidate && isDesktopShortcutSelected(candidate.app.id)) {
                items.push({
                    item: candidate,
                    x: candidate.x,
                    y: candidate.y
                });
            }
        }

        desktopDragOrigin = Qt.point(position.x, position.y);
        desktopDragItems = items;
        desktopDragAnchor = shortcut;
        desktopDragging = items.length > 0;
        desktopContextMenu.close();
    }

    function updateDesktopDrag(shortcut, localX, localY) {
        if (!desktopDragging || desktopDragItems.length === 0) {
            return;
        }

        const position = shortcut.mapToItem(desktopShortcuts, localX, localY);
        let movementX = position.x - desktopDragOrigin.x;
        let movementY = position.y - desktopDragOrigin.y;
        let minimumX = desktopDragItems[0].x;
        let minimumY = desktopDragItems[0].y;
        let maximumX = desktopDragItems[0].x + desktopDragItems[0].item.width;
        let maximumY = desktopDragItems[0].y + desktopDragItems[0].item.height;

        for (let index = 1; index < desktopDragItems.length; ++index) {
            const entry = desktopDragItems[index];

            minimumX = Math.min(minimumX, entry.x);
            minimumY = Math.min(minimumY, entry.y);
            maximumX = Math.max(maximumX, entry.x + entry.item.width);
            maximumY = Math.max(maximumY, entry.y + entry.item.height);
        }

        movementX = Math.max(-minimumX, Math.min(desktopShortcuts.width - maximumX, movementX));
        movementY = Math.max(-minimumY, Math.min(desktopShortcuts.height - maximumY, movementY));

        for (let index = 0; index < desktopDragItems.length; ++index) {
            const entry = desktopDragItems[index];

            entry.item.x = entry.x + movementX;
            entry.item.y = entry.y + movementY;
        }
    }

    function desktopPlacementOverlapsShell(itemX, itemY, itemWidth, itemHeight) {
        const clearance = 8;
        const sideBarPosition = sideBar.mapToItem(desktopShortcuts, 0, 0);
        const reservedX = sideBarPosition.x - clearance;
        const reservedY = sideBarPosition.y - clearance;
        const reservedWidth = sideBar.width + clearance * 2;
        const reservedHeight = sideBar.height + clearance * 2;

        return itemX < reservedX + reservedWidth && itemX + itemWidth > reservedX && itemY < reservedY + reservedHeight && itemY + itemHeight > reservedY;
    }

    function snapDesktopDragToGrid() {
        if (!desktopDragAnchor || desktopDragItems.length === 0) {
            return;
        }

        const cellWidth = desktopShortcuts.cellWidth;
        const cellHeight = desktopShortcuts.cellHeight;
        const occupied = {};
        const cells = [];
        let anchorCell = null;

        for (let index = 0; index < desktopShortcutRepeater.count; ++index) {
            const shortcut = desktopShortcutRepeater.itemAt(index);

            if (shortcut && !isDesktopShortcutSelected(shortcut.app.id)) {
                const column = Math.round(shortcut.x / cellWidth);
                const row = Math.round(shortcut.y / cellHeight);

                occupied[column + ":" + row] = true;
            }
        }

        for (let index = 0; index < desktopDragItems.length; ++index) {
            const entry = desktopDragItems[index];
            const cell = {
                item: entry.item,
                column: Math.round(entry.x / cellWidth),
                row: Math.round(entry.y / cellHeight)
            };

            cells.push(cell);

            if (entry.item === desktopDragAnchor) {
                anchorCell = cell;
            }
        }

        if (!anchorCell) {
            anchorCell = cells[0];
        }

        const preferredColumn = Math.round(desktopDragAnchor.x / cellWidth);
        const preferredRow = Math.round(desktopDragAnchor.y / cellHeight);
        const horizontalDirection = Math.sign(preferredColumn - anchorCell.column);
        const verticalDirection = Math.sign(preferredRow - anchorCell.row);
        const maximumColumn = Math.max(0, Math.floor((desktopShortcuts.width - desktopDragAnchor.width) / cellWidth));
        const maximumRow = Math.max(0, Math.floor((desktopShortcuts.height - desktopDragAnchor.height) / cellHeight));
        let bestPlacement = null;
        let bestDistance = Number.MAX_VALUE;
        let bestDirectionPenalty = Number.MAX_VALUE;

        for (let row = 0; row <= maximumRow; ++row) {
            for (let column = 0; column <= maximumColumn; ++column) {
                const columnOffset = column - anchorCell.column;
                const rowOffset = row - anchorCell.row;
                const placement = [];
                const placementCells = {};
                let valid = true;

                for (let index = 0; index < cells.length; ++index) {
                    const cell = cells[index];
                    const targetColumn = cell.column + columnOffset;
                    const targetRow = cell.row + rowOffset;
                    const targetX = targetColumn * cellWidth;
                    const targetY = targetRow * cellHeight;
                    const key = targetColumn + ":" + targetRow;

                    if (targetColumn < 0 || targetRow < 0 || targetX + cell.item.width > desktopShortcuts.width || targetY + cell.item.height > desktopShortcuts.height || desktopPlacementOverlapsShell(targetX, targetY, cell.item.width, cell.item.height) || occupied[key] || placementCells[key]) {
                        valid = false;
                        break;
                    }

                    placementCells[key] = true;
                    placement.push({
                        item: cell.item,
                        x: targetX,
                        y: targetY
                    });
                }

                if (!valid) {
                    continue;
                }

                const distance = Math.pow(column - preferredColumn, 2) + Math.pow(row - preferredRow, 2);
                const directionPenalty = (horizontalDirection !== 0 && (column - preferredColumn) * horizontalDirection < 0 ? 1 : 0) + (verticalDirection !== 0 && (row - preferredRow) * verticalDirection < 0 ? 1 : 0);

                if (distance < bestDistance || (distance === bestDistance && directionPenalty < bestDirectionPenalty)) {
                    bestDistance = distance;
                    bestDirectionPenalty = directionPenalty;
                    bestPlacement = placement;
                }
            }
        }

        if (!bestPlacement) {
            bestPlacement = cells.map(cell => ({
                        item: cell.item,
                        x: cell.column * cellWidth,
                        y: cell.row * cellHeight
                    }));
        }

        desktopDragging = false;

        for (let index = 0; index < bestPlacement.length; ++index) {
            const placement = bestPlacement[index];

            placement.item.x = placement.x;
            placement.item.y = placement.y;
        }
    }

    function endDesktopDrag() {
        snapDesktopDragToGrid();
        desktopDragging = false;
        desktopDragAnchor = null;
        desktopDragItems = [];
    }

    // -------------------------------------------
    // Files quick window
    // -------------------------------------------
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
    }
}
