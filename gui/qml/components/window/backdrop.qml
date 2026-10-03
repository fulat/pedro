pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window

// Compose only the Pedro windows beneath the owner; never capture the owner or
// windows above it. The shared Liquid component blurs this complete backdrop.
Item {
    id: backdrop

    property Window owner
    property Window desktopWindow
    property var windows: []
    readonly property real desktopX: desktopWindow ? desktopWindow.x : Screen.virtualX
    readonly property real desktopY: desktopWindow ? desktopWindow.y : Screen.virtualY

    x: desktopX - (owner ? owner.x : 0)
    y: desktopY - (owner ? owner.y : 0)
    width: desktopWindow ? desktopWindow.width : Screen.width
    height: desktopWindow ? desktopWindow.height : Screen.height

    Image {
        anchors.fill: parent
        source: backdrop.enabled ? Backend.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
    }

    Repeater {
        model: backdrop.enabled ? backdrop.windows : []

        delegate: Image {
            id: windowImage

            required property var modelData
            property var capture: null
            property bool pending: false
            property bool alive: true
            readonly property bool overlapping: backdrop.owner && modelData
                && modelData !== backdrop.owner && modelData.visible && backdrop.owner.visible
                && modelData.x < backdrop.owner.x + backdrop.owner.width
                && modelData.x + modelData.width > backdrop.owner.x
                && modelData.y < backdrop.owner.y + backdrop.owner.height
                && modelData.y + modelData.height > backdrop.owner.y

            x: modelData ? modelData.x - backdrop.desktopX : 0
            y: modelData ? modelData.y - backdrop.desktopY : 0
            width: modelData ? modelData.width : 0
            height: modelData ? modelData.height : 0
            visible: overlapping
            source: capture ? capture.url : ""
            smooth: true
            mipmap: true

            Component.onDestruction: alive = false

            Timer {
                interval: 100
                repeat: true
                triggeredOnStart: true
                running: windowImage.overlapping

                onTriggered: {
                    if (windowImage.pending) return;
                    windowImage.pending = true;
                    // Half-resolution is sufficient for heavily frosted glass and
                    // keeps cross-window texture readback bounded to overlapping windows.
                    const target = Qt.size(Math.max(1, Math.ceil(windowImage.width / 2)),
                        Math.max(1, Math.ceil(windowImage.height / 2)));
                    const started = windowImage.modelData.contentItem.grabToImage(result => {
                        if (!windowImage.alive) return;
                        windowImage.capture = result;
                        windowImage.pending = false;
                    }, target);
                    if (!started) windowImage.pending = false;
                }
            }
        }
    }
}
