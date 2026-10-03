import QtQuick
import "../../qml/components" as Components
Components.Application {
    id: root
    property var opened: []
    Component.onCompleted: Qt.callLater(() => {
        opened = [openFolderWindow("file:///tmp"), openFolderWindow("file:///var")];
        check.start();
    })
    Timer {
        id: check
        interval: 500
        onTriggered: {
            if (root.opened.length !== 2 || !root.opened[0].item || !root.opened[1].item
                    || root.opened[0].item === root.opened[1].item
                    || !root.opened[0].item.visible || !root.opened[1].item.visible
                    || root.opened[0].item.controller.directory.location !== "file:///tmp"
                    || root.opened[1].item.controller.directory.location !== "file:///var") {
                console.error("Independent folder windows failed");
                Qt.exit(1);
                return;
            }
            console.log("Independent folder windows: two distinct windows with separate locations passed");
            root.opened[0].item.close();
            root.opened[1].item.close();
            Qt.callLater(() => Qt.quit());
        }
    }
}
