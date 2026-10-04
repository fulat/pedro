import QtQuick
import QtQuick.Controls.Basic

import "qml/components" as Components
import "qml/components/desktop" as Desktop
import "qml/components/navigation" as Navigation
import "qml/controllers" as Controllers
import "qml/scripts/theme.js" as Theme
import "qml/scripts/mocks.js" as Mocks

Components.Application {
    id: main
    readonly property Item entryBackdrop: wallpaper

    // Available positions:
    //
    // "top-left", "top-center", "top-right"
    // "bottom-left", "bottom-center", "bottom-right"
    // "left-top", "left-center", "left-bottom"
    // "right-top", "right-center", "right-bottom"
    readonly property string dockPosition: mainController.dockPosition
    readonly property bool dockOnLeft: mainController.dockOnLeft
    readonly property bool dockOnRight: mainController.dockOnRight
    readonly property bool dockOnTop: mainController.dockOnTop
    readonly property bool dockOnBottom: mainController.dockOnBottom
    readonly property bool dockHorizontalCenter: mainController.dockHorizontalCenter
    readonly property bool dockVerticalCenter: mainController.dockVerticalCenter
    readonly property bool dockVertical: mainController.dockVertical

    // Supplies shell configuration without mixing JavaScript functions into the view.
    Controllers.Main {
        id: mainController
        view: main
    }

    desktopShortcuts: desktopShortcutsArea
    desktopShortcutRepeater: desktopShortcutRepeaterItem
    desktopContextMenu: wallpaperMenuLoader.item
    sideBar: sideBarItem
    topBar: topBarItem
    desktopObstacles: [topBarItem.logoControl, topBarItem.statusControl, topBarItem.notificationControl, sideBarItem, weatherCard, dock]

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

        readonly property real itemWidth: 106
        readonly property real itemHeight: 102
        readonly property real cellGap: 8
        readonly property real cellWidth: itemWidth + cellGap
        readonly property real cellHeight: itemHeight + cellGap

        z: 10

        anchors.fill: parent

        MouseArea {
            id: desktopSelectionArea

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: selectionRectangle.visible ? Qt.CrossCursor : Qt.ArrowCursor

            onPressed: mouse => mainController.desktopPressed(mouse, desktopShortcutsArea, selectionRectangle, main.desktopContextMenu)
            onPositionChanged: mouse => mainController.desktopPositionChanged(mouse, pressedButtons, selectionRectangle)
            onReleased: mouse => mainController.desktopReleased(mouse, selectionRectangle)

            onCanceled: selectionRectangle.visible = false
        }

        Repeater {
            id: desktopShortcutRepeaterItem
            model: Backend.desktopModel

            delegate: Desktop.Shortcut {
                id: desktopShortcut

                required property var entry
                required property int index

                property point initialPosition: Qt.point(0, 0)
                x: initialPosition.x
                y: initialPosition.y
                shell: main
                controller: mainController
                cellWidth: desktopShortcutsArea.itemWidth
                cellHeight: desktopShortcutsArea.itemHeight
                app: entry
                selected: main.controller.isDesktopShortcutSelected(entry.id)

                Component.onCompleted: initialPosition = main.controller.desktopRestoredPosition(entry, index)

                onMenuRequested: (localX, localY) => mainController.shortcutMenuRequested(desktopShortcut, localX, localY)
            }
        }

        Repeater {
            model: Backend.desktopModel.organization === "stack" ? Backend.desktopModel.groups : []
            delegate: Desktop.Shortcut {
                required property var modelData
                shell: main
                controller: mainController
                cellWidth: desktopShortcutsArea.itemWidth
                cellHeight: desktopShortcutsArea.itemHeight
                stackIndicator: true
                app: main.controller.stackIndicatorEntry(modelData)
                visible: modelData.members.length > 1 && stack.expanded
                readonly property point indicatorPosition: main.controller.desktopStackPosition(stack.slot - 1)
                x: indicatorPosition.x
                y: indicatorPosition.y
            }
        }

        Item {
            id: stackDragPreview
            z: 100
            width: desktopShortcutsArea.itemWidth
            height: desktopShortcutsArea.itemHeight
            x: main.controller.stackDragPoint.x - width / 2
            y: main.controller.stackDragPoint.y - 28
            opacity: main.controller.stackDragActive ? 0.9 : 0
            visible: opacity > 0
            scale: main.controller.stackDragActive ? 1.08 : 1

            Behavior on opacity { NumberAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 140 } }
            Behavior on x {
                enabled: !main.controller.stackDragActive
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                enabled: !main.controller.stackDragActive
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }

            Desktop.Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 57
                height: 57
                kind: main.controller.stackDragEntry ? main.controller.stackDragEntry.icon : ""
                imageUrl: main.controller.stackDragEntry ? main.controller.stackDragEntry.url : ""
            }
            Text {
                anchors.top: parent.top
                anchors.topMargin: 65
                width: parent.width
                text: main.controller.stackDragEntry ? main.controller.stackDragEntry.name : ""
                color: Theme.white
                style: Text.Outline
                styleColor: Theme.shortcutShadow
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
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

    Loader {
        id: wallpaperMenuLoader
        source: "qml/components/wallpaper/menu.qml"

        onLoaded: {
            item.parent = main.contentItem;
            item.backdrop = wallpaper;
            item.organization = Qt.binding(() => Backend.desktopModel.organization);
            item.keepAligned = Qt.binding(() => Backend.desktopModel.keepAligned);
            item.canPaste = Qt.binding(() => Backend.clipboard.canPaste);
            item.sortKey = Qt.binding(() => Backend.desktopModel.sortKey);
            item.actionRequested.connect(action => main.controller.wallpaperAction(action));
        }
    }

    Connections {
        target: Backend.desktopModel
        function onEntryCreated(id) { main.controller.startDesktopRename(id); }
        function onEntryRenamed(id) {
            main.controller.desktopOperationError = "";
            main.controller.renamingDesktopId = "";
            main.controller.renamingDesktopBusy = false;
            main.controller.selectOnlyDesktopShortcut(id);
        }
        function onOperationFailed(message) {
            main.controller.renamingDesktopBusy = false;
            main.controller.desktopOperationError = message;
        }
        function onSortRestored() { Qt.callLater(main.controller.arrangeDesktop); }
        function onSortRequested() { Qt.callLater(main.controller.sortDesktop); }
        function onOrganizationChanged() { Qt.callLater(main.controller.arrangeDesktop); }
        function onGroupsChanged() {
            if (Backend.desktopModel.organization === "stack") {
                Qt.callLater(main.controller.arrangeDesktop);
            }
        }
    }

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 76
        z: 200
        visible: main.controller.desktopOperationError.length > 0
        text: qsTranslate("Pedro", "desktop.operation.error").replace("{message}", main.controller.desktopOperationError)
        color: Theme.white
        padding: 12
        width: Math.min(implicitWidth, main.width - 24)
        wrapMode: Text.Wrap
        background: Components.Liquid {
            backdrop: wallpaper
            frosted: true
        }
        TapHandler { onTapped: main.controller.desktopOperationError = "" }
    }

    // -------------------------------------------------------------------------
    // Top bar
    // -------------------------------------------------------------------------
    Components.Logo {
        id: topBarItem
        z: 20
        backdrop: wallpaper
        windowWidth: main.width
        currentTime: main.currentTime
        activeSource: main.panelMode !== "" ? main.panelSource : ""

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }

        onDesktopRequested: main.controller.closePanel()
        onPanelRequested: (mode, anchorX, source) => main.controller.togglePanel(mode, anchorX, source)
    }

    // -------------------------------------------------------------------------
    // Fixed navigation dock
    // -------------------------------------------------------------------------
    Item {
        id: sideBarItem

        z: 16
        x: 9
        width: 44
        // Size to the navigation entries; only compact further when space is limited.
        height: Math.min(navigationRepeater.count * 30 + Math.max(0, navigationRepeater.count - 1) * navigation.spacing + 20,
                         Math.max(0, weatherCard.y - topBarItem.height - 24))

        y: Math.max(topBarItem.height + 12, Math.min((main.height - height) / 2, weatherCard.y - height - 12))

        Components.Liquid {
            anchors.fill: parent
            backdrop: wallpaper
            cornerRadius: 22
        }

        Column {
            id: navigation

            anchors.centerIn: parent
            spacing: 3

            Repeater {
                id: navigationRepeater

                model: { Backend.language; return Mocks.osNavigationMenuItems(); }

                delegate: Item {
                    id: navigationEntry

                    required property var modelData

                    readonly property bool selected: modelData.id === "home" ? main.panelMode === "" && !main.filesQuickWindowVisible : modelData.id === "files" ? main.filesQuickWindowVisible : main.panelSource === "nav-" + modelData.id

                    width: 36
                    height: Math.max(0, Math.min(30, (sideBarItem.height - 20 - navigation.spacing * Math.max(0, navigationRepeater.count - 1)) / Math.max(1, navigationRepeater.count)))

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(30, parent.height)
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
                        width: Math.min(30, parent.height)
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

                    Navigation.Glyph {
                        anchors.centerIn: parent
                        width: Math.min(17, navigationEntry.height * 0.58)
                        height: width
                        kind: navigationEntry.modelData.icon
                        controller: mainController
                        visible: kind === "home" || kind === "folder" || kind === "apps" || kind === "chat" || kind === "notes"
                    }

                    Components.Icon {
                        anchors.centerIn: parent
                        width: Math.min(17, navigationEntry.height * 0.58)
                        height: width
                        visible: navigationEntry.modelData.icon === "settings" || navigationEntry.modelData.icon === "moon" || navigationEntry.modelData.icon === "brightness" || navigationEntry.modelData.icon === "power"
                        source: visible ? "assets/icons/" + navigationEntry.modelData.icon + ".svg" : ""
                        tint: Theme.white
                    }

                    MouseArea {
                        id: navigationMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: mainController.navigationActivated(navigationEntry, sideBarItem)
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
        width: 164
        height: 56

        anchors.left: main.contentItem.left
        anchors.leftMargin: 16
        anchors.bottom: main.contentItem.bottom
        anchors.bottomMargin: main.width < 900 ? 80 : 16

        Components.Liquid {
            anchors.fill: parent
            backdrop: wallpaper
            cornerRadius: 28
        }

        Rectangle {
            x: 22
            y: 12
            width: 20
            height: 20
            radius: 10
            color: Theme.weatherSun
        }

        Rectangle {
            x: 16
            y: 28
            width: 34
            height: 14
            radius: 7
            color: Theme.weatherCloud
        }

        Rectangle {
            x: 22
            y: 22
            width: 20
            height: 17
            radius: 9
            color: Theme.weatherCloud
        }

        Text {
            x: 62
            y: 5
            text: "28°"
            color: Theme.white
            font.pixelSize: 26
            font.weight: Font.Light
        }

        Text {
            x: 63
            y: 35
            text: "Santo Domingo"
            color: Theme.weatherPlace
            font.pixelSize: 12
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
        z: 100
        anchors.fill: parent
        source: "qml/components/capture/view.qml"
        onLoaded: {
            item.capture = Backend.capture;
            item.windowProvider = () => main.captureWindows();
            item.backdrop = wallpaper;
            item.screenOrigin = Qt.binding(() => Qt.point(main.x, main.y));
        }
    }

    Popup {
        id: panelPopup

        parent: main.contentItem
        popupType: Popup.Window
        z: 300
        padding: 0
        margins: 10
        // A native Wayland popup must have valid geometry before it is mapped.
        width: Math.max(1, panelLoader.item ? panelLoader.item.implicitWidth : 240)
        height: Math.max(1, panelLoader.item ? panelLoader.item.implicitHeight : 140)
        visible: main.panelMode !== "" && panelLoader.status === Loader.Ready
            && panelLoader.item !== null && panelLoader.item.implicitWidth > 0 && panelLoader.item.implicitHeight > 0
        x: Math.max(10, Math.min(main.width - width - 10, main.panelAnchorX - width / 2))
        y: topBarItem.barHeight + 5
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: main.controller.closePanel()
        background: Item {}

        contentItem: Loader {
            id: panelLoader

            active: main.panelMode !== ""
            source: "qml/components/Root.qml"
            onLoaded: mainController.panelLoaded(item, wallpaper, topBarItem)
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
        anchors.top: main.dockOnTop ? contentArea.top : undefined
        anchors.bottom: main.dockOnBottom ? main.contentItem.bottom : undefined

        anchors.horizontalCenter: main.dockHorizontalCenter ? main.contentItem.horizontalCenter : undefined
        anchors.verticalCenter: main.dockVerticalCenter ? contentArea.verticalCenter : undefined

        anchors.leftMargin: main.dockPosition.indexOf("left-") === 0 ? sideBarItem.x + sideBarItem.width + 12 : main.dockPosition === "bottom-left" ? weatherCard.x + weatherCard.width + 12 : main.dockOnLeft ? 16 : 0
        anchors.rightMargin: main.dockOnRight ? 16 : 0
        anchors.topMargin: main.dockOnTop ? 16 : 0
        anchors.bottomMargin: main.dockOnBottom ? 16 : 0
    }
}
