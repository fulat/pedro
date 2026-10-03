import QtQuick
import "../../qml/controllers" as Controllers
Item {
    id: root
    width: 1280
    height: 720
    Item { id: files; property var controller }
    Item { id: menu; x: 872; y: 10; width: 356; height: 30 }
    Controllers.Application {
        id: controller
        objectName: "controller"
        window: root
        filesQuickWindow: files
        desktopShortcuts: area
        desktopShortcutRepeater: repeater
        desktopObstacles: [menu]
    }
    Item {
        id: area
        anchors.fill: parent
        property real cellWidth: 114
        property real cellHeight: 110
        property real cellGap: 8
        Repeater {
            id: repeater
            objectName: "repeater"
            model: Backend.desktopModel
            delegate: Item {
                required property var entry
                required property int index
                objectName: "shortcut"
                property var app: entry
                property point initialPosition: Qt.point(0, 0)
                Component.onCompleted: initialPosition = controller.desktopRestoredPosition(entry, index)
                width: 106
                height: 102
                x: initialPosition.x
                y: initialPosition.y
            }
        }
    }
    Connections {
        target: Backend.desktopModel
        function onSortRequested() { Qt.callLater(controller.sortDesktop); }
    }
}
