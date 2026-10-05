import QtQuick
import QtQuick.Controls.Basic

import "../../scripts/theme.js" as Theme
import ".." as Components

// Declares the visual representation and input wiring for a desktop shortcut.
Item {
    id: shortcut

    required property var shell
    required property var controller
    required property real cellWidth
    required property real cellHeight
    property var app
    property bool stackIndicator: false
    property bool selected: false
    readonly property var stack: shell.controller.stackInfo(app)
    readonly property bool stacked: Backend.desktopModel.organization === "stack"
    visible: !stacked || stack.visible

    signal menuRequested(real localX, real localY)

    width: cellWidth
    height: cellHeight
    z: shell.desktopDragging && shortcut.selected ? 3 : 1
    scale: shell.desktopDragging && shortcut.selected ? 1.04 : 1
    opacity: shell.controller.stackDragActive && shell.controller.stackDragSource === shortcut ? 0.5 : 1

    Behavior on opacity {
        NumberAnimation { duration: 120 }
    }

    Behavior on scale {
        NumberAnimation {
            duration: 100
            easing.type: Easing.OutCubic
        }
    }

    Behavior on x {
        enabled: !shell.desktopDragging
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    Behavior on y {
        enabled: !shell.desktopDragging
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: shortcut.stackIndicator ? (shortcutMouse.containsMouse ? Theme.shortcutHover : "transparent") : shell.controller.stackDropTargetId === shortcut.app.id ? "#405b99dd" : shortcut.selected ? Theme.shortcutSelected : shortcutMouse.containsMouse ? Theme.shortcutHover : "transparent"
        border.width: !shortcut.stackIndicator && (shortcut.selected || shell.controller.stackDropTargetId === shortcut.app.id) ? 1 : 0
        border.color: Theme.shortcutSelectedBorder

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
    }

    Rectangle {
        visible: shortcut.stacked && shortcut.stack.leader && shortcut.stack.count > 1 && (shortcut.stackIndicator || !shortcut.stack.expanded)
        width: 44
        height: 34
        x: (parent.width - width) / 2 + 6
        y: 4
        radius: 6
        rotation: 9
        color: shortcut.app && shortcut.app.isDirectory ? "#254d79" : "#455369"
        border.color: "#87a9cc"
        antialiasing: true
    }
    Rectangle {
        visible: shortcut.stacked && shortcut.stack.leader && shortcut.stack.count > 1 && (shortcut.stackIndicator || !shortcut.stack.expanded)
        width: 44
        height: 34
        x: (parent.width - width) / 2 - 4
        y: 10
        radius: 6
        rotation: -6
        color: shortcut.app && shortcut.app.isDirectory ? "#396b9d" : "#62748e"
        border.color: "#a2bfdd"
        antialiasing: true
    }

    function closeMenu() {
        if (entryLoader.item) entryLoader.item.closeMenu();
    }

    function activate() {
        if (entryLoader.item) entryLoader.item.activate();
    }

    function openMenu(localX, localY) {
        const position = mapToItem(entryLoader, localX, localY);
        entryLoader.item.openMenu(position.x, position.y);
    }

    Item {
        id: nameSlot
        y: 63
        width: parent.width
        height: 36
        z: 5
    }

    Loader {
        id: entryLoader
        anchors.top: parent.top
        anchors.topMargin: 3
        anchors.horizontalCenter: parent.horizontalCenter
        width: 57
        height: 57
        source: shortcut.app && shortcut.app.isDirectory ? "../entry/folder.qml" : "../entry/file.qml"
        onLoaded: {
            item.controller = Qt.binding(() => shortcut.shell.controller);
            item.entry = Qt.binding(() => shortcut.app || {});
            item.showName = false;
            item.nameSurface = Qt.binding(() => nameSlot);
            item.nameSize = 13;
            item.label = Qt.binding(() => shortcut.stacked && shortcut.stack.leader && shortcut.stack.count > 1 && (shortcut.stackIndicator || !shortcut.stack.expanded)
                ? shortcut.shell.controller.stackLabel(shortcut.stack.key) : shortcut.app ? shortcut.app.name : "");
            item.inputEnabled = false;
            item.iconSize = 57;
            if (shortcut.renameRequested) Qt.callLater(() => {
                if (shortcut.renameRequested) {
                    item.beginRename();
                    shortcut.shell.controller.renamingDesktopId = "";
                }
            });
        }
    }

    Item {
        visible: shortcut.stacked && shortcut.stack.leader && shortcut.stack.count > 1 && (shortcut.stackIndicator || !shortcut.stack.expanded)
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 12
        width: 24
        height: 24
        Components.Liquid {
            anchors.fill: parent
            backdrop: shortcut.shell.entryBackdrop
            cornerRadius: 12
            frosted: true
            resolutionScale: 2
        }
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "#660b1420"
            antialiasing: true
        }
        Text {
            anchors.centerIn: parent
            text: shortcut.stack.count
            color: Theme.white
            font.pixelSize: 12
        }
    }

    readonly property bool renameRequested: !stackIndicator && app && shell.controller.renamingDesktopId === app.id
    onRenameRequestedChanged: {
        if (renameRequested && entryLoader.item) {
            entryLoader.item.beginRename();
            shell.controller.renamingDesktopId = "";
        }
    }

    function dragFiles(urls) { return entryLoader.item.dragFiles(shortcut, urls); }
    function canDrop(urls) { return entryLoader.item.canDrop(urls); }
    function dropFiles(urls) { return entryLoader.item.dropFiles(urls); }

    MouseArea {
        id: shortcutMouse

        property bool moved: false
        property real pressedX
        property real pressedY

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPressed: mouse => controller.shortcutPressed(mouse, shortcutMouse, shortcut)
        onPositionChanged: mouse => controller.shortcutPositionChanged(mouse, pressedButtons, shortcutMouse, shortcut)
        onReleased: mouse => controller.shortcutReleased(mouse)
        onCanceled: shell.controller.cancelDesktopDrag()
        onClicked: mouse => controller.shortcutClicked(mouse, moved, shortcut)
        onDoubleClicked: mouse => controller.shortcutDoubleClicked(mouse, moved, shortcut)
    }
}
