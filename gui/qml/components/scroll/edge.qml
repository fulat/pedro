import QtQuick

Item {
    id: edge
    objectName: "filesScrollEdge"
    property var flickable: null
    readonly property Item surface: flickable ? flickable.contentItem : null
    function pulse() {
        if (!flickable || !flickable.atYEnd || flickable.contentHeight <= flickable.height || motion.running) return;
        motion.start();
    }
    onSurfaceChanged: {
        motion.stop();
        shift.y = 0;
        if (surface) surface.transform.push(shift);
    }
    Translate { id: shift; y: 0 }
    SequentialAnimation {
        id: motion
        NumberAnimation { target: shift; property: "y"; to: -4; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: shift; property: "y"; to: 0; duration: 180; easing.type: Easing.InOutQuad }
    }
    Connections {
        target: edge.flickable
        function onContentYChanged() {
            if (edge.flickable.moving) edge.pulse();
        }
        function onMovementEnded() { edge.pulse(); }
    }
}
