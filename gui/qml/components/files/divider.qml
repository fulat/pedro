import QtQuick
import "palette.js" as Palette

Item {
    id: divider
    objectName: "filesColumnDivider"
    property real currentWidth: 240
    property real minimumWidth: 180
    property real maximumWidth: 600
    property int direction: 1
    property bool collapsible: false
    readonly property bool dragging: mouse.pressed
    signal dragStarted()
    signal dragFinished()
    signal collapseRequested()
    signal resized(real value)
    Rectangle {
        anchors.centerIn: parent
        width: 1
        height: parent.height
        color: Palette.colors(Backend.appearanceMode).line
    }
    MouseArea {
        id: mouse
        objectName: "filesColumnResizeHandle"
        anchors.fill: parent
        cursorShape: Qt.SplitHCursor
        preventStealing: true
        property real initialX: 0
        property real initialWidth: 0
        onPressed: mouse => {
            initialX = mapToGlobal(mouse.x, mouse.y).x;
            initialWidth = divider.currentWidth;
            divider.dragStarted();
        }
        onReleased: {
            divider.dragFinished();
            if (divider.collapsible && divider.currentWidth <= 150) divider.collapseRequested();
        }
        onCanceled: divider.dragFinished()
        onPositionChanged: mouse => {
            if (!pressed) return;
            const delta = mapToGlobal(mouse.x, mouse.y).x - initialX;
            divider.resized(Math.max(divider.minimumWidth, Math.min(divider.maximumWidth,
                initialWidth + delta * divider.direction)));
        }
    }
}
