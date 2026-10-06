import QtQuick

Item {
    id: edge
    objectName: "filesScrollEdge"
    property var flickable: null
    readonly property Item surface: flickable ? flickable.contentItem : null
    function pulse() {
        if (!flickable || !flickable.atYEnd || flickable.contentHeight <= flickable.height || motion.running || release.running) return;
        motion.start();
    }
    function scrollBy(delta, precise = false) {
        if (!flickable || flickable.contentHeight <= flickable.height) return;
        const minimum = flickable.originY - flickable.topMargin;
        const maximum = Math.max(minimum, flickable.originY + flickable.contentHeight - flickable.height + flickable.bottomMargin);
        const start = wheelMotion.running ? wheelMotion.to : flickable.contentY;
        const destination = Math.max(minimum, Math.min(maximum, start - delta));
        if (flickable.atYEnd && delta < 0) {
            motion.stop();
            release.stop();
            shift.y = Math.max(-10, shift.y + delta * 0.12);
            wheelRelease.restart();
        }
        wheelMotion.stop();
        wheelMotion.from = flickable.contentY;
        wheelMotion.to = destination;
        wheelMotion.duration = precise ? 70 : 150;
        wheelMotion.start();
    }
    onSurfaceChanged: {
        motion.stop();
        release.stop();
        shift.y = 0;
        if (surface) surface.transform.push(shift);
    }
    Translate { id: shift; y: 0 }
    NumberAnimation { id: wheelMotion; target: edge.flickable; property: "contentY"; easing.type: Easing.OutCubic }
    NumberAnimation { id: release; target: shift; property: "y"; to: 0; duration: 220; easing.type: Easing.OutCubic }
    Timer { id: wheelRelease; interval: 140; onTriggered: release.restart() }
    SequentialAnimation {
        id: motion
        NumberAnimation { target: shift; property: "y"; to: -4; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: shift; property: "y"; to: 0; duration: 180; easing.type: Easing.InOutQuad }
    }
    WheelHandler {
        parent: edge.flickable
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        acceptedModifiers: Qt.NoModifier
        onWheel: event => {
            if (!edge.flickable || edge.flickable.contentHeight <= edge.flickable.height
                || Math.abs(event.pixelDelta.x || event.angleDelta.x) > Math.abs(event.pixelDelta.y || event.angleDelta.y)) {
                event.accepted = false;
                return;
            }
            const precise = event.pixelDelta.y !== 0;
            const delta = precise ? event.pixelDelta.y : event.angleDelta.y / 120 * 36;
            if (!delta) { event.accepted = false; return; }
            edge.scrollBy(delta, precise);
            event.accepted = true;
        }
    }
    Connections {
        target: edge.flickable
        function onVerticalOvershootChanged() {
            if (edge.flickable.dragging && edge.flickable.verticalOvershoot > 0) {
                motion.stop();
                release.stop();
                shift.y = -Math.min(10, edge.flickable.verticalOvershoot * 0.12);
            }
        }
        function onDraggingChanged() {
            if (edge.flickable.dragging) wheelMotion.stop();
            else if (shift.y < 0) release.restart();
        }
        function onContentYChanged() {
            if (edge.flickable.flicking) edge.pulse();
        }
        function onMovementEnded() {
            if (shift.y < 0) release.restart();
            else edge.pulse();
        }
    }
}
