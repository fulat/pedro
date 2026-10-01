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
            leftMargin: sideBarItem.y < topBarItem.height + desktopShortcutsArea.cellHeight ? sideBarItem.x + sideBarItem.width + 12 : 0
        }

        MouseArea {
            id: desktopSelectionArea

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: selectionRectangle.visible ? Qt.CrossCursor : Qt.ArrowCursor

            onPressed: mouse => mainController.desktopPressed(mouse, desktopShortcutsArea, selectionRectangle, desktopMenu)
            onPositionChanged: mouse => mainController.desktopPositionChanged(mouse, pressedButtons, selectionRectangle)
            onReleased: mouse => mainController.desktopReleased(mouse, selectionRectangle)

            onCanceled: selectionRectangle.visible = false
        }

        Repeater {
            id: desktopShortcutRepeaterItem
            model: Mocks.desktopShortcutRepeaterItems

            delegate: Desktop.Shortcut {
                id: desktopShortcut

                required property var modelData

                x: modelData.column * desktopShortcutsArea.cellWidth
                y: modelData.row * desktopShortcutsArea.cellHeight
                shell: main
                controller: mainController
                cellWidth: desktopShortcutsArea.cellWidth
                cellHeight: desktopShortcutsArea.cellHeight
                app: modelData
                selected: main.controller.isDesktopShortcutSelected(modelData.id)

                onMenuRequested: (localX, localY) => mainController.shortcutMenuRequested(desktopShortcut, localX, localY)
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
        popupType: Popup.Item
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Components.Liquid {
            backdrop: wallpaper
            frosted: false
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

                model: Mocks.osNavigationMenuItems

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
        id: panelLoader

        z: 30
        active: main.panelMode !== ""
        source: "qml/components/Root.qml"

        anchors.top: main.contentItem.top
        anchors.topMargin: topBarItem.barHeight + 5
        x: Math.max(10, Math.min(main.width - width - 10, main.panelAnchorX - width / 2))

        onLoaded: mainController.panelLoaded(item, wallpaper, topBarItem)

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
