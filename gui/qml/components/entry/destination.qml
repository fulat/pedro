import QtQuick

// A location receives the native drag produced by File/Folder, regardless of
// which view or application contains the source component.
DropArea {
    id: destination
    property url location
    property bool acceptsFiles: true
    property var resolveLocation: null
    property url currentLocation: location
    onLocationChanged: currentLocation = location
    onExited: currentLocation = location
    function updateLocation(position) {
        currentLocation = resolveLocation ? resolveLocation(position) : location;
    }
    readonly property bool trash: String(currentLocation).startsWith("trash:")
    enabled: acceptsFiles
    keys: ["text/uri-list"]

    function canDrop(urls) {
        return acceptsFiles && (trash ? urls.length > 0 && !Backend.trash.busy
            : Backend.fileTransfer.canMove(urls, currentLocation));
    }

    function dropFiles(urls) {
        if (!canDrop(urls)) return false;
        if (trash) Backend.trash.move(urls);
        else Backend.fileTransfer.move(urls, currentLocation);
        return true;
    }

    onEntered: drag => {
        updateLocation(Qt.point(drag.x, drag.y));
        drag.accepted = canDrop(drag.urls);
    }
    onPositionChanged: drag => {
        updateLocation(Qt.point(drag.x, drag.y));
        drag.accepted = canDrop(drag.urls);
    }
    onDropped: drop => {
        updateLocation(Qt.point(drop.x, drop.y));
        if (dropFiles(drop.urls)) drop.accept(Qt.MoveAction);
    }
}
