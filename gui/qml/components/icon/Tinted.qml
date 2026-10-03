pragma ComponentBehavior: Bound

import QtQuick
import "../../scripts/pixel.js" as Pixel
import "../../scripts/theme.js" as Theme

Item {
    id: root
    property url source
    property color tint: Theme.white
    property real resolutionScale: 1
    readonly property real pixelRatio: Math.max(1, Screen.devicePixelRatio)
    implicitWidth: 24
    implicitHeight: 24

    //source icon
    property url sourceIcon: root.source.toString().length ? "image://icons/" + root.tint.toString().replace("#", "") + "/" + root.source.toString().split("/").pop() : ""

    Image {
        anchors.fill: parent
        source: root.sourceIcon
        sourceSize.width: Pixel.physical(root.width * root.resolutionScale, root.pixelRatio)
        sourceSize.height: Pixel.physical(root.height * root.resolutionScale, root.pixelRatio)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: false
        antialiasing: true
    }
}
