import QtQuick
import QtQuick.Window
import gui
import "../scripts/constants.js" as Constants
import "../scripts/desktop/collision.js" as Collision
import "../scripts/desktop/grid.js" as Grid

// Owns the graphical shell state and every operation triggered by its views.
QtObject {
    id: controller

    required property var window
    required property var filesQuickWindow

    property string pendingFilesLocation: ""
    property Connections filesConnection: Connections {
        target: controller.filesQuickWindow || null
        function onControllerChanged() { controller.applyFilesLocation(); }
    }

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
    property bool externalDesktopDrag: false
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

    function select(entry, contextMenu = false) {
        if (contextMenu && isDesktopShortcutSelected(entry.id)) {
            return;
        }
        selectOnlyDesktopShortcut(entry.id);
    }

    property Timer resizeTimer: Timer {
        interval: 100
        onTriggered: {
            if (controller.desktopDragging || controller.stackDragPending) {
                restart();
            } else if (controller.desktopShortcutRepeater) {
                controller.arrangeDesktop();
            }
        }
    }
    property Connections viewportConnection: Connections {
        target: controller.desktopShortcuts || null
        function onWidthChanged() { controller.resizeTimer.restart(); }
        function onHeightChanged() { controller.resizeTimer.restart(); }
    }
    property Connections transferConnection: Connections {
        target: Backend.fileTransfer || null
        function onFailed(message) { controller.desktopOperationError = message; }
    }

    property Connections clipboardConnection: Connections {
        target: Backend.clipboard || null
        function onFailed(message) { controller.desktopOperationError = message; }
    }

    // File preview windows will consume one request per opened file.
    signal filePreviewRequested(var entry)
    onFilePreviewRequested: entry => previewEntry(entry)

    function contextEntries(entry) {
        let ids = isDesktopShortcutSelected(entry.id) ? selectedDesktopIds.slice() : [entry.id];
        if (Backend.desktopModel.organization === "stack") {
            const stack = stackInfo(entry);
            if (stack.leader && !stack.expanded) {
                const group = Backend.desktopModel.groups.find(group => group.key === stack.key);
                if (group) {
                    ids = Array.from(new Set(ids.concat(group.members)));
                }
            }
        }
        const entries = [];
        for (let index = 0; index < desktopShortcutRepeater.count; ++index) {
            const item = desktopShortcutRepeater.itemAt(index);
            if (item && item.app && ids.indexOf(item.app.id) !== -1) {
                entries.push(item.app);
            }
        }
        return entries;
    }

    function entryAction(action, entry) {
        const entries = contextEntries(entry);
        if (action === "open") {
            for (const item of entries) {
                if (item.isDirectory && item.url) {
                    window.openFolderWindow(item.url);
                } else {
                    filePreviewRequested(item);
                }
            }
        } else if (action === "copy" || action === "cut") {
            Backend.clipboard.copy(entries.map(item => item.url), action === "cut");
        } else if (action === "paste") {
            Backend.clipboard.paste(entry.isDirectory ? entry.url : Backend.desktopModel.directory);
        }
    }

    function previewEntry(entry) {
        const siblings = [];
        for (let row = 0; row < desktopShortcutRepeater.count; ++row) {
            const shortcut = desktopShortcutRepeater.itemAt(row);
            if (shortcut && shortcut.app && !shortcut.app.isDirectory && shortcut.app.url) {
                siblings.push(shortcut.app.url);
            }
        }
        Backend.openPreview(entry.url, siblings);
    }

    function openEntry(entry) {
        if (!entry.url) {
            return;
        }
        if (!entry.isDirectory) {
            previewEntry(entry);
            return;
        }
        closePanel();
        window.openFolderWindow(String(entry.url));
    }

    function applyFilesLocation() {
        if (pendingFilesLocation && filesQuickWindow && filesQuickWindow.controller) {
            filesQuickWindow.controller.selectedEntry = {};
            filesQuickWindow.controller.directory.open(pendingFilesLocation);
            pendingFilesLocation = "";
        }
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

    function openTrashQuickWindow() {
        openFilesQuickWindow();
        if (filesQuickWindow.controller) {
            filesQuickWindow.controller.openPlace("trash");
        }
    }

    // Opens the desktop context menu at a position constrained to the window.
    function openDesktopShortcutMenu(shortcut, localX, localY, shortcutName) {
        const position = shortcut.mapToItem(window.contentItem, localX, localY);

        desktopContextMenu.shortcutName = shortcutName || qsTranslate("Pedro", "desktop.title");
        const menuX = Math.max(12, Math.min(window.width - desktopContextMenu.width - 12, position.x));
        const menuY = Math.max(12, Math.min(window.height - desktopContextMenu.height - 12, position.y));
        desktopContextMenu.popup(menuX, menuY);
    }

    function wallpaperAction(action) {
        desktopOperationError = "";
        if (action === "select") {
            const selected = [];
            for (let index = 0; index < desktopShortcutRepeater.count; ++index) {
                const item = desktopShortcutRepeater.itemAt(index);
                if (item && item.app) {
                    selected.push(item.app.id);
                }
            }
            selectedDesktopIds = selected;
        } else if (action === "folder") {
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
        } else if (action === "name" || action === "type" || action === "date" || action === "size") {
            if (desktopDragging) {
                endDesktopDrag();
            }
            if (!Backend.desktopModel.sortKey && Backend.desktopModel.organization !== "stack") {
                for (let index = 0; index < desktopShortcutRepeater.count; ++index) {
                    const item = desktopShortcutRepeater.itemAt(index);
                    if (item) {
                        Backend.desktopModel.savePosition(item.app.id, item.x, item.y);
                    }
                }
            }
            Backend.desktopModel.sort(action);
        } else if (action === "paste") {
            Backend.clipboard.paste(Backend.desktopModel.directory);
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
                    visible: member === 0 || expanded, expanded: expanded, slot: slot + (expanded ? member + (group.members.length > 1 ? 1 : 0) : 0)};
            }
            slot += expanded ? group.members.length + (group.members.length > 1 ? 1 : 0) : 1;
        }
        return {key: "file", count: 1, leader: true, visible: true, expanded: false, slot: slot};
    }

    function stackIndicatorEntry(group) {
        for (let index = 0; index < desktopShortcutRepeater.count; ++index) {
            const item = desktopShortcutRepeater.itemAt(index);
            if (item && item.app.id === group.members[0]) {
                return Object.assign({}, item.app);
            }
        }
        return {id: group.members[0], icon: group.key, isDirectory: group.key === "folder"};
    }

    function toggleStack(entry) {
        const info = stackInfo(entry);
        const expanded = expandedDesktopStacks.slice();
        const index = expanded.indexOf(info.key);
        if (index === -1) {
            selectedDesktopIds = [];
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
            item.initialPosition = Qt.point(position.x, position.y);
            item.x = position.x;
            item.y = position.y;
        }
    }

    // Explicit sorting redistributes icons without changing the organization mode.
    function sortDesktop() {
        if (Backend.desktopModel.organization === "stack") {
            arrangeDesktop();
            return;
        }

        const placements = [];
        for (let index = 0; index < desktopShortcutRepeater.count; ++index) {
            const item = desktopShortcutRepeater.itemAt(index);
            if (item) {
                const position = desktopStackPosition(index);
                placements.push({item: item, x: position.x, y: position.y});
            }
        }

        // Apply the whole layout before model notifications update saved positions.
        for (const placement of placements) {
            placement.item.initialPosition = Qt.point(placement.x, placement.y);
            placement.item.x = placement.x;
            placement.item.y = placement.y;
        }
        for (const placement of placements) {
            Backend.desktopModel.savePosition(placement.item.app.id, placement.x, placement.y);
        }
    }

    // Keep a small inset even when the viewport cannot fit a full cell.
    function desktopInset(extent, itemExtent) {
        return Math.min(8, Math.max(0, (extent - itemExtent) / 2));
    }

    function desktopGap() {
        return desktopShortcuts.cellGap || 0;
    }

    function desktopItemWidth() {
        return desktopShortcuts.cellWidth - desktopGap();
    }

    function desktopItemHeight() {
        return desktopShortcuts.cellHeight - desktopGap();
    }

    // Preserve saved grid positions unless they violate spacing with earlier items.
    function desktopSpacedPosition(x, y, index) {
        function available(candidateX, candidateY) {
            if (desktopPlacementOverlapsShell(candidateX, candidateY, desktopItemWidth(), desktopItemHeight())) {
                return false;
            }
            for (let previous = 0; previous < index; ++previous) {
                const item = desktopShortcutRepeater.itemAt(previous);
                if (!item) {
                    continue;
                }
                const position = item.initialPosition || Qt.point(item.x, item.y);
                if (candidateX < position.x + item.width + desktopGap()
                        && candidateX + desktopItemWidth() + desktopGap() > position.x
                        && candidateY < position.y + item.height + desktopGap()
                        && candidateY + desktopItemHeight() + desktopGap() > position.y) {
                    return false;
                }
            }
            return true;
        }

        if (available(x, y)) {
            return Qt.point(x, y);
        }

        let closest = null;
        let distance = Number.MAX_VALUE;

        for (const candidate of desktopGridCandidates()) {
            const candidateDistance = Math.pow(candidate.x - x, 2) + Math.pow(candidate.y - y, 2);
            if (candidateDistance < distance && available(candidate.x, candidate.y)) {
                closest = Qt.point(candidate.x, candidate.y);
                distance = candidateDistance;
            }
        }
        return closest || desktopInitialPosition(index);
    }

    // Restores persisted positions, constraining them to the current screen.
    function desktopRestoredPosition(entry, index) {
        if (Backend.desktopModel.organization === "stack") {
            return desktopStackPosition(stackInfo(entry).slot);
        }
        if (entry.position) {
            const insetX = desktopInset(desktopShortcuts.width, desktopItemWidth());
            const insetY = desktopInset(desktopShortcuts.height, desktopItemHeight());
            const x = Math.max(insetX, Math.min(entry.position.x, desktopShortcuts.width - desktopItemWidth() - insetX));
            const y = Math.max(insetY, Math.min(entry.position.y, desktopShortcuts.height - desktopItemHeight() - insetY));

            if (Backend.desktopModel.organization === "grid") {
                return desktopSpacedPosition(x, y, index);
            }

            if (!desktopPlacementOverlapsShell(x, y, desktopItemWidth(), desktopItemHeight())) {
                return Qt.point(x, y);
            }
        }

        return desktopInitialPosition(index);
    }

    // Fill stack columns from each free segment below the shell controls.
    function desktopStackPosition(index) {
        const bounds = desktopGridBounds();
        const positions = Grid.stack(bounds, desktopObstacleRectangles(), desktopItemWidth(), desktopItemHeight(),
            desktopShortcuts.cellWidth, desktopShortcuts.cellHeight, desktopGap());
        const position = positions[index];

        return position ? Qt.point(position.x, position.y)
            : Qt.point(bounds.x, bounds.y + bounds.height + desktopGap());
    }

    // Places initial model entries in free desktop cells without filesystem logic.
    function desktopInitialPosition(index, ignoreSaved = false) {
        if (Backend.desktopModel.organization === "grid") {
            const candidates = desktopGridCandidates().sort((first, second) => first.y - second.y || first.x - second.x);

            for (const candidate of candidates) {
                const rectangle = {x: candidate.x, y: candidate.y, width: desktopItemWidth(), height: desktopItemHeight()};
                let reserved = false;

                for (let itemIndex = 0; itemIndex < desktopShortcutRepeater.count; ++itemIndex) {
                    const item = desktopShortcutRepeater.itemAt(itemIndex);
                    if (!item || !item.visible) {
                        continue;
                    }

                    const saved = item.app ? item.app.position : null;
                    const previous = itemIndex < index ? item.initialPosition || Qt.point(item.x, item.y) : null;
                    if ((!ignoreSaved && saved && Grid.intersects(rectangle,
                                {x: saved.x, y: saved.y, width: desktopItemWidth(), height: desktopItemHeight()}, desktopGap()))
                            || (previous && Grid.intersects(rectangle,
                                {x: previous.x, y: previous.y, width: desktopItemWidth(), height: desktopItemHeight()}, desktopGap()))) {
                        reserved = true;
                        break;
                    }
                }

                if (!reserved) {
                    return Qt.point(candidate.x, candidate.y);
                }
            }
        }

        let slot = 0;
        const insetX = desktopInset(desktopShortcuts.width, desktopItemWidth());
        const insetY = desktopInset(desktopShortcuts.height, desktopItemHeight());
        const columns = Math.max(1, Math.floor((desktopShortcuts.width - insetX * 2 + desktopGap()) / desktopShortcuts.cellWidth));
        const rows = Math.max(1, Math.floor((desktopShortcuts.height - insetY * 2 + desktopGap()) / desktopShortcuts.cellHeight));

        for (let row = 0; row < rows; ++row) {
            for (let column = 0; column < columns; ++column) {
                const x = insetX + column * desktopShortcuts.cellWidth;
                const y = insetY + row * desktopShortcuts.cellHeight;

                let reserved = false;

                for (let itemIndex = 0; itemIndex < desktopShortcutRepeater.count; ++itemIndex) {
                    const item = desktopShortcutRepeater.itemAt(itemIndex);
                    const saved = item && item.app ? item.app.position : null;

                    if (!ignoreSaved && saved && x < saved.x + desktopItemWidth() && x + desktopItemWidth() > saved.x
                            && y < saved.y + desktopItemHeight() && y + desktopItemHeight() > saved.y) {
                        reserved = true;
                        break;
                    }
                }

                if (!reserved && !desktopPlacementOverlapsShell(x, y, desktopItemWidth(), desktopItemHeight())) {
                    if (slot++ === index) {
                        return Qt.point(x, y);
                    }
                }
            }
        }

        return Qt.point(insetX + (index % columns) * desktopShortcuts.cellWidth,
            insetY + rows * desktopShortcuts.cellHeight);
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

    function draggedDesktopUrls() {
        if (stackDragPending && stackDragSource) {
            return contextEntries(stackDragSource.app).map(entry => entry.url);
        }
        return desktopDragItems.map(entry => entry.item.app.url);
    }

    function updateDesktopDropTarget(shortcut, localX, localY) {
        const point = shortcut.mapToItem(desktopShortcuts, localX, localY);
        const urls = draggedDesktopUrls();
        stackDropTargetId = "";
        for (let index = 0; index < desktopShortcutRepeater.count; ++index) {
            const candidate = desktopShortcutRepeater.itemAt(index);
            if (!candidate || !candidate.visible || !candidate.app.isDirectory
                    || urls.indexOf(candidate.app.url) !== -1
                    || (candidate.stack && candidate.stacked && candidate.stack.leader && candidate.stack.count > 1 && !candidate.stack.expanded)) {
                continue;
            }
            if (point.x >= candidate.x && point.x <= candidate.x + candidate.width
                    && point.y >= candidate.y && point.y <= candidate.y + candidate.height
                    && Backend.fileTransfer.canMove(urls, candidate.app.url)) {
                stackDropTargetId = candidate.app.id;
                break;
            }
        }
        const globalPoint = shortcut.mapToGlobal(localX, localY);
        if (window.fileDropWindowAt && window.fileDropWindowAt(globalPoint)) {
            externalDesktopDrag = true;
            Backend.dragFiles(shortcut, urls);
            externalDesktopDrag = false;
            for (const entry of desktopDragItems) {
                if (entry.item) {
                    entry.item.x = entry.x;
                    entry.item.y = entry.y;
                    entry.item.initialPosition = Qt.point(entry.x, entry.y);
                }
            }
            desktopDragging = false;
            desktopDragItems = [];
            desktopDragAnchor = null;
            stackDragPending = false;
            stackDragActive = false;
            stackDragSource = null;
            stackDropTargetId = "";
            return true;
        }
        return false;
    }

    function dropDesktopIntoFolder() {
        if (!stackDropTargetId) {
            return false;
        }
        const urls = draggedDesktopUrls();
        for (let index = 0; index < desktopShortcutRepeater.count; ++index) {
            const candidate = desktopShortcutRepeater.itemAt(index);
            if (candidate && candidate.app.id === stackDropTargetId && Backend.fileTransfer.canMove(urls, candidate.app.url)) {
                Backend.fileTransfer.move(urls, candidate.app.url);
                for (const entry of desktopDragItems) {
                    entry.item.x = entry.x;
                    entry.item.y = entry.y;
                    entry.item.initialPosition = Qt.point(entry.x, entry.y);
                }
                desktopDragging = false;
                desktopDragItems = [];
                desktopDragAnchor = null;
                stackDragPending = false;
                stackDragActive = false;
                stackDragSource = null;
                stackDropTargetId = "";
                return true;
            }
        }
        return false;
    }

    // Captures the selected shortcuts before a grouped desktop drag.
    function beginDesktopDrag(shortcut, localX, localY) {
        if (renamingDesktopId.length > 0) {
            return;
        }
        if (window.keepFileWindowActive) {
            Qt.callLater(window.keepFileWindowActive);
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
            shortcut.closeMenu();
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
        shortcut.closeMenu();
    }

    // Moves the selected shortcuts while keeping them inside the desktop area.
    function updateDesktopDrag(shortcut, localX, localY) {
        if (stackDragPending) {
            stackDragActive = true;
            stackDragPoint = shortcut.mapToItem(desktopShortcuts, localX, localY);
            updateDesktopDropTarget(shortcut, localX, localY);
            return;
        }
        if (!desktopDragging || desktopDragItems.length === 0) {
            return;
        }

        if (updateDesktopDropTarget(shortcut, localX, localY)) {
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

        const insetX = desktopInset(desktopShortcuts.width, maximumX - minimumX);
        const insetY = desktopInset(desktopShortcuts.height, maximumY - minimumY);
        movementX = Math.max(insetX - minimumX, Math.min(desktopShortcuts.width - maximumX - insetX, movementX));
        movementY = Math.max(insetY - minimumY, Math.min(desktopShortcuts.height - maximumY - insetY, movementY));

        const rectangles = desktopDragItems.map(entry => ({x: entry.item.x, y: entry.item.y,
            width: entry.item.width, height: entry.item.height}));
        const obstacles = desktopObstacleRectangles();
        const currentX = desktopDragItems[0].item.x - desktopDragItems[0].x;
        const currentY = desktopDragItems[0].item.y - desktopDragItems[0].y;
        const allowed = Collision.constrain(rectangles, obstacles, movementX - currentX, movementY - currentY);
        movementX = currentX + allowed.x;
        movementY = currentY + allowed.y;

        for (let index = 0; index < desktopDragItems.length; ++index) {
            const entry = desktopDragItems[index];

            entry.item.x = entry.x + movementX;
            entry.item.y = entry.y + movementY;
        }
    }

    // Uses the same clearance for collision barriers and local grid boundaries.
    function desktopObstacleRectangles() {
        const rectangles = [];

        for (const obstacle of desktopObstacles) {
            if (!obstacle || !obstacle.visible || obstacle.width <= 0 || obstacle.height <= 0) {
                continue;
            }

            const position = obstacle.mapToItem(desktopShortcuts, 0, 0);
            rectangles.push({x: position.x - 8, y: position.y - 8,
                width: obstacle.width + 16, height: obstacle.height + 16});
        }

        return rectangles;
    }

    function desktopGridBounds() {
        const insetX = desktopInset(desktopShortcuts.width, desktopItemWidth());
        const insetY = desktopInset(desktopShortcuts.height, desktopItemHeight());

        return {x: insetX, y: insetY, width: desktopShortcuts.width - insetX * 2,
            height: desktopShortcuts.height - insetY * 2};
    }

    function desktopGridCandidates() {
        return Grid.candidates(desktopGridBounds(), desktopObstacleRectangles(),
            desktopItemWidth(), desktopItemHeight(), desktopShortcuts.cellWidth, desktopShortcuts.cellHeight);
    }

    // Reports whether a proposed shortcut position overlaps fixed shell chrome.
    function desktopPlacementOverlapsShell(itemX, itemY, itemWidth, itemHeight) {
        const rectangle = {x: itemX, y: itemY, width: itemWidth, height: itemHeight};
        return desktopObstacleRectangles().some(obstacle => Grid.intersects(rectangle, obstacle, 0));
    }

    // Snaps a grouped drag to the nearest free set of desktop grid cells.
    function snapDesktopDragToGrid() {
        if (!desktopDragAnchor || desktopDragItems.length === 0) {
            return;
        }

        const anchor = desktopDragItems.find(entry => entry.item === desktopDragAnchor) || desktopDragItems[0];
        const entries = [anchor].concat(desktopDragItems.filter(entry => entry !== anchor));
        const occupied = [];

        for (let index = 0; index < desktopShortcutRepeater.count; ++index) {
            const shortcut = desktopShortcutRepeater.itemAt(index);

            if (shortcut && shortcut.visible && !isDesktopShortcutSelected(shortcut.app.id)) {
                occupied.push({x: shortcut.x, y: shortcut.y, width: shortcut.width, height: shortcut.height});
            }
        }

        // Retain the spacing of the grid where this selection started.
        let origin = {cellWidth: desktopShortcuts.cellWidth, cellHeight: desktopShortcuts.cellHeight};
        let originDistance = Infinity;

        for (const candidate of desktopGridCandidates()) {
            const distance = Math.pow(candidate.x - anchor.x, 2) + Math.pow(candidate.y - anchor.y, 2);
            if (distance < originDistance) {
                origin = candidate;
                originDistance = distance;
            }
        }

        const cells = entries.map(entry => ({width: entry.item.width, height: entry.item.height,
            column: Math.round((entry.x - anchor.x) / origin.cellWidth),
            row: Math.round((entry.y - anchor.y) / origin.cellHeight)}));
        const result = Grid.placement(desktopGridBounds(), desktopObstacleRectangles(), occupied, cells,
            {x: desktopDragAnchor.x, y: desktopDragAnchor.y},
            desktopShortcuts.cellWidth, desktopShortcuts.cellHeight, desktopGap());
        let bestPlacement = result ? result.map((position, index) => ({item: entries[index].item,
            x: position.x, y: position.y})) : null;

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

            placement.item.initialPosition = Qt.point(placement.x, placement.y);
            placement.item.x = placement.x;
            placement.item.y = placement.y;
            const original = desktopDragItems.find(entry => entry.item === placement.item);
            const moved = original && (placement.x !== original.x || placement.y !== original.y);
            Backend.desktopModel.savePosition(placement.item.app.id, placement.x, placement.y, !!moved);
        }
    }

    function cancelDesktopDrag() {
        if (externalDesktopDrag) {
            return;
        }
        for (const entry of desktopDragItems) {
            entry.item.x = entry.x;
            entry.item.y = entry.y;
            entry.item.initialPosition = Qt.point(entry.x, entry.y);
        }
        desktopDragging = false;
        desktopDragItems = [];
        desktopDragAnchor = null;
        stackDragPending = false;
        stackDragActive = false;
        stackDragSource = null;
        stackDropTargetId = "";
    }

    // Completes a desktop drag and clears its transient state.
    function endDesktopDrag() {
        if (externalDesktopDrag) {
            return;
        }
        if (dropDesktopIntoFolder()) {
            return;
        }
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
                entry.item.initialPosition = Qt.point(entry.item.x, entry.item.y);
                Backend.desktopModel.savePosition(entry.item.app.id, entry.item.x, entry.item.y,
                    entry.item.x !== entry.x || entry.item.y !== entry.y);
            }
        } else {
            snapDesktopDragToGrid();
        }
        desktopDragging = false;
        desktopDragAnchor = null;
        desktopDragItems = [];
        stackDropTargetId = "";
    }

    // Keeps the clock state out of the visual component.
    property Timer clock: Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: controller.currentTime = new Date()
    }
}
