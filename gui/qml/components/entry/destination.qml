import QtQuick

// A location receives the native drag produced by File/Folder, regardless of
// which view or application contains the source component.
DropArea {
    id: destination
    property url location
    property bool acceptsFiles: true
    readonly property bool trash: String(location).startsWith("trash:")
    enabled: acceptsFiles
    keys: ["text/uri-list"]

    function canDrop(urls) {
        return acceptsFiles && (trash ? urls.length > 0 && !Backend.trash.busy
            : Backend.fileTransfer.canMove(urls, location));
    }

    function dropFiles(urls) {
        if (!canDrop(urls)) return false;
        if (trash) Backend.trash.move(urls);
        else Backend.fileTransfer.move(urls, location);
        return true;
    }

    onEntered: drag => { drag.accepted = canDrop(drag.urls); }
    onDropped: drop => {
        if (dropFiles(drop.urls)) drop.accept(Qt.MoveAction);
    }
}
