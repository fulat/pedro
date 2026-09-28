import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic
import gui
import "qml/bar" as Bar
import "qml/icon" as Icon
import "qml/panel" as Panel

ApplicationWindow {
    id: window

    readonly property real designAspectRatio: 20 / 13
    readonly property real developmentWidth: Screen.desktopAvailableWidth > 0
                                                 ? Math.min(1600, Screen.desktopAvailableWidth * 0.82)
                                                 : 1280
    readonly property real developmentHeight: Screen.desktopAvailableHeight > 0
                                                  ? Math.min(developmentWidth / designAspectRatio,
                                                             Screen.desktopAvailableHeight * 0.82)
                                                  : developmentWidth / designAspectRatio

    width: Papi.developmentMode ? developmentWidth : 3500
    height: Papi.developmentMode ? developmentHeight : 1400
    minimumWidth: Papi.developmentMode ? Math.min(640, developmentWidth) : 0
    minimumHeight: Papi.developmentMode ? Math.min(416, developmentHeight) : 0
    visible: true
    title: qsTr("Pedro OS")
    visibility: Papi.developmentMode ? Window.Windowed : Window.FullScreen
    color: "#05080c"

    property string panelMode: ""
    property string panelSource: ""
    property real panelAnchorX: width - 190
    property date currentTime: new Date()
    property var selectedDesktopIds: []
    property var desktopDragItems: []
    property var desktopDragAnchor: null
    property point desktopDragOrigin: Qt.point(0, 0)
    property bool desktopDragging: false
    property var pinnedApps: [
        { id: "files", name: "Archivos", icon: "folder" },
        { id: "browser", name: "Navegador", icon: "browser" },
        { id: "terminal", name: "Terminal", icon: "terminal" },
        { id: "music", name: "Música", icon: "music" },
        { id: "photos", name: "Fotos", icon: "photos" }
    ]
    property var recentApps: [
        { id: "chat", name: "Mensajes", icon: "chat" },
        { id: "notes", name: "Notas", icon: "notes" },
        { id: "code", name: "Código", icon: "code" }
    ]
    readonly property real dockIconSize: Math.max(27, Math.min(38, width / 42))
    readonly property real dockTileSize: dockIconSize + 14
    readonly property real dockSpacing: Math.max(5, Math.min(10, width / 160))

    signal applicationRequested(string applicationId)

    function closePanel() {
        panelMode = "";
        panelSource = ""
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

    function activateDockApp(app) {
        if (app.id === "files") {
            togglePanel("files", dock.x + dock.width / 2, "dock-files");
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

    function openDesktopShortcutMenu(shortcut, localX, localY) {
        const position = shortcut.mapToItem(window.contentItem, localX, localY);

        desktopContextMenu.shortcutName = shortcut.app ? shortcut.app.name : "Elemento";
        desktopContextMenu.x = Math.max(12, Math.min(window.width - desktopContextMenu.width - 12,
                                                     position.x));
        desktopContextMenu.y = Math.max(topBar.barHeight + 8,
                                        Math.min(window.height - desktopContextMenu.height - 12,
                                                 position.y));
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

            const intersects = shortcut.x < rectangle.x + rectangle.width
                               && shortcut.x + shortcut.width > rectangle.x
                               && shortcut.y < rectangle.y + rectangle.height
                               && shortcut.y + shortcut.height > rectangle.y;
            const selectedIndex = selected.indexOf(shortcut.app.id);

            if (intersects && selectedIndex === -1) {
                selected.push(shortcut.app.id);
            } else if (!intersects && selectedIndex !== -1
                       && baseSelection.indexOf(shortcut.app.id) === -1) {
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
                items.push({ item: candidate, x: candidate.x, y: candidate.y });
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

        movementX = Math.max(-minimumX,
                             Math.min(desktopShortcuts.width - maximumX, movementX));
        movementY = Math.max(-minimumY,
                             Math.min(desktopShortcuts.height - maximumY, movementY));

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

        return itemX < reservedX + reservedWidth
               && itemX + itemWidth > reservedX
               && itemY < reservedY + reservedHeight
               && itemY + itemHeight > reservedY;
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
        const maximumColumn = Math.max(0, Math.floor((desktopShortcuts.width
                                                      - desktopDragAnchor.width) / cellWidth));
        const maximumRow = Math.max(0, Math.floor((desktopShortcuts.height
                                                   - desktopDragAnchor.height) / cellHeight));
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

                    if (targetColumn < 0 || targetRow < 0
                            || targetX + cell.item.width > desktopShortcuts.width
                            || targetY + cell.item.height > desktopShortcuts.height
                            || desktopPlacementOverlapsShell(targetX, targetY,
                                                             cell.item.width, cell.item.height)
                            || occupied[key] || placementCells[key]) {
                        valid = false;
                        break;
                    }

                    placementCells[key] = true;
                    placement.push({ item: cell.item, x: targetX, y: targetY });
                }

                if (!valid) {
                    continue;
                }

                const distance = Math.pow(column - preferredColumn, 2)
                                 + Math.pow(row - preferredRow, 2);
                const directionPenalty = (horizontalDirection !== 0
                                          && (column - preferredColumn) * horizontalDirection < 0 ? 1 : 0)
                                         + (verticalDirection !== 0
                                            && (row - preferredRow) * verticalDirection < 0 ? 1 : 0);

                if (distance < bestDistance
                        || (distance === bestDistance && directionPenalty < bestDirectionPenalty)) {
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

    Window {
        id: filesQuickWindow

        width: 520
        height: 340
        x: window.x + Math.round((window.width - width) / 2)
        y: window.y + Math.round((window.height - height) / 2)
        visible: false
        transientParent: window
        title: "Archivos · Ventana rápida"
        color: "transparent"
        flags: Qt.Window | Qt.FramelessWindowHint

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "#2c2c2c"
            border.width: 1
            border.color: "#454545"

            Rectangle {
                id: filesTitleBar

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 44
                radius: parent.radius
                color: "#323232"

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onPressed: filesQuickWindow.startSystemMove()
                    onDoubleClicked: {
                        if (filesQuickWindow.visibility === Window.Maximized) {
                            filesQuickWindow.showNormal();
                        } else {
                            filesQuickWindow.showMaximized();
                        }
                    }
                }

                Row {
                    z: 2
                    anchors.left: parent.left
                    anchors.leftMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Repeater {
                        model: [
                            { action: "close", color: "#ff5f57", glyph: "×", glyphColor: "#68110d" },
                            { action: "minimize", color: "#febc2e", glyph: "−", glyphColor: "#765000" },
                            { action: "maximize", color: "#28c840", glyph: "+", glyphColor: "#0b5d18" }
                        ]

                        delegate: Item {
                            id: windowControl

                            required property var modelData
                            width: 23
                            height: 28

                            Rectangle {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                radius: width / 2
                                color: windowControl.modelData.color
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: controlMouse.containsMouse
                                text: windowControl.modelData.glyph
                                color: windowControl.modelData.glyphColor
                                font.pixelSize: windowControl.modelData.action === "close" ? 14 : 13
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: controlMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (windowControl.modelData.action === "close") {
                                        filesQuickWindow.hide();
                                    } else if (windowControl.modelData.action === "minimize") {
                                        filesQuickWindow.showMinimized();
                                    } else if (filesQuickWindow.visibility === Window.Maximized) {
                                        filesQuickWindow.showNormal();
                                    } else {
                                        filesQuickWindow.showMaximized();
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: filesQuickWindow.title
                    color: "#dedede"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
            }

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: filesTitleBar.height / 2
                text: "Ventana rápida"
                color: "#ffffff"
                font.pixelSize: 24
                font.weight: Font.Medium
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: window.currentTime = new Date()
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: "assets/wallpaper.jpeg"
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: "#19000000"
            }
            GradientStop {
                position: 0.5
                color: "#00000000"
            }
            GradientStop {
                position: 1.0
                color: "#26000000"
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.topMargin: topBar.barHeight
        onClicked: window.closePanel()
    }

    Item {
        id: desktopShortcuts

        readonly property real cellWidth: 106
        readonly property real cellHeight: 102

        z: 10
        anchors.fill: parent
        anchors.leftMargin: 0
        anchors.topMargin: topBar.barHeight
        anchors.rightMargin: 0
        anchors.bottomMargin: 100

        MouseArea {
            id: desktopSelectionArea

            property real originX
            property real originY
            property var baseSelection: []

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: selectionRectangle.visible ? Qt.CrossCursor : Qt.ArrowCursor

            onPressed: mouse => {
                originX = mouse.x;
                originY = mouse.y;
                baseSelection = (mouse.modifiers & Qt.ControlModifier)
                                ? window.selectedDesktopIds.slice() : [];
                selectionRectangle.x = originX;
                selectionRectangle.y = originY;
                selectionRectangle.width = 0;
                selectionRectangle.height = 0;
                selectionRectangle.visible = true;
                window.selectedDesktopIds = baseSelection.slice();
                window.closePanel();
                desktopContextMenu.close();
            }

            onPositionChanged: mouse => {
                if (!(pressedButtons & Qt.LeftButton)) {
                    return;
                }

                selectionRectangle.x = Math.min(originX, mouse.x);
                selectionRectangle.y = Math.min(originY, mouse.y);
                selectionRectangle.width = Math.abs(mouse.x - originX);
                selectionRectangle.height = Math.abs(mouse.y - originY);
                window.selectDesktopShortcutsInRectangle(selectionRectangle, baseSelection);
            }

            onReleased: selectionRectangle.visible = false
            onCanceled: selectionRectangle.visible = false
        }

        Repeater {
            id: desktopShortcutRepeater

            model: [
                { id: "projects", name: "Proyectos", icon: "folder", mode: "files", column: 0, row: 0 },
                { id: "notes", name: "Notas", icon: "notes", mode: "about", column: 1, row: 0 },
                { id: "wallpaper", name: "Wallpaper.jpg", icon: "image", mode: "about", column: 2, row: 0 },
                { id: "designs", name: "Diseños", icon: "folder", mode: "files", column: 3, row: 0 }
            ]

            delegate: DesktopShortcut {
                id: desktopShortcut

                required property var modelData

                x: modelData.column * desktopShortcuts.cellWidth
                y: modelData.row * desktopShortcuts.cellHeight
                app: modelData
                selected: window.isDesktopShortcutSelected(modelData.id)
                onMenuRequested: (localX, localY) => {
                    window.closePanel();
                    window.openDesktopShortcutMenu(desktopShortcut, localX, localY);
                }
            }
        }

        Rectangle {
            id: selectionRectangle

            z: 20
            visible: false
            color: "#5c315f99"
            border.width: 1
            border.color: "#d05f98d8"
        }
    }

    Popup {
        id: desktopContextMenu

        property string shortcutName

        z: 100
        width: 202
        height: 78
        padding: 0
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 12
            color: "#f02b2b2b"
            border.width: 1
            border.color: "#5c777777"
        }

        contentItem: Column {
            leftPadding: 13
            rightPadding: 13
            topPadding: 11
            bottomPadding: 10
            spacing: 5

            Label {
                width: desktopContextMenu.width - 26
                text: desktopContextMenu.shortcutName
                color: "#ffffff"
                font.pixelSize: 13
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Label {
                width: desktopContextMenu.width - 26
                text: "Sin acciones disponibles"
                color: "#aeb4b8"
                font.pixelSize: 11
            }
        }
    }

    Item {
        id: sideBar

        z: 16
        x: 9
        anchors.verticalCenter: parent.verticalCenter
        width: 76
        height: Math.min(530, window.height - 100)

        MatteSurface {
            anchors.fill: parent
            cornerRadius: 38
        }

        Column {
            id: navigation

            anchors.centerIn: parent
            spacing: Math.max(4, Math.min(9, window.height / 100))

            Repeater {
                model: [
                    { id: "home", name: "Inicio", icon: "home", mode: "" },
                    { id: "files", name: "Archivos", icon: "folder", mode: "files" },
                    { id: "apps", name: "Aplicaciones", icon: "apps", mode: "about" },
                    { id: "messages", name: "Mensajes", icon: "chat", mode: "about" },
                    { id: "settings", name: "Configuración", icon: "settings", mode: "system" },
                    { id: "focus", name: "Concentración", icon: "moon", mode: "quick" },
                    { id: "documents", name: "Documentos", icon: "notes", mode: "files" },
                    { id: "display", name: "Pantalla", icon: "brightness", mode: "quick" },
                    { id: "power", name: "Energía", icon: "power", mode: "system" }
                ]

                delegate: Item {
                    id: navigationEntry

                    required property var modelData
                    readonly property bool selected: modelData.id === "home"
                                                      ? window.panelMode === "" && !filesQuickWindow.visible
                                                      : modelData.id === "files"
                                                        ? filesQuickWindow.visible
                                                        : window.panelSource === "nav-" + modelData.id

                    width: 60
                    height: Math.min(48, (sideBar.height - 24 - navigation.spacing * 8) / 9)

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(47, parent.height)
                        height: width
                        radius: width / 2
                        color: "#22ffffff"
                        opacity: navigationMouse.containsMouse && !navigationEntry.selected ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: 140 }
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(47, parent.height)
                        height: width
                        radius: width / 2
                        visible: navigationEntry.selected
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#3d59ba" }
                            GradientStop { position: 1; color: "#343d86" }
                        }
                        border.width: 1
                        border.color: "#587daed8"
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(47, parent.height)
                        height: width
                        radius: width / 2
                        color: "#18ffffff"
                        opacity: navigationMouse.containsMouse && navigationEntry.selected ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: 140 }
                        }
                    }

                    NavigationGlyph {
                        anchors.centerIn: parent
                        width: Math.min(26, navigationEntry.height * 0.58)
                        height: width
                        kind: navigationEntry.modelData.icon
                        visible: kind === "home" || kind === "folder"
                                 || kind === "apps" || kind === "chat" || kind === "notes"
                    }

                    Icon.Tinted {
                        anchors.centerIn: parent
                        width: Math.min(26, navigationEntry.height * 0.58)
                        height: width
                        visible: navigationEntry.modelData.icon === "settings"
                                 || navigationEntry.modelData.icon === "moon"
                                 || navigationEntry.modelData.icon === "brightness"
                                 || navigationEntry.modelData.icon === "power"
                        source: "assets/icons/" + navigationEntry.modelData.icon + ".svg"
                        tint: "#ffffff"
                    }

                    MouseArea {
                        id: navigationMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (navigationEntry.modelData.id === "home") {
                                window.closePanel();
                                return;
                            }

                            if (navigationEntry.modelData.id === "files") {
                                window.openFilesQuickWindow();
                                return;
                            }

                            window.togglePanel(navigationEntry.modelData.mode,
                                               sideBar.x + sideBar.width / 2,
                                               "nav-" + navigationEntry.modelData.id);
                        }
                    }

                    ToolTip.visible: navigationMouse.containsMouse
                    ToolTip.delay: 500
                    ToolTip.text: navigationEntry.modelData.name
                }
            }
        }
    }

    Item {
        id: weatherCard

        z: 12
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: window.width < 900 ? 105 : 18
        width: 190
        height: 70

        MatteSurface {
            anchors.fill: parent
            cornerRadius: 35
        }

        // Visual placeholder until weather information is supplied by PAPI.
        Rectangle {
            x: 27
            y: 16
            width: 25
            height: 25
            radius: 13
            color: "#ffc42d"
        }

        Rectangle {
            x: 20
            y: 35
            width: 42
            height: 17
            radius: 9
            color: "#f8f8f6"
        }

        Rectangle {
            x: 27
            y: 28
            width: 24
            height: 20
            radius: 10
            color: "#f8f8f6"
        }

        Text {
            x: 80
            y: 9
            text: "28°"
            color: "#ffffff"
            font.pixelSize: 31
            font.weight: Font.Light
        }

        Text {
            x: 81
            y: 44
            text: "Santo Domingo"
            color: "#f5f5f5"
            font.pixelSize: 13
        }
    }

    Bar.Top {
        id: topBar
        z: 20
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        windowWidth: window.width
        currentTime: window.currentTime
        activeSource: window.panelMode !== "" ? window.panelSource : ""
        onDesktopRequested: window.closePanel()
        onPanelRequested: (mode, anchorX, source) => window.togglePanel(mode, anchorX, source)
    }

    Panel.Root {
        z: 30
        anchors.top: parent.top
        anchors.topMargin: topBar.barHeight + 5
        x: Math.max(10, Math.min(window.width - width - 10, window.panelAnchorX - width / 2))
        mode: window.panelMode
        availableWidth: window.width
        availableHeight: window.height - topBar.barHeight
        onCloseRequested: window.closePanel()
        onModeRequested: mode => window.panelMode = mode

        Behavior on x {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }
    }

    Item {
        id: dock

        z: 15
        width: Math.min(window.width - 28, dockRow.width + 34)
        height: 76
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16

        MatteSurface {
            anchors.fill: parent
            cornerRadius: 29
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Row {
            id: dockRow

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 4
            spacing: window.dockSpacing
            scale: Math.min(1, (dock.width - 24) / width)

            Repeater {
                model: window.pinnedApps

                delegate: DockEntry {
                    required property var modelData

                    app: modelData
                    onActivated: window.activateDockApp(modelData)
                }
            }

            Rectangle {
                width: 1
                height: 33
                y: (dockRow.height - height) / 2
                color: "#75ffffff"
            }

            Repeater {
                model: window.recentApps

                delegate: DockEntry {
                    required property var modelData

                    app: modelData
                    onActivated: window.activateDockApp(modelData)
                }
            }
        }
    }

    component MatteSurface: Item {
        id: surface

        property real cornerRadius: 24

        Rectangle {
            x: -6
            y: 5
            width: surface.width + 12
            height: surface.height + 4
            radius: surface.cornerRadius + 6
            color: "#18000000"
        }

        Rectangle {
            x: -3
            y: 3
            width: surface.width + 6
            height: surface.height + 2
            radius: surface.cornerRadius + 3
            color: "#2a000000"
        }

        Rectangle {
            anchors.fill: parent
            radius: surface.cornerRadius
            gradient: Gradient {
                GradientStop { position: 0; color: "#e8383838" }
                GradientStop { position: 0.55; color: "#e82c2c2c" }
                GradientStop { position: 1; color: "#e8202020" }
            }
            border.width: 1
            border.color: "#526f6f6f"
        }
    }

    component DesktopShortcut: Item {
        id: shortcut

        property var app
        property bool selected: false
        signal menuRequested(real localX, real localY)

        width: 106
        height: 102
        z: window.desktopDragging && shortcut.selected ? 3 : 1
        scale: window.desktopDragging && shortcut.selected ? 1.04 : 1

        Behavior on scale {
            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
        }

        Behavior on x {
            enabled: !window.desktopDragging
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        Behavior on y {
            enabled: !window.desktopDragging
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: shortcut.selected ? "#70315f99"
                                     : shortcutMouse.containsMouse ? "#24ffffff" : "transparent"
            border.width: shortcut.selected ? 1 : 0
            border.color: "#c85f98d8"

            Behavior on color {
                ColorAnimation { duration: 140 }
            }
        }

        DockIcon {
            anchors.top: parent.top
            anchors.topMargin: 3
            anchors.horizontalCenter: parent.horizontalCenter
            width: 62
            height: 62
            kind: shortcut.app ? shortcut.app.icon : ""
        }

        Text {
            anchors.top: parent.top
            anchors.topMargin: 70
            anchors.left: parent.left
            anchors.right: parent.right
            text: shortcut.app ? shortcut.app.name : ""
            color: "#ffffff"
            style: Text.Outline
            styleColor: "#76352a24"
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        MouseArea {
            id: shortcutMouse

            property bool moved: false
            property real pressedX
            property real pressedY

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onPressed: mouse => {
                moved = false;
                pressedX = mouse.x;
                pressedY = mouse.y;

                if (mouse.button === Qt.RightButton) {
                    if (!shortcut.selected) {
                        window.selectOnlyDesktopShortcut(shortcut.app.id);
                    }

                    return;
                }

                if (mouse.modifiers & Qt.ControlModifier) {
                    window.toggleDesktopShortcut(shortcut.app.id);
                    return;
                }

                if (!shortcut.selected) {
                    window.selectOnlyDesktopShortcut(shortcut.app.id);
                }

                window.beginDesktopDrag(shortcut, mouse.x, mouse.y);
            }

            onPositionChanged: mouse => {
                if (!(pressedButtons & Qt.LeftButton) || (mouse.modifiers & Qt.ControlModifier)) {
                    return;
                }

                if (Math.abs(mouse.x - pressedX) > 3 || Math.abs(mouse.y - pressedY) > 3) {
                    moved = true;
                }

                if (moved) {
                    window.updateDesktopDrag(shortcut, mouse.x, mouse.y);
                }
            }

            onReleased: mouse => {
                if (mouse.button === Qt.LeftButton) {
                    window.endDesktopDrag();
                }
            }

            onCanceled: window.endDesktopDrag()

            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    shortcut.menuRequested(mouse.x, mouse.y);
                } else if (!moved && !(mouse.modifiers & Qt.ControlModifier)) {
                    window.selectOnlyDesktopShortcut(shortcut.app.id);
                }
            }

            onDoubleClicked: mouse => {
                if (mouse.button === Qt.LeftButton && !moved) {
                    shortcut.menuRequested(mouse.x, mouse.y);
                }
            }
        }
    }

    component NavigationGlyph: Canvas {
        id: glyph

        property string kind

        onKindChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.save();
            ctx.scale(width / 24, height / 24);
            ctx.strokeStyle = "#ffffff";
            ctx.fillStyle = "#ffffff";
            ctx.lineWidth = 1.8;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.beginPath();

            if (kind === "home") {
                ctx.moveTo(3, 11);
                ctx.lineTo(12, 4);
                ctx.lineTo(21, 11);
                ctx.moveTo(6, 10);
                ctx.lineTo(6, 20);
                ctx.lineTo(10, 20);
                ctx.lineTo(10, 15);
                ctx.lineTo(14, 15);
                ctx.lineTo(14, 20);
                ctx.lineTo(18, 20);
                ctx.lineTo(18, 10);
            } else if (kind === "folder") {
                ctx.moveTo(3, 7);
                ctx.lineTo(9, 7);
                ctx.lineTo(11, 9);
                ctx.lineTo(21, 9);
                ctx.lineTo(21, 19);
                ctx.lineTo(3, 19);
                ctx.closePath();
            } else if (kind === "apps") {
                for (let x = 6; x <= 18; x += 12) {
                    for (let y = 6; y <= 18; y += 12) {
                        ctx.moveTo(x + 2, y);
                        ctx.arc(x, y, 2, 0, Math.PI * 2);
                    }
                }
            } else if (kind === "chat") {
                ctx.moveTo(5, 5);
                ctx.lineTo(19, 5);
                ctx.quadraticCurveTo(21, 5, 21, 7);
                ctx.lineTo(21, 16);
                ctx.quadraticCurveTo(21, 18, 19, 18);
                ctx.lineTo(10, 18);
                ctx.lineTo(5, 21);
                ctx.lineTo(5, 18);
                ctx.quadraticCurveTo(3, 18, 3, 16);
                ctx.lineTo(3, 7);
                ctx.quadraticCurveTo(3, 5, 5, 5);
            } else if (kind === "notes") {
                ctx.moveTo(5, 3);
                ctx.lineTo(15, 3);
                ctx.lineTo(20, 8);
                ctx.lineTo(20, 21);
                ctx.lineTo(5, 21);
                ctx.closePath();
                ctx.moveTo(15, 3);
                ctx.lineTo(15, 8);
                ctx.lineTo(20, 8);
                ctx.moveTo(8, 12);
                ctx.lineTo(17, 12);
                ctx.moveTo(8, 16);
                ctx.lineTo(17, 16);
            }

            ctx.stroke();
            ctx.restore();
        }
    }

    component DockEntry: Item {
        id: entry

        property var app
        signal activated()

        width: window.dockTileSize
        height: window.dockTileSize + 12

        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: window.dockTileSize
            height: width
            radius: 13
            color: entryMouse.containsMouse ? "#26ffffff" : "transparent"
            border.width: entryMouse.containsMouse ? 1 : 0
            border.color: "#58ffffff"

            Behavior on color {
                ColorAnimation { duration: 140 }
            }
        }

        DockIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            y: (window.dockTileSize - height) / 2
            width: window.dockIconSize
            height: width
            kind: entry.app ? entry.app.icon : ""
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 3
            width: 3
            height: 3
            radius: 2
            color: "#54b9ff"
        }

        MouseArea {
            id: entryMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: entry.activated()
        }

        ToolTip.visible: entryMouse.containsMouse
        ToolTip.delay: 500
        ToolTip.text: entry.app ? entry.app.name : ""
    }

    component DockIcon: Item {
        id: icon

        property string kind

        Rectangle {
            visible: icon.kind === "notes"
            anchors.centerIn: parent
            width: icon.width * 0.70
            height: icon.height * 0.84
            radius: 4
            color: "#f7f6f1"
            border.color: "#c9c8c4"

            Column {
                x: parent.width * 0.17
                y: parent.height * 0.27
                spacing: parent.height * 0.12

                Repeater {
                    model: 3
                    delegate: Rectangle {
                        width: icon.width * (index === 2 ? 0.28 : 0.39)
                        height: 1
                        color: "#8b9398"
                    }
                }
            }
        }

        Rectangle {
            visible: icon.kind === "image"
            anchors.centerIn: parent
            width: icon.width * 0.82
            height: icon.height * 0.68
            radius: 4
            color: "#f6f4ef"
            border.width: 2
            border.color: "#f6f4ef"
            clip: true

            Image {
                anchors.fill: parent
                anchors.margins: 2
                source: "assets/wallpaper.jpeg"
                sourceSize: Qt.size(64, 48)
                fillMode: Image.PreserveAspectCrop
            }
        }

        Rectangle {
            visible: icon.kind === "chat"
            anchors.centerIn: parent
            width: icon.width * 0.78
            height: width
            radius: 9
            color: "#f8f8f5"

            Rectangle {
                x: parent.width * 0.19
                y: parent.height * 0.19
                width: parent.width * 0.35
                height: parent.height * 0.35
                radius: 4
                color: "#38bc82"
            }

            Rectangle {
                x: parent.width * 0.48
                y: parent.height * 0.19
                width: parent.width * 0.35
                height: parent.height * 0.35
                radius: 4
                color: "#e95372"
            }

            Rectangle {
                x: parent.width * 0.19
                y: parent.height * 0.48
                width: parent.width * 0.35
                height: parent.height * 0.35
                radius: 4
                color: "#53a4e6"
            }

            Rectangle {
                x: parent.width * 0.48
                y: parent.height * 0.48
                width: parent.width * 0.35
                height: parent.height * 0.35
                radius: 4
                color: "#f0bc40"
            }
        }

        Rectangle {
            visible: icon.kind === "folder"
            x: icon.width * 0.12
            y: icon.height * 0.22
            width: icon.width * 0.48
            height: icon.height * 0.19
            radius: 5
            color: "#59caff"
        }

        Rectangle {
            visible: icon.kind === "folder"
            anchors.horizontalCenter: parent.horizontalCenter
            y: icon.height * 0.32
            width: icon.width * 0.78
            height: icon.height * 0.52
            radius: 6
            gradient: Gradient {
                GradientStop { position: 0; color: "#22baff" }
                GradientStop { position: 1; color: "#087be5" }
            }
        }

        Rectangle {
            visible: icon.kind === "browser"
            anchors.centerIn: parent
            width: icon.width * 0.82
            height: width
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0; color: "#12bfae" }
                GradientStop { position: 0.48; color: "#167dd1" }
                GradientStop { position: 1; color: "#123dc0" }
            }

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -2
                text: "e"
                color: "#e6ffffff"
                font.pixelSize: parent.width * 0.82
                font.weight: Font.Bold
            }
        }

        Rectangle {
            visible: icon.kind === "code"
            anchors.centerIn: parent
            width: icon.width * 0.78
            height: width
            radius: 10
            color: "#252c35"
        }

        Canvas {
            visible: icon.kind === "code"
            anchors.centerIn: parent
            width: icon.width * 0.78
            height: width
            onPaint: {
                const ctx = getContext("2d");
                const scale = width / 56;

                ctx.clearRect(0, 0, width, height);
                ctx.save();
                ctx.scale(scale, scale);
                ctx.fillStyle = "#07549b";
                ctx.beginPath();
                ctx.moveTo(36, 6);
                ctx.lineTo(48, 11);
                ctx.lineTo(48, 45);
                ctx.lineTo(36, 50);
                ctx.lineTo(17, 34);
                ctx.lineTo(8, 41);
                ctx.lineTo(3, 36);
                ctx.lineTo(13, 28);
                ctx.lineTo(3, 20);
                ctx.lineTo(8, 15);
                ctx.lineTo(17, 22);
                ctx.closePath();
                ctx.fill();
                ctx.fillStyle = "#24a5f2";
                ctx.beginPath();
                ctx.moveTo(36, 14);
                ctx.lineTo(36, 42);
                ctx.lineTo(20, 28);
                ctx.closePath();
                ctx.fill();
                ctx.restore();
            }
        }

        Item {
            visible: icon.kind === "design"
            anchors.centerIn: parent
            width: icon.width * 0.56
            height: icon.height * 0.78

            Rectangle { x: 0; y: 0; width: parent.width / 2; height: parent.height / 3; radius: height / 2; color: "#f24e1e" }
            Rectangle { x: parent.width / 2; y: 0; width: parent.width / 2; height: parent.height / 3; radius: height / 2; color: "#ff7262" }
            Rectangle { x: 0; y: parent.height / 3; width: parent.width / 2; height: parent.height / 3; radius: height / 2; color: "#a259ff" }
            Rectangle { x: parent.width / 2; y: parent.height / 3; width: parent.width / 2; height: parent.height / 3; radius: height / 2; color: "#1abcfe" }
            Rectangle { x: 0; y: parent.height * 2 / 3; width: parent.width / 2; height: parent.height / 3; radius: height / 2; color: "#0acf83" }
        }

        Rectangle {
            visible: icon.kind === "terminal"
            anchors.centerIn: parent
            width: icon.width * 0.82
            height: width
            radius: 9
            color: "#202730"

            Text {
                anchors.centerIn: parent
                text: ">_"
                color: "#f7f7f7"
                font.family: "monospace"
                font.pixelSize: parent.width * 0.46
                font.weight: Font.Bold
            }
        }

        Rectangle {
            visible: icon.kind === "music"
            anchors.centerIn: parent
            width: icon.width * 0.82
            height: width
            radius: width / 2
            color: "#16c864"

            Canvas {
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    const scale = width / 56;

                    ctx.clearRect(0, 0, width, height);
                    ctx.save();
                    ctx.scale(scale, scale);
                    ctx.strokeStyle = "#173c31";
                    ctx.lineCap = "round";

                    for (let line = 0; line < 3; ++line) {
                        ctx.lineWidth = 4 - line * 0.6;
                        ctx.beginPath();
                        ctx.moveTo(12 + line * 2, 20 + line * 8);
                        ctx.quadraticCurveTo(28, 15 + line * 8, 44 - line * 2, 23 + line * 8);
                        ctx.stroke();
                    }

                    ctx.restore();
                }
            }
        }

        Rectangle {
            visible: icon.kind === "photos"
            anchors.centerIn: parent
            width: icon.width * 0.8
            height: width
            radius: 11
            color: "#fffdfb"

            Repeater {
                model: ["#ed484e", "#f49b3f", "#f5d84e", "#63ba57", "#4ea5dc", "#a270c5"]

                delegate: Rectangle {
                    required property int index
                    required property string modelData

                    x: parent.width / 2 + Math.sin(index * Math.PI / 3) * parent.width * 0.19 - width / 2
                    y: parent.height / 2 - Math.cos(index * Math.PI / 3) * parent.height * 0.19 - height / 2
                    width: parent.width * 0.26
                    height: parent.height * 0.39
                    radius: width / 2
                    rotation: index * 60
                    color: modelData
                    opacity: 0.86
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.18
                height: width
                radius: width / 2
                color: "#fff9ed"
            }
        }

        Item {
            visible: icon.kind === "trash"
            anchors.centerIn: parent
            width: icon.width * 0.70
            height: icon.height * 0.92

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: parent.width * 0.79
                height: parent.height * 0.82
                radius: 5
                gradient: Gradient {
                    GradientStop { position: 0; color: "#f6f7f8" }
                    GradientStop { position: 1; color: "#9ca7ad" }
                }
                border.color: "#a6b0b5"
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: parent.width
                height: parent.height * 0.12
                radius: 3
                color: "#e1e7e9"
                border.color: "#a6b0b5"
            }
        }
    }
}
