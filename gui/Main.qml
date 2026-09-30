import QtQuick
import QtQuick.Controls.Basic

import "qml/components" as Components
import "qml/logic/theme.js" as Theme

Components.Application {
    id: main

    function requestedDockPosition() {
        const prefix = "--dock-position=";
        const supportedPositions = [
            "top-left", "top-center", "top-right",
            "bottom-left", "bottom-center", "bottom-right",
            "left-top", "left-center", "left-bottom",
            "right-top", "right-center", "right-bottom"
        ];

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

    // Available positions:
    //
    // "top-left", "top-center", "top-right"
    // "bottom-left", "bottom-center", "bottom-right"
    // "left-top", "left-center", "left-bottom"
    // "right-top", "right-center", "right-bottom"
    property string dockPosition: requestedDockPosition()

    readonly property bool dockOnLeft: dockPosition.indexOf("left-") === 0
                                       || dockPosition === "top-left"
                                       || dockPosition === "bottom-left"
    readonly property bool dockOnRight: dockPosition.indexOf("right-") === 0
                                        || dockPosition === "top-right"
                                        || dockPosition === "bottom-right"
    readonly property bool dockOnTop: dockPosition.indexOf("top-") === 0
                                      || dockPosition === "left-top"
                                      || dockPosition === "right-top"
    readonly property bool dockOnBottom: dockPosition.indexOf("bottom-") === 0
                                         || dockPosition === "left-bottom"
                                         || dockPosition === "right-bottom"
    readonly property bool dockHorizontalCenter: dockPosition === "top-center"
                                                  || dockPosition === "bottom-center"
    readonly property bool dockVerticalCenter: dockPosition === "left-center"
                                                || dockPosition === "right-center"
    readonly property bool dockVertical: dockPosition.indexOf("left-") === 0
                                         || dockPosition.indexOf("right-") === 0

    desktopShortcuts: desktopShortcutsArea
    desktopShortcutRepeater: desktopShortcutRepeaterItem
    desktopContextMenu: desktopMenu
    sideBar: sideBarItem
    topBar: topBarItem

    // -------------------------------------------------------------------------
    // Wallpaper
    // -------------------------------------------------------------------------

    Image {
        id: wallpaper

        anchors.fill: parent

        source: Backend.wallpaper
        fillMode: Image.PreserveAspectCrop

        smooth: true
        mipmap: true
    }

    // -------------------------------------------------------------------------
    // Interactive desktop grid
    // -------------------------------------------------------------------------

    Item {
        id: desktopShortcutsArea

        readonly property real cellWidth: 106
        readonly property real cellHeight: 102

        z: 10

        anchors {
            top: topBarItem.bottom
            bottom: main.contentItem.bottom
            left: main.contentItem.left
            right: main.contentItem.right
            bottomMargin: 100
            leftMargin: sideBarItem.y < topBarItem.height + desktopShortcutsArea.cellHeight
                        ? sideBarItem.x + sideBarItem.width + 12
                        : 0
        }

        MouseArea {
            id: desktopSelectionArea

            property real originX
            property real originY
            property var baseSelection: []

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: selectionRectangle.visible ? Qt.CrossCursor : Qt.ArrowCursor

            onPressed: mouse => {
                if (mouse.button === Qt.RightButton) {
                    main.selectedDesktopIds = [];
                    main.closePanel();
                    main.openDesktopShortcutMenu(desktopShortcutsArea, mouse.x, mouse.y, "Escritorio");
                    return;
                }

                originX = mouse.x;
                originY = mouse.y;
                baseSelection = (mouse.modifiers & Qt.ControlModifier) ? main.selectedDesktopIds.slice() : [];

                selectionRectangle.x = originX;
                selectionRectangle.y = originY;
                selectionRectangle.width = 0;
                selectionRectangle.height = 0;
                selectionRectangle.visible = true;

                main.selectedDesktopIds = baseSelection.slice();
                main.closePanel();
                desktopMenu.close();
            }

            onPositionChanged: mouse => {
                if (!(pressedButtons & Qt.LeftButton)) {
                    return;
                }

                selectionRectangle.x = Math.min(originX, mouse.x);
                selectionRectangle.y = Math.min(originY, mouse.y);
                selectionRectangle.width = Math.abs(mouse.x - originX);
                selectionRectangle.height = Math.abs(mouse.y - originY);

                main.selectDesktopShortcutsInRectangle(selectionRectangle, baseSelection);
            }

            onReleased: mouse => {
                if (mouse.button === Qt.LeftButton) {
                    selectionRectangle.visible = false;
                }
            }

            onCanceled: selectionRectangle.visible = false
        }

        Repeater {
            id: desktopShortcutRepeaterItem

            model: [
                { id: "projects", name: "Proyectos", icon: "folder", mode: "files", column: 0, row: 0 },
                { id: "notes", name: "Notas", icon: "notes", mode: "about", column: 1, row: 0 },
                { id: "wallpaper", name: "Wallpaper.jpg", icon: "image", mode: "about", column: 2, row: 0 },
                { id: "designs", name: "Diseños", icon: "folder", mode: "files", column: 3, row: 0 }
            ]

            delegate: DesktopShortcut {
                id: desktopShortcut

                required property var modelData

                x: modelData.column * desktopShortcutsArea.cellWidth
                y: modelData.row * desktopShortcutsArea.cellHeight
                app: modelData
                selected: main.isDesktopShortcutSelected(modelData.id)

                onMenuRequested: (localX, localY) => {
                    main.closePanel();
                    main.openDesktopShortcutMenu(desktopShortcut, localX, localY, desktopShortcut.app.name);
                }
            }
        }

        Rectangle {
            id: selectionRectangle

            z: 20
            visible: false
            color: Theme.selectionArea
            border.width: 1
            border.color: Theme.selectionAreaBorder
        }
    }

    Popup {
        id: desktopMenu

        property string shortcutName: "Escritorio"

        z: 100
        width: 210
        height: 82
        padding: 0
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Components.Glass {
            backdrop: wallpaper
            cornerRadius: 13
        }

        contentItem: Column {
            leftPadding: 14
            rightPadding: 14
            topPadding: 12
            bottomPadding: 10
            spacing: 5

            Label {
                width: desktopMenu.width - 28
                text: desktopMenu.shortcutName
                color: Theme.white
                font.pixelSize: 13
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Label {
                width: desktopMenu.width - 28
                text: "Sin acciones disponibles"
                color: Theme.contextMenuTextMuted
                font.pixelSize: 11
            }
        }
    }

    // -------------------------------------------------------------------------
    // Top bar
    // -------------------------------------------------------------------------

    Components.Logo {
        id: topBarItem
        backdrop: wallpaper
        windowWidth: main.width
        currentTime: main.currentTime
        activeSource: main.panelMode !== "" ? main.panelSource : ""

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }

        onDesktopRequested: main.closePanel()
        onPanelRequested: (mode, anchorX, source) => main.togglePanel(mode, anchorX, source)
    }

    // -------------------------------------------------------------------------
    // Fixed navigation dock
    // -------------------------------------------------------------------------

    Item {
        id: sideBarItem

        z: 16
        x: 9
        width: 76
        height: Math.min(530, main.height - 100)

        anchors.verticalCenter: main.contentItem.verticalCenter

        Components.Glass {
            anchors.fill: parent
            backdrop: wallpaper
            cornerRadius: 38
        }

        Column {
            id: navigation

            anchors.centerIn: parent
            spacing: Math.max(4, Math.min(9, main.height / 100))

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
                                                     ? main.panelMode === "" && !main.filesQuickWindowVisible
                                                     : modelData.id === "files"
                                                       ? main.filesQuickWindowVisible
                                                       : main.panelSource === "nav-" + modelData.id

                    width: 60
                    height: Math.min(48, (sideBarItem.height - 24 - navigation.spacing * 8) / 9)

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(47, parent.height)
                        height: width
                        radius: width / 2
                        color: Theme.overlayHover
                        opacity: navigationMouse.containsMouse && !navigationEntry.selected ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 140
                            }
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(47, parent.height)
                        height: width
                        radius: width / 2
                        visible: navigationEntry.selected
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: Theme.navigationSelectedTop
                            }
                            GradientStop {
                                position: 1
                                color: Theme.navigationSelectedBottom
                            }
                        }
                        border.width: 1
                        border.color: Theme.navigationSelectedBorder
                    }

                    NavigationGlyph {
                        anchors.centerIn: parent
                        width: Math.min(26, navigationEntry.height * 0.58)
                        height: width
                        kind: navigationEntry.modelData.icon
                        visible: kind === "home" || kind === "folder" || kind === "apps" || kind === "chat" || kind === "notes"
                    }

                    Components.Icon {
                        anchors.centerIn: parent
                        width: Math.min(26, navigationEntry.height * 0.58)
                        height: width
                        visible: navigationEntry.modelData.icon === "settings"
                                 || navigationEntry.modelData.icon === "moon"
                                 || navigationEntry.modelData.icon === "brightness"
                                 || navigationEntry.modelData.icon === "power"
                        source: visible ? "assets/icons/" + navigationEntry.modelData.icon + ".svg" : ""
                        tint: Theme.white
                    }

                    MouseArea {
                        id: navigationMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (navigationEntry.modelData.id === "home") {
                                main.closePanel();
                                return;
                            }

                            if (navigationEntry.modelData.id === "files") {
                                main.openFilesQuickWindow();
                                return;
                            }

                            main.togglePanel(navigationEntry.modelData.mode,
                                             sideBarItem.x + sideBarItem.width / 2,
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

    // -------------------------------------------------------------------------
    // Fixed weather widget
    // -------------------------------------------------------------------------

    Item {
        id: weatherCard

        z: 12
        width: 190
        height: 70

        anchors.left: main.contentItem.left
        anchors.leftMargin: 16
        anchors.bottom: main.contentItem.bottom
        anchors.bottomMargin: main.width < 900 ? 105 : 18

        Components.Glass {
            anchors.fill: parent
            backdrop: wallpaper
            cornerRadius: 35
        }

        Rectangle {
            x: 27
            y: 16
            width: 25
            height: 25
            radius: 13
            color: Theme.weatherSun
        }

        Rectangle {
            x: 20
            y: 35
            width: 42
            height: 17
            radius: 9
            color: Theme.weatherCloud
        }

        Rectangle {
            x: 27
            y: 28
            width: 24
            height: 20
            radius: 10
            color: Theme.weatherCloud
        }

        Text {
            x: 80
            y: 9
            text: "28°"
            color: Theme.white
            font.pixelSize: 31
            font.weight: Font.Light
        }

        Text {
            x: 81
            y: 44
            text: "Santo Domingo"
            color: Theme.weatherPlace
            font.pixelSize: 13
        }
    }

    // -------------------------------------------------------------------------
    // Main content area
    //
    // Used as reference for right-center positioning.
    // -------------------------------------------------------------------------

    Item {
        id: contentArea

        anchors {
            top: topBarItem.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
    }

    Loader {
        id: panelLoader

        z: 30
        active: main.panelMode !== ""
        source: "qml/components/Root.qml"

        anchors.top: main.contentItem.top
        anchors.topMargin: topBarItem.barHeight + 5
        x: Math.max(10, Math.min(main.width - width - 10, main.panelAnchorX - width / 2))

        onLoaded: {
            item.backdrop = wallpaper;
            item.mode = Qt.binding(() => main.panelMode);
            item.availableWidth = Qt.binding(() => main.width);
            item.availableHeight = Qt.binding(() => main.height - topBarItem.barHeight);
            item.closeRequested.connect(main.closePanel);
            item.modeRequested.connect(mode => main.panelMode = mode);
        }

        Behavior on x {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }
    }

    // -------------------------------------------------------------------------
    // Main dock
    //
    // Can move between:
    //
    // The first word selects the edge. The second word selects alignment on
    // that edge. Side positions automatically switch the dock to a column.
    // -------------------------------------------------------------------------

    Components.Dock {
        id: dock
        backdrop: wallpaper
        shell: main
        vertical: main.dockVertical
        maximumLength: vertical ? contentArea.height - 32 : main.width - 32

        anchors.left: main.dockOnLeft ? main.contentItem.left : undefined
        anchors.right: main.dockOnRight ? main.contentItem.right : undefined
        anchors.horizontalCenter: main.dockHorizontalCenter ? main.contentItem.horizontalCenter : undefined
        anchors.top: main.dockOnTop ? contentArea.top : undefined
        anchors.bottom: main.dockOnBottom ? main.contentItem.bottom : undefined
        anchors.verticalCenter: main.dockVerticalCenter ? contentArea.verticalCenter : undefined

        anchors.leftMargin: main.dockPosition.indexOf("left-") === 0
                            ? sideBarItem.x + sideBarItem.width + 12
                            : main.dockPosition === "bottom-left"
                              ? weatherCard.x + weatherCard.width + 12
                              : main.dockOnLeft ? 16 : 0
        anchors.rightMargin: main.dockOnRight ? 16 : 0
        anchors.topMargin: main.dockOnTop ? 16 : 0
        anchors.bottomMargin: main.dockOnBottom ? 16 : 0
    }

    component DesktopShortcut: Item {
        id: shortcut

        property var app
        property bool selected: false

        signal menuRequested(real localX, real localY)

        width: desktopShortcutsArea.cellWidth
        height: desktopShortcutsArea.cellHeight
        z: main.desktopDragging && shortcut.selected ? 3 : 1
        scale: main.desktopDragging && shortcut.selected ? 1.04 : 1

        Behavior on scale {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutCubic
            }
        }

        Behavior on x {
            enabled: !main.desktopDragging
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Behavior on y {
            enabled: !main.desktopDragging
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: shortcut.selected
                   ? Theme.shortcutSelected
                   : shortcutMouse.containsMouse ? Theme.shortcutHover : "transparent"
            border.width: shortcut.selected ? 1 : 0
            border.color: Theme.shortcutSelectedBorder

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }
        }

        DesktopIcon {
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
            color: Theme.white
            style: Text.Outline
            styleColor: Theme.shortcutShadow
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
                        main.selectOnlyDesktopShortcut(shortcut.app.id);
                    }

                    return;
                }

                if (mouse.modifiers & Qt.ControlModifier) {
                    main.toggleDesktopShortcut(shortcut.app.id);
                    return;
                }

                if (!shortcut.selected) {
                    main.selectOnlyDesktopShortcut(shortcut.app.id);
                }

                main.beginDesktopDrag(shortcut, mouse.x, mouse.y);
            }

            onPositionChanged: mouse => {
                if (!(pressedButtons & Qt.LeftButton) || (mouse.modifiers & Qt.ControlModifier)) {
                    return;
                }

                if (Math.abs(mouse.x - pressedX) > 3 || Math.abs(mouse.y - pressedY) > 3) {
                    moved = true;
                }

                if (moved) {
                    main.updateDesktopDrag(shortcut, mouse.x, mouse.y);
                }
            }

            onReleased: mouse => {
                if (mouse.button === Qt.LeftButton) {
                    main.endDesktopDrag();
                }
            }

            onCanceled: main.endDesktopDrag()

            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    shortcut.menuRequested(mouse.x, mouse.y);
                } else if (!moved && !(mouse.modifiers & Qt.ControlModifier)) {
                    main.selectOnlyDesktopShortcut(shortcut.app.id);
                }
            }

            onDoubleClicked: mouse => {
                if (mouse.button === Qt.LeftButton && !moved) {
                    shortcut.menuRequested(mouse.x, mouse.y);
                }
            }
        }
    }

    component DesktopIcon: Item {
        id: desktopIcon

        property string kind

        Rectangle {
            visible: desktopIcon.kind === "notes"
            anchors.centerIn: parent
            width: desktopIcon.width * 0.70
            height: desktopIcon.height * 0.84
            radius: 4
            color: Theme.notesBackground
            border.color: Theme.notesBorder

            Column {
                x: parent.width * 0.17
                y: parent.height * 0.27
                spacing: parent.height * 0.12

                Repeater {
                    model: 3

                    delegate: Rectangle {
                        required property int index

                        width: desktopIcon.width * (index === 2 ? 0.28 : 0.39)
                        height: 1
                        color: Theme.notesLines
                    }
                }
            }
        }

        Rectangle {
            visible: desktopIcon.kind === "image"
            anchors.centerIn: parent
            width: desktopIcon.width * 0.82
            height: desktopIcon.height * 0.68
            radius: 4
            color: Theme.imageIconFrame
            border.width: 2
            border.color: Theme.imageIconFrame
            clip: true

            Image {
                anchors.fill: parent
                anchors.margins: 2
                source: wallpaper.source
                sourceSize: Qt.size(128, 96)
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
            }
        }

        Rectangle {
            visible: desktopIcon.kind === "folder"
            x: desktopIcon.width * 0.12
            y: desktopIcon.height * 0.22
            width: desktopIcon.width * 0.48
            height: desktopIcon.height * 0.19
            radius: 5
            color: Theme.folderTab
        }

        Rectangle {
            visible: desktopIcon.kind === "folder"
            anchors.horizontalCenter: parent.horizontalCenter
            y: desktopIcon.height * 0.32
            width: desktopIcon.width * 0.78
            height: desktopIcon.height * 0.52
            radius: 6
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.folderTop
                }
                GradientStop {
                    position: 1
                    color: Theme.folderBottom
                }
            }
        }
    }

    component NavigationGlyph: Canvas {
        id: glyph

        property string kind

        onKindChanged: requestPaint()

        onPaint: {
            const context = getContext("2d");

            context.clearRect(0, 0, width, height);
            context.save();
            context.scale(width / 24, height / 24);
            context.strokeStyle = Theme.white;
            context.fillStyle = Theme.white;
            context.lineWidth = 1.8;
            context.lineCap = "round";
            context.lineJoin = "round";
            context.beginPath();

            if (kind === "home") {
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
            } else if (kind === "folder") {
                context.moveTo(3, 7);
                context.lineTo(9, 7);
                context.lineTo(11, 9);
                context.lineTo(21, 9);
                context.lineTo(21, 19);
                context.lineTo(3, 19);
                context.closePath();
            } else if (kind === "apps") {
                for (let x = 6; x <= 18; x += 12) {
                    for (let y = 6; y <= 18; y += 12) {
                        context.moveTo(x + 2, y);
                        context.arc(x, y, 2, 0, Math.PI * 2);
                    }
                }
            } else if (kind === "chat") {
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
            } else if (kind === "notes") {
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
}
