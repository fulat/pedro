import QtQuick

import "../../scripts/theme.js" as Theme

// Declares the visual representation and input wiring for a desktop shortcut.
Item {
    id: shortcut

    required property var shell
    required property var controller
    required property real cellWidth
    required property real cellHeight
    property var app
    property bool selected: false

    signal menuRequested(real localX, real localY)

    width: cellWidth
    height: cellHeight
    z: shell.desktopDragging && shortcut.selected ? 3 : 1
    scale: shell.desktopDragging && shortcut.selected ? 1.04 : 1

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
        color: shortcut.selected ? Theme.shortcutSelected : shortcutMouse.containsMouse ? Theme.shortcutHover : "transparent"
        border.width: shortcut.selected ? 1 : 0
        border.color: Theme.shortcutSelectedBorder

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
    }

    Icon {
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

        onPressed: mouse => controller.shortcutPressed(mouse, shortcutMouse, shortcut)
        onPositionChanged: mouse => controller.shortcutPositionChanged(mouse, pressedButtons, shortcutMouse, shortcut)
        onReleased: mouse => controller.shortcutReleased(mouse)
        onCanceled: shell.controller.endDesktopDrag()
        onClicked: mouse => controller.shortcutClicked(mouse, moved, shortcut)
        onDoubleClicked: mouse => controller.shortcutDoubleClicked(mouse, moved, shortcut)
    }
}
