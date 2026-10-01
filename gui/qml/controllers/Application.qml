import QtQuick
import QtQuick.Window
import gui
import "../scripts/constants.js" as Constants

// Owns the graphical shell state and every operation triggered by its views.
QtObject {
    id: controller

    required property var window
    required property var filesQuickWindow

    property string panelMode: Constants.PANEL_MODE
    property string panelSource: Constants.PANEL_SOURCE
    property real panelAnchorX: window.width - 190
    property date currentTime: new Date()
    property var selectedDesktopIds: []
    property string renamingDesktopId: ""
    property bool renamingDesktopBusy: false
    property string desktopOperationError: ""
    property var expandedDesktopStacks: []
    property var desktopDragItems: []
    property var desktopDragAnchor: null
    property point desktopDragOrigin: Qt.point(0, 0)
    property bool desktopDragging: false
    property bool stackDragPending: false
    property bool stackDragActive: false
    property var stackDragEntry: null
    property var stackDragSource: null
    property point stackDragPoint: Qt.point(0, 0)
    property string stackDropTargetId: ""
    property var desktopShortcuts
    property var desktopShortcutRepeater
    property var desktopContextMenu
    property var folderContextMenu
    property var sideBar
    property var topBar
    property var desktopObstacles: []

    readonly property var installedApps: Papi.installedApplications
    readonly property var pinnedApps: Papi.pinnedApplications

    // Logical pixels keep shell controls consistent across screen sizes and DPI.
    readonly property real dockIconSize: 26
    readonly property real dockTileSize: 34
    readonly property real dockSpacing: 4

    // Closes the active shell panel.
    function closePanel() {
        panelMode = "";
        panelSource = "";
    }

    // Opens a panel or closes it when its current trigger is pressed again.
    function togglePanel(name, anchorX, source) {
        if (panelMode === name && panelSource === source) {
            closePanel();
            return;
        }

        panelAnchorX = anchorX;
        panelSource = source;
        panelMode = name;
    }

    // Presents the standalone files window above the shell.
    function openFilesQuickWindow() {
        closePanel();
        if (filesQuickWindow.visibility === Window.Minimized) {
            filesQuickWindow.showNormal();
        } else {
            filesQuickWindow.show();
        }
        filesQuickWindow.raise();
        filesQuickWindow.requestActivate();
    }

    // Opens the desktop context menu at a position constrained to the window.
    function openDesktopShortcutMenu(shortcut, localX, localY, shortcutName) {
        const position = shortcut.mapToItem(window.contentItem, localX, localY);

        if (folderContextMenu) {
            folderContextMenu.close();
        }

        if (shortcut.app && folderContextMenu) {
            desktopContextMenu.close();
            folderContextMenu.folderName = shortcutName;
            folderContextMenu.fileMode = !shortcut.app.isDirectory;
            folderContextMenu.imageFile = shortcut.app.icon === "image";
            folderContextMenu.popup(Math.max(12, Math.min(window.width - folderContextMenu.width - 12, position.x)),
                                    Math.max(12, Math.min(window.height - folderContextMenu.height - 12, position.y)));
            return;
        }

        desktopContextMenu.shortcutName = shortcutName || qsTranslate("Pedro", "desktop.title");
        const menuX = Math.max(12, Math.min(window.width - desktopContextMenu.width - 12, position.x));
        const menuY = Math.max(12, Math.min(window.height - desktopContextMenu.height - 12, position.y));
        desktopContextMenu.popup(menuX, menuY);
    }

    function wallpaperAction(action) {
        desktopOperationError = "";
        if (action === "folder") {
            Backend.desktopModel.createFolder(qsTranslate("Pedro", "desktop.menu.folder"));
        } else if (action === "file") {
            Backend.desktopModel.createFile(qsTranslate("Pedro", "desktop.menu.file"));
        } else if (action === "grid" || action === "free" || action === "stack") {
            if (Backend.desktopModel.organization !== "stack") {
                for (let index = 0; index < desktopShortcutRepeater.count; ++index) {
                    const item = desktopShortcutRepeater.itemAt(index);
                    if (item) {
                        Backend.desktopModel.savePosition(item.app.id, item.x, item.y);
                    }
                }
            }
            expandedDesktopStacks = [];
            Backend.desktopModel.setOrganization(action);
        } else if (action === "align") {
            Backend.desktopModel.setKeepAligned(!Backend.desktopModel.keepAligned);
        }
    }

    function stackInfo(entry) {
        if (!entry) {
            return {key: "file", count: 1, leader: true, visible: true, expanded: false, slot: 0};
        }
        const groups = Backend.desktopModel.groups;
        let slot = 0;
        for (const group of groups) {
            const expanded = expandedDesktopStacks.indexOf(group.key) !== -1;
            const member = group.members.indexOf(entry.id);
            if (member !== -1) {
                return {key: group.key, count: group.members.length, leader: member === 0,
                    visible: member === 0 || expanded, expanded: expanded, slot: slot + (expanded ? member : 0)};
            }
            slot += expanded ? group.members.length : 1;
        }
        return {key: "file", count: 1, leader: true, visible: true, expanded: false, slot: slot};
    }

    function toggleStack(entry) {
        const info = stackInfo(entry);
        const expanded = expandedDesktopStacks.slice();
        const index = expanded.indexOf(info.key);
        if (index === -1) {
            expanded.push(info.key);
        } else {
            expanded.splice(index, 1);
        }
        expandedDesktopStacks = expanded;
        arrangeDesktop();
    }

    function stackLabel(key) {
        const labels = {folder: qsTranslate("Pedro", "desktop.stack.folder"), image: qsTranslate("Pedro", "desktop.stack.image"), text: qsTranslate("Pedro", "shell.navigation.documents"), audio: qsTranslate("Pedro", "desktop.stack.audio"), video: qsTranslate("Pedro", "desktop.stack.video"), file: qsTranslate("Pedro", "desktop.stack.file")};
        return labels[key] || labels.file;
    }

    function startDesktopRename(id) {
        renamingDesktopBusy = false;
        renamingDesktopId = id;
        selectOnlyDesktopShortcut(id);
        for (const group of Backend.desktopModel.groups) {
            if (group.members.indexOf(id) !== -1 && expandedDesktopStacks.indexOf(group.key) === -1) {
                expandedDesktopStacks = expandedDesktopStacks.concat([group.key]);
            }
        }
        if (Backend.desktopModel.organization === "stack") {
            arrangeDesktop();
        }
    }

    function commitDesktopRename(entry, name) {
        if (renamingDesktopBusy || renamingDesktopId !== entry.id) {
            return;
        }
        if (name === entry.name) {
            renamingDesktopId = "";
            return;
        }
        renamingDesktopBusy = true;
        Backend.desktopModel.renameEntry(entry.id, name);
    }

    function arrangeDesktop() {
        if (desktopDragging) {
            endDesktopDrag();
        }
        const mode = Backend.desktopModel.organization;
        for (let index = 0; index < desktopShortcutRepeater.count; ++index) {
            const item = desktopShortcutRepeater.itemAt(index);
            if (!item) {
                continue;
            }
            const position = mode === "stack" ? desktopStackPosition(stackInfo(item.app).slot)
                : desktopRestoredPosition(item.app, index);
            item.x = position.x;
            item.y = position.y;
        }
    }

    // Restores persisted positions, constraining them to the current screen.
    function desktopRestoredPosition(entry, index) {
        if (Backend.desktopModel.organization === "stack") {
            return desktopStackPosition(stackInfo(entry).slot);
        }
        if (entry.position) {
            const x = Math.max(0, Math.min(entry.position.x, desktopShortcuts.width - desktopShortcuts.cellWidth));
            const y = Math.max(0, Math.min(entry.position.y, desktopShortcuts.height - desktopShortcuts.cellHeight));

            if (!desktopPlacementOverlapsShell(x, y, desktopShortcuts.cellWidth, desktopShortcuts.cellHeight)) {
                return Qt.point(x, y);
            }
        }

        return desktopInitialPosition(index);
    }

    // Fill stack columns from the right edge, scanning each from top to bottom.
    function desktopStackPosition(index) {
        let slot = 0;
        const columns = Math.max(1, Math.floor(desktopShortcuts.width / desktopShortcuts.cellWidth));
        const rows = Math.max(1, Math.floor(desktopShortcuts.height / desktopShortcuts.cellHeight));

        for (let column = 0; column < columns; ++column) {
            const x = Math.max(0, desktopShortcuts.width - desktopShortcuts.cellWidth * (column + 1));

            for (let row = 0; row < rows; ++row) {
                const y = row * desktopShortcuts.cellHeight;

                if (!desktopPlacementOverlapsShell(x, y, desktopShortcuts.cellWidth, desktopShortcuts.cellHeight)) {
                    if (slot++ === index) {
                        return Qt.point(x, y);
                    }
                }
            }
        }

        return Qt.point(0, rows * desktopShortcuts.cellHeight);
    }

    // Places initial model entries in free desktop cells without filesystem logic.
    function desktopInitialPosition(index, ignoreSaved = false) {
        let slot = 0;
        const columns = Math.max(1, Math.floor(desktopShortcuts.width / desktopShortcuts.cellWidth));
        const rows = Math.max(1, Math.floor(desktopShortcuts.height / desktopShortcuts.cellHeight));

        for (let row = 0; row < rows; ++row) {
            for (let column = 0; column < columns; ++column) {
                const x = column * desktopShortcuts.cellWidth;
                const y = row * desktopShortcuts.cellHeight;

                let reserved = false;

                for (let itemIndex = 0; itemIndex < desktopShortcutRepeater.count; ++itemIndex) {
                    const item = desktopShortcutRepeater.itemAt(itemIndex);
                    const saved = item && item.app ? item.app.position : null;

                    if (!ignoreSaved && saved && x < saved.x + desktopShortcuts.cellWidth && x + desktopShortcuts.cellWidth > saved.x
                            && y < saved.y + desktopShortcuts.cellHeight && y + desktopShortcuts.cellHeight > saved.y) {
                        reserved = true;
                        break;
                    }
                }

                if (!reserved && !desktopPlacementOverlapsShell(x, y, desktopShortcuts.cellWidth, desktopShortcuts.cellHeight)) {
                    if (slot++ === index) {
                        return Qt.point(x, y);
                    }
                }
            }
        }

        return Qt.point((index % columns) * desktopShortcuts.cellWidth, rows * desktopShortcuts.cellHeight);
    }

    // Reports whether a desktop shortcut belongs to the current selection.
    function isDesktopShortcutSelected(shortcutId) {
        return selectedDesktopIds.indexOf(shortcutId) !== -1;
    }

    // Replaces the desktop selection with one shortcut.
    function selectOnlyDesktopShortcut(shortcutId) {
        selectedDesktopIds = [shortcutId];
    }

    // Adds or removes one shortcut from the desktop selection.
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

    // Selects every shortcut intersecting the current drag rectangle.
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

    // Captures the selected shortcuts before a grouped desktop drag.
    function beginDesktopDrag(shortcut, localX, localY) {
        if (renamingDesktopId.length > 0) {
            return;
        }
        const position = shortcut.mapToItem(desktopShortcuts, localX, localY);
        if (Backend.desktopModel.organization === "stack") {
            stackDragPending = true;
            stackDragActive = false;
            stackDragEntry = shortcut.app;
            stackDragSource = shortcut;
            stackDragPoint = position;
            stackDropTargetId = "";
            desktopContextMenu.close();
            if (folderContextMenu) {
                folderContextMenu.close();
            }
            return;
        }
        const items = [];

        for (let index = 0; index < desktopShortcutRepeater.count; ++index) {
            const candidate = desktopShortcutRepeater.itemAt(index);

            if (candidate && candidate.visible && isDesktopShortcutSelected(candidate.app.id)) {
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
        if (folderContextMenu) {
            folderContextMenu.close();
        }
    }

    // Moves the selected shortcuts while keeping them inside the desktop area.
    function updateDesktopDrag(shortcut, localX, localY) {
        if (stackDragPending) {
            stackDragActive = true;
            stackDragPoint = shortcut.mapToItem(desktopShortcuts, localX, localY);
            stackDropTargetId = "";
            for (let index = 0; index < desktopShortcutRepeater.count; ++index) {
                const candidate = desktopShortcutRepeater.itemAt(index);
                if (!candidate || !candidate.visible || candidate === stackDragSource || !candidate.app.isDirectory
                        || (candidate.stack.leader && candidate.stack.count > 1 && !candidate.stack.expanded)) {
                    continue;
                }
                if (stackDragPoint.x >= candidate.x && stackDragPoint.x <= candidate.x + candidate.width
                        && stackDragPoint.y >= candidate.y && stackDragPoint.y <= candidate.y + candidate.height) {
                    stackDropTargetId = candidate.app.id;
                    break;
                }
            }
            return;
        }
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

    // Reports whether a proposed shortcut position overlaps fixed shell chrome.
    function desktopPlacementOverlapsShell(itemX, itemY, itemWidth, itemHeight) {
        const clearance = 8;

        for (const obstacle of desktopObstacles) {
            if (!obstacle || !obstacle.visible || obstacle.width <= 0 || obstacle.height <= 0) {
                continue;
            }

            const position = obstacle.mapToItem(desktopShortcuts, 0, 0);

            if (itemX < position.x + obstacle.width + clearance && itemX + itemWidth > position.x - clearance
                    && itemY < position.y + obstacle.height + clearance && itemY + itemHeight > position.y - clearance) {
                return true;
            }
        }

        return false;
    }

    // Snaps a grouped drag to the nearest free set of desktop grid cells.
    function snapDesktopDragToGrid() {
        if (!desktopDragAnchor || desktopDragItems.length === 0) {
            return;
        }

        const maximumColumn = Math.max(0, Math.floor((desktopShortcuts.width - desktopDragAnchor.width) / desktopShortcuts.cellWidth));
        const maximumRow = Math.max(0, Math.floor((desktopShortcuts.height - desktopDragAnchor.height) / desktopShortcuts.cellHeight));
        // Distribute leftover space so the first and last cells touch both edges.
        const cellWidth = maximumColumn > 0 ? (desktopShortcuts.width - desktopDragAnchor.width) / maximumColumn : desktopShortcuts.cellWidth;
        const cellHeight = maximumRow > 0 ? (desktopShortcuts.height - desktopDragAnchor.height) / maximumRow : desktopShortcuts.cellHeight;
        const occupied = [];
        const cells = [];
        let anchorCell = null;

        for (let index = 0; index < desktopShortcutRepeater.count; ++index) {
            const shortcut = desktopShortcutRepeater.itemAt(index);

            if (shortcut && !isDesktopShortcutSelected(shortcut.app.id)) {
                occupied.push(shortcut);
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

                    const overlapsShortcut = occupied.some(shortcut => targetX < shortcut.x + shortcut.width
                            && targetX + cell.item.width > shortcut.x && targetY < shortcut.y + shortcut.height
                            && targetY + cell.item.height > shortcut.y);

                    if (targetColumn < 0 || targetRow < 0 || targetX + cell.item.width > desktopShortcuts.width || targetY + cell.item.height > desktopShortcuts.height || desktopPlacementOverlapsShell(targetX, targetY, cell.item.width, cell.item.height) || overlapsShortcut || placementCells[key]) {
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
            bestPlacement = desktopDragItems.map(entry => ({
                        item: entry.item,
                        x: entry.x,
                        y: entry.y
                    }));
        }

        desktopDragging = false;

        for (let index = 0; index < bestPlacement.length; ++index) {
            const placement = bestPlacement[index];

            placement.item.x = placement.x;
            placement.item.y = placement.y;
            Backend.desktopModel.savePosition(placement.item.app.id, placement.x, placement.y);
        }
    }

    // Completes a desktop drag and clears its transient state.
    function endDesktopDrag() {
        if (stackDragPending) {
            stackDragActive = false;
            if (stackDragSource) {
                stackDragPoint = Qt.point(stackDragSource.x + stackDragSource.width / 2, stackDragSource.y + 28);
            }
            stackDragPending = false;
            stackDropTargetId = "";
            stackDragSource = null;
            return;
        }
        if (Backend.desktopModel.organization === "free" || !Backend.desktopModel.keepAligned) {
            const blocked = desktopDragItems.some(entry => desktopPlacementOverlapsShell(entry.item.x, entry.item.y, entry.item.width, entry.item.height));
            for (const entry of desktopDragItems) {
                if (blocked) {
                    entry.item.x = entry.x;
                    entry.item.y = entry.y;
                }
                Backend.desktopModel.savePosition(entry.item.app.id, entry.item.x, entry.item.y);
            }
        } else {
            snapDesktopDragToGrid();
        }
        desktopDragging = false;
        desktopDragAnchor = null;
        desktopDragItems = [];
    }

    // Keeps the clock state out of the visual component.
    property Timer clock: Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: controller.currentTime = new Date()
    }
}
