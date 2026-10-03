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
        color: shell.controller.stackDropTargetId === shortcut.app.id ? "#405b99dd" : shortcut.selected ? Theme.shortcutSelected : shortcutMouse.containsMouse ? Theme.shortcutHover : "transparent"
        border.width: shortcut.selected || shell.controller.stackDropTargetId === shortcut.app.id ? 1 : 0
        border.color: Theme.shortcutSelectedBorder

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
    }

    Rectangle {
        visible: shortcut.stacked && shortcut.stack.leader && shortcut.stack.count > 1
        width: 42
        height: 38
        radius: 5
        color: "#4036475a"
        border.color: "#40ffffff"
        x: (parent.width - width) / 2 + 5
        y: 10
        rotation: 8
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
            item.inputEnabled = false;
            item.iconSize = 57;
        }
    }

    Item {
        visible: shortcut.stacked && shortcut.stack.leader && shortcut.stack.count > 1
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

    Text {
        anchors.top: parent.top
        anchors.topMargin: 65
        anchors.left: parent.left
        anchors.right: parent.right
        visible: shell.controller.renamingDesktopId !== shortcut.app.id
        text: shortcut.stacked && shortcut.stack.leader && shortcut.stack.count > 1 && !shortcut.stack.expanded
            ? shell.controller.stackLabel(shortcut.stack.key) : shortcut.app ? shortcut.app.name : ""
        color: Theme.white
        style: Text.Outline
        styleColor: Theme.shortcutShadow
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }

    TextField {
        id: nameEditor
        objectName: "desktopNameEditor"
        anchors.top: parent.top
        anchors.topMargin: 63
        anchors.left: parent.left
        anchors.right: parent.right
        z: 5
        height: 28
        visible: shortcut.app && shell.controller.renamingDesktopId === shortcut.app.id
        readOnly: shell.controller.renamingDesktopBusy
        color: Theme.white
        selectionColor: "#805b99dd"
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        background: Rectangle {
            color: "#d9232e3c"
            radius: 5
            border.color: "#80ffffff"
        }
        onVisibleChanged: {
            if (visible) {
                text = shortcut.app.name;
                Qt.callLater(() => { forceActiveFocus(); selectAll(); });
            }
        }
        onAccepted: shell.controller.commitDesktopRename(shortcut.app, text)
        onActiveFocusChanged: {
            if (!activeFocus && visible) {
                shell.controller.commitDesktopRename(shortcut.app, text);
            }
        }
        Keys.onEscapePressed: shell.controller.renamingDesktopId = ""
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

        onPressed: mouse => controller.shortcutPressed(mouse, shortcutMouse, shortcut)
        onPositionChanged: mouse => controller.shortcutPositionChanged(mouse, pressedButtons, shortcutMouse, shortcut)
        onReleased: mouse => controller.shortcutReleased(mouse)
        onCanceled: shell.controller.cancelDesktopDrag()
        onClicked: mouse => controller.shortcutClicked(mouse, moved, shortcut)
        onDoubleClicked: mouse => controller.shortcutDoubleClicked(mouse, moved, shortcut)
    }
}
