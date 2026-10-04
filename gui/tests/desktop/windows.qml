import QtQuick
import "../../qml/components" as Components
Components.Application {
    id: root
    property var opened: []
    Component.onCompleted: Qt.callLater(() => {
        opened = [openFolderWindow("file:///tmp"), openFolderWindow("file:///var"), openFolderWindow("file:///usr")];
        check.start();
    })
    Timer {
        id: check
        interval: 500
        onTriggered: {
            if (root.opened.length !== 3 || !root.opened[0].item || !root.opened[1].item
                    || root.opened[0].item === root.opened[1].item
                    || (root.opened[0].item.x === root.opened[1].item.x && root.opened[0].item.y === root.opened[1].item.y)
                    || !root.opened[0].item.visible || !root.opened[1].item.visible
                    || root.opened[0].item.controller.directory.location !== "file:///tmp"
                    || root.opened[1].item.controller.directory.location !== "file:///var") {
                console.error("Independent folder windows failed");
                Qt.exit(1);
                return;
            }
            const positions = new Set(root.opened.map(loader => `${loader.item.x}:${loader.item.y}`));
            if (positions.size !== 3 || root.placementReservations.length !== 3) {
                console.error("Stack folder position reservations failed");
                Qt.exit(3);
                return;
            }
            const same = root.openFolderWindow("file:///tmp", true);
            if (same !== root.opened[0] || root.folderWindows.length !== 3) {
                console.error("Bulk folder duplicate skip failed");
                Qt.exit(2);
                return;
            }
            console.log("Independent folder windows: three distinct windows with reserved separate positions passed");
            root.opened[0].item.close();
            root.opened[1].item.close();
            root.opened[2].item.close();
            Qt.callLater(() => Qt.quit());
        }
    }
}
